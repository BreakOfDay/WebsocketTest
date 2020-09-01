<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ page session="false" %>
<html>
<head>
	<title>Home</title>
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
	var pc;
	 
	/* Prepare websocket for signaling server endpoint. */
	var signalingWebsocket = new WebSocket("ws://" + window.location.host + "/websocket/signal");
	 
	var fname;
	var fsize;
	
	var chat = document.querySelector('input#chat');
	
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
	
	/* 파일 선택 및 파일 선택 */
	fileInput.addEventListener('change', handleFileInputChange, false);
	async function handleFileInputChange() {
		const file = fileInput.files[0];
		
		if(!file) {
			console.log('No file chosen');
		} else {
			sendFileButton.disabled = false;
			alert("file을 보낼 준비가 되었습니다.");
		}
	}
	
	/* Send Button Event */
	sendFileButton.addEventListener("click", () => createConnection());
	async function createConnection() {
		abortButton.disabled = false;
		sendFileButton.disabled = true;
		
		/* localConnection == pc */
		/* sendChannel == dc */
		signalingWebsocket.binaryType = 'arraybuffer';
		sendData();
	}
	
	/* sendData() */
	function sendData() {
		const file = fileInput.files[0];
		
		var obj = { 
			'filesize' : file.size,
			'filename' : file.name
		};
		signalingWebsocket.send(JSON.stringify(obj));
		log("<p style='margin: 5px; float: right; background: #ffe100;'>&lt;"+file.name+"&gt; "+file.size+"(bytes)</p><br>");
		
		statusMessage.textContent = '';
		
		if(file.size === 0) {
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
			signalingWebsocket.send(e.target.result);
			offset += e.target.result.byteLength;
			sendProgress.value = offset;
			if (offset < file.size) {
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
	
	function IsJsonString(str) { // json 타입인지 구분하는 함수
		  try {
		    var json = JSON.parse(str);
		    return (typeof json === 'object'); // json일 경우 type은 object이므로 true 리턴
		  } catch (e) {
		    return false;
		  }
	}
	
	signalingWebsocket.onmessage = function(msg) {
	    console.log("Got message", msg.data);
	    
	    var arr;
	    var signal
		if(typeof msg.data == 'string') {
			if(IsJsonString(msg.data)) {
				signal = JSON.parse(msg.data);				

				switch (signal.type) {
			        case "offer":
			            handleOffer(signal);
			            break;
			        case "answer":
			            handleAnswer(signal);
			            break;
			        // In local network, ICE candidates might not be generated.
			        case "candidate":
			            handleCandidate(signal);
			            break;
			        default:
			            break;
			    }
				
				if('filesize' in signal) {
					fname = signal.filename;
					fsize = signal.filesize;
				}
				//console.log("type:"+signal.type + ", data : "+msg.data);
				
				//fname = arr.filename;
				//fsize = arr.filesize;
			} else {
				log("<p style='margin: 5px; float: left; background: #d4d4d4;'>" + msg.data + "</p><br>"); // JSON 타입 아닐 경우에는 일반 채팅이므로 채팅 log 출력
			}
		}
	    
	    console.log(typeof msg.data);
	    if(typeof msg.data == 'object') {
			receiveBuffer.push(msg.data);
			receivedSize += msg.data.byteLength;
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
	};
	 
	signalingWebsocket.onopen = init();
	 
	function sendSignal(signal) {
	    if (signalingWebsocket.readyState == 1) {
	        signalingWebsocket.send(JSON.stringify(signal));
	    }
	};

	function init() {
	    console.log("Connected to signaling endpoint. Now initializing.");    
	    preparePeerConnection();
	};
	 
	function preparePeerConnection() {
	     // Using free public google STUN server.
	    const config = {iceServers: [{urls: "stun:stun.1.google.com:19302"}]};
	 
	    // Prepare peer connection object
	    pc = new RTCPeerConnection(config);
	    pc.onnegotiationneeded = async () => {
	        console.log('onnegotiationneeded');
	        sendOfferSignal();
	    };
	    pc.onicecandidate = function(event) {
	        if (event.candidate) {
	        	sendSignal(event);
	        }
	    };
	};
	 
	function sendOfferSignal() {
	    pc.createOffer(function(offer) {
	        sendSignal(offer);
	        pc.setLocalDescription(offer);
	    }, function(error) {
	        alert("Error creating an offer");
	    });
	};
	 
	function handleOffer(offer) {
	    pc.setRemoteDescription(new RTCSessionDescription(offer));
	 
	    // create and send an answer to an offer
	    pc.createAnswer(function(answer) {
	        pc.setLocalDescription(answer);
	        sendSignal(answer);
	    }, function(error) {
	        alert("Error creating an answer");
	    });
	 
	};
	 
	function handleAnswer(answer) {
	    pc.setRemoteDescription(new RTCSessionDescription(answer));
	    console.log("connection established successfully!!");
	};
	
	function handleCandidate(candidate) {
		alert("handleCandidate");
	    pc.addIceCandidate(new RTCIceCandidate(candidate));
	};
	
	const dc = pc.createDataChannel("chat", { negotiated: true, id: 0 }); // 원격 유저와 연결하는 신규 채널 생성 (채널이름, 설정 옵션)
	const log = function(msg) {
		div.innerHTML += "<br>"+msg;
	}
	
	
	dc.onmessage = function(e) { // 요청 데이터 받아와 사용
		console.log(e);
		var arr;
		if(typeof e.data == 'string') {
			if(IsJsonString(e.data)) {
				arr = JSON.parse(e.data);				

				fname = arr.filename;
				fsize = arr.filesize;
			} else {
				log("<p style='margin: 5px; float: left; background: #d4d4d4;'>" + e.data + "</p><br>"); // JSON 타입 아닐 경우에는 일반 채팅이므로 채팅 log 출력
			}
		}
		
		if(typeof e.data == 'object') {
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
	
	pc.oniceconnectionstatechange = function(e) { // 연결 상태
		log(pc.iceConnectionState);
	} 
	
	chat.onkeypress = function(e) {
		if (e.keyCode != 13) return;
		signalingWebsocket.send(chat.value); // 데이터 송수신 함수
		log("<p style='margin: 5px; float: right; background: #ffe100;'>" + chat.value + "</p><br>");
		chat.value = "";
	};
	</script>
 
</body>
</html>
