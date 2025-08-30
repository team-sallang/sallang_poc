// app.js

// ✅ Firebase 초기화
const firebaseConfig = {
    apiKey: "AIzaSyCLdrXmmOqJ25KRILzaVwgfXsvG-VfncoE",
    authDomain: "sallang-80005.firebaseapp.com",
    projectId: "sallang-80005",
    storageBucket: "sallang-80005.firebasestorage.app",
    messagingSenderId: "674931707999",
    appId: "1:674931707999:web:bfe7d9ad737eebb7b48bea",
    measurementId: "G-PNGVX7QXK1"
};

firebase.initializeApp(firebaseConfig);
const database = firebase.database();

// ✅ WebRTC 관련 전역 변수
let localStream;
let remoteStream;
let peerConnection;
let yourId;
let targetId;

// ✅ 시그널링 채널
const servers = { iceServers: [{ urls: "stun:stun.l.google.com:19302" }] };

// ✅ Firebase 메시지 핸들링
database.ref().on("child_added", readMessage);

function sendMessage(senderId, data) {
    const msg = database.ref().push({ sender: senderId, message: data });
    msg.remove(); // 휘발성
}

function readMessage(data) {
    const msg = data.val();
    const sender = msg.sender;
    const message = msg.message;

    if (sender === yourId) return;

    if (message.ice) {
        peerConnection.addIceCandidate(new RTCIceCandidate(message.ice));
    } else if (message.sdp) {
        peerConnection
            .setRemoteDescription(new RTCSessionDescription(message.sdp))
            .then(() => {
                if (message.sdp.type === "offer") {
                    peerConnection
                        .createAnswer()
                        .then((answer) => peerConnection.setLocalDescription(answer))
                        .then(() =>
                            sendMessage(yourId, { sdp: peerConnection.localDescription })
                        );
                }
            });
    }
}

function startCall() {
    yourId = document.getElementById("yourId").value;
    targetId = document.getElementById("targetId").value;

    document.getElementById("status").innerText = `🔗 Connecting to "${targetId}"...`;

    peerConnection = new RTCPeerConnection(servers);

    // 스트림 구성
    peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
            sendMessage(yourId, { ice: event.candidate });
        }
    };

    peerConnection.ontrack = (event) => {
        document.getElementById("partnerAudio").srcObject = event.streams[0];
        document.getElementById("status").innerText = `✅ Connected with "${targetId}"`;
    };

    navigator.mediaDevices
        .getUserMedia({ audio: true, video: false })
        .then((stream) => {
            localStream = stream;
            document.getElementById("yourAudio").srcObject = localStream;

            localStream.getTracks().forEach((track) => {
                peerConnection.addTrack(track, localStream);
            });

            peerConnection
                .createOffer()
                .then((offer) => peerConnection.setLocalDescription(offer))
                .then(() =>
                    sendMessage(yourId, { sdp: peerConnection.localDescription })
                );
        });
}

// ✅ 전역에 등록해서 HTML onclick에서 쓸 수 있게
window.startCall = startCall;