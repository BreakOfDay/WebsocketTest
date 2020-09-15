<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<html>
<head>
	<title>채팅방</title>
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
</head>
<body style="width: 445px; margin: auto;">
	
	<div id="div"></div>
	<br>
	
	Chat: <input id="chat"><br><br>

	<form id="fileInfo">
		<input type="file" id="fileInput" name="files" />
	</form>
	
	<button disabled id="sendFile">Send</button>
	<button disabled id="abortButton">Abort</button>
	
	<div class="progress">
		<div class="label">Send progress:</div>
		<progress id="sendProgress" max="0" value="0"></progress>
	</div>

	<div class="progress">
		<div class="label">Receive progress:</div>
		<progress id="receiveProgress" max="0" value="0"></progress>
	</div>

	<span id="status"></span>

 
	<script>
	/*
	* Origin code 
	* 1. https://stackoverflow.com/questions/54980799/webrtc-datachannel-with-manual-signaling-example-please?answertab=oldest#tab-top
	*/
	
	/* 
	* 2. https://github.com/webrtc/samples/blob/gh-pages/src/content/datachannel/filetransfer/js/main.js
	*  Copyright (c) 2015 The WebRTC project authors. All Rights Reserved.
	*
	*  Use of this source code is governed by a BSD-style license
	*  that can be found in the LICENSE file in the root of the source
	*  tree.
	*/
	
	/* 
	* 3. https://itsallbinary.com/create-your-own-screen-sharing-web-application-using-java-and-javascript-webrtc/
	*/
	
	/* 시그널링 서버를 위한 websocket */
	var signalingWebsocket = new WebSocket("ws://" + window.location.host + "/websocket/signal");
	var pc;
	var dc;
	console.log("${param.room}");
	console.log("${param.id}");
	var chat = document.querySelector('input#chat');
	const log = function(msg) {
		div.innerHTML += "<br>"+msg;
	}
	
	signalingWebsocket.onopen = init();
	function init() {
	    console.log("Connected to signaling endpoint. Now initializing.");    
	    preparePeerConnection();
	};
	
	function preparePeerConnection() {
	     // ICE(Internet Connectivity Establishment) : 두 단말이 서로 통신할 수 있는 최적의 경로를 찾을 수 있도록 도와주는 프레임워크
	    const config = {iceServers: [{urls: "stun:stun.1.google.com:19302"}]}; // google의 공개 stun 서버 중 하나
	    pc = new RTCPeerConnection(config); // 로컬과 원격 피어 간 연결 나타내는 새로운 객체 생성 반환
	    dc = pc.createDataChannel("${param.room}", { negotiated: true, id: ${param.id} }); // 원격 유저와 연결하는 신규 채널 생성 (채널이름, 설정 옵션)
	    pc.onnegotiationneeded = async () => { // 시그널링 서버를 통해 연결 협상중일 때
	        console.log('onnegotiationneeded');
	        sendOfferSignal();
	    };
	    pc.onicecandidate = function(event) { // 로컬 ICE 에이전트가 signaling 서버를 통해 원격 피어에게 메세지를 전달 할 필요가 있을때 마다 발생.
	        if (event.candidate) { // candidate : 해당 네트워크 연결 정보.
	        	sendSignal(event);
	        }
	    };
	};

	/* offer 보내는 함수 */
	function sendOfferSignal() {
	    pc.createOffer(function(offer) { // 로컬 SDP 생성 및 작성
	        sendSignal(offer);
	        pc.setLocalDescription(offer);
	    }, function(error) {
	        alert("Error creating an offer");
	    });
	};
	 
	function sendSignal(signal) {
	    if (signalingWebsocket.readyState == 1) { // readyState == 1 : websocket 열린 상태
	    	if(signal.candidate) { // signal에 candidate 존재 -> sdp의 candidate에 대한 정보
	    		signalingWebsocket.send(JSON.stringify(signal.candidate));
	    	} else { // signal에 candidate 존재x -> sdp 전체 정보
		        signalingWebsocket.send(JSON.stringify(signal));	    		
	    	}
	    } 
	};

	pc.oniceconnectionstatechange = function(e) { // 연결 상태가 변경되면 변경된 상태 화면에 출력
		if(pc.iceConnectionState == 'checking') {
			log("연결을 시도중입니다.");			
		} else if(pc.iceConnectionState == 'connected') {
			log("연결이 성공했습니다.");
		} else if(pc.iceConnectionState == 'disconnected') {
			log("연결이 끊어졌습니다.");
		}
	} 
	
	// 시그널링 서버가 요청 데이터를 받았을 때
	signalingWebsocket.onmessage = function(msg) {
	    console.log("Got message", msg.data);
	    
	    var signal;
		signal = JSON.parse(msg.data);				
		if(signal.type) { // msg 타입이 offer나 answer일 경우
			switch (signal.type) {
		        case "offer":
		            handleOffer(signal);
		            break;
		        case "answer":
		            handleAnswer(signal);
		            break;
		        default:
		            break;
		    }
		} else { // msg 타입이 candidate일 경우
			handleCandidate(signal);
		}
	};
	
	function handleOffer(offer) {
	    pc.setRemoteDescription(new RTCSessionDescription(offer)); // offer에게서 받은 sdp를 원격 피어의 설명으로 설정
	 
	    pc.createAnswer(function(answer) { // answer의 sdp 생성 및 작성
	        pc.setLocalDescription(answer);
	        sendSignal(answer);
	    }, function(error) {
	        alert("Error creating an answer");
	    });
	};
	 
	function handleAnswer(answer) {
	    pc.setRemoteDescription(new RTCSessionDescription(answer)); // answer에게 받은 sdp를 원격 피어의 설명으로 설정
	    console.log("connection established successfully!!");
	};
	
	// 시그널링 채널을 통해 원격 유저로부터 candidate를 수신-> 브라우저의 ICE 에이전트에게 새로 수신한 candidate 전달
	function handleCandidate(candidate) {
		alert("handleCandidate");
		// addIceCandidate : 원격 설명에 연결의 원격쪽 상태를 설명해주는 신규 원격 candidate 추가
	    pc.addIceCandidate(new RTCIceCandidate(candidate));
	};
	
	/* 파일전송 변수 */
	var fileReader;
	const fileInput = document.querySelector('input#fileInput');
	const abortButton = document.querySelector('button#abortButton');
	const sendProgress = document.querySelector('progress#sendProgress');
	const receiveProgress = document.querySelector('progress#receiveProgress');
	const statusMessage = document.querySelector('span#status');
	const sendFileButton = document.querySelector('button#sendFile');

	var receiveBuffer = [];
	var receivedSize = 0;
	
	var fname;
	var fsize;
	
	/* 파일 선택 및 파일 선택 */
	fileInput.addEventListener('change', handleFileInputChange, false);  // fileInput이 변경 시 handleFileInputChange 메소드 실행
	async function handleFileInputChange() {
		const file = fileInput.files[0];
		
		if(!file) {
			console.log('No file chosen');
		} else {
			sendFileButton.disabled = false;
			alert("file을 보낼 준비가 되었습니다.");
		}
	}
	
	/* 파일 전송 버튼 클릭 */
	sendFileButton.addEventListener("click", () => createConnection());
	async function createConnection() {
		abortButton.disabled = false;
		sendFileButton.disabled = true;
		
		/* localConnection == pc */
		/* sendChannel == dc */
		dc.binaryType = 'arraybuffer';
		sendData();
	}

	function sendData() {
		const file = fileInput.files[0];
		
		var obj = { 
			'filesize' : file.size,
			'filename' : file.name
		};
		dc.send(JSON.stringify(obj));
		log("<p style='margin: 5px; float: right; background: #ffe100;'>&lt;"+file.name+"&gt; "+file.size+"(bytes)</p><br>");
		
		statusMessage.textContent = '';
		
		if(file.size === 0) { // 파일 선택 안 했을 때
			statusMessage.textContent = 'File is empty, please select a non-empty file';
			return;
		}
		
		sendProgress.max = file.size;
		receiveProgress.max = file.size;
		
		const chunkSize = 16384;
		fileReader = new FileReader(); // 파일 읽기
		var offset = 0;
		fileReader.addEventListener('error', error => console.error('Error reading file:', error));
		fileReader.addEventListener('abort', event => console.log('File reading aborted:', event));
		fileReader.addEventListener('load', e => {
			console.log('FileRead.onload ', e);
			dc.send(e.target.result); // chunkSize 크기로 filesize를 잘라서 ArrayBuffer로 전송
			offset += e.target.result.byteLength; // 전송하는 객체의 바이트 수
			sendProgress.value = offset;
			if (offset < file.size) { // 보낸 파일 값이 파일 전체 크기보다 작을 때
				readSlice(offset);
			}
		});
		const readSlice = o => {
			console.log('readSlice ', o);
			const slice = file.slice(offset, o + chunkSize); // slice(start, end) : start부터 end 바로 전 까지 선택
			fileReader.readAsArrayBuffer(slice); // ArrayBuffer(바이트로 구성된 배열) 형식으로 파읽 읽음.
		};
		readSlice(0);
	}
	
	chat.onkeypress = function(e) {
		if (e.keyCode != 13) return;
		dc.send(chat.value); // 데이터 송수신 함수
		log("<p style='margin: 5px; float: right; background: #ffe100;'>" + chat.value + "</p><br>");
		chat.value = "";
	};

	
	dc.onopen = function() { // 연결 및 데이터 요청(연결 성공했을 때, connected 됐을 때)
		chat.select();
	} 
	
	function IsJsonString(str) { // json 타입인지 구분하는 함수
		  try {
		    var json = JSON.parse(str);
		    return (typeof json === 'object'); // json일 경우 type은 object이므로 true 리턴
		  } catch (e) {
		    return false;
		  }
	}
	
	dc.onmessage = function(e) { // 요청 데이터 받아와 사용
		console.log(e);
		
		var arr;
		if(typeof e.data == 'string') { // 일반 채팅 및 파일이름과 크기 받을 때
			if(IsJsonString(e.data)) { // 파일 기본 정보
				arr = JSON.parse(e.data);				

				fname = arr.filename;
				fsize = arr.filesize;
			} else { // 일반 채팅
				log("<p style='margin: 5px; float: left; background: #d4d4d4;'>${username}" + e.data + "</p><br>"); // JSON 타입 아닐 경우에는 일반 채팅이므로 채팅 log 출력
			}
		}
		
		if(typeof e.data == 'object') { // 파일 받을 때
			receiveBuffer.push(e.data);
			receivedSize += e.data.byteLength;
			receiveProgress.value = receivedSize;
			
			if(receivedSize == fsize) {
				const received = new Blob(receiveBuffer); // Blob : 대용량 바이너리 객체. 대체로 이미지나 사운드 파일 같은 하나의 커다란 파일
				
				var url = URL.createObjectURL(received); // Blob 객체를 나타내는 URL을 포함한 DOMString 생성. 생성된 window의 document에서만 유효.
				var txt = "&lt;" + fname + "&gt; " +fsize + "(bytes)";
				
				log("<p style='margin: 5px; float: left; background: #d4d4d4;'><a href='"+url+"' download='"+fname+"' style='display: block;'>"+txt+"</a></p><br>");
				receiveBuffer = [];
				receivedSize = 0;
			}
		}
	}
	</script>
 
</body>
</html>
