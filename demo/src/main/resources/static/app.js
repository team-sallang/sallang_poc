// 🔑 Firebase 설정 (자신의 값으로 교체!)
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

let peerConnection;
let localStream;
let myId, targetId;
let signalingRef;

const servers = {
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
};

// 시작 버튼
async function start() {
    myId = document.getElementById("myId").value.trim();
    targetId = document.getElementById("targetId").value.trim();

    if (!myId || !targetId) {
        alert("Your ID와 Target ID를 입력하세요.");
        return;
    }

    document.getElementById("status").innerText = `Ready (me: ${myId}, target: ${targetId})`;

    peerConnection = new RTCPeerConnection(servers);

    // 내 오디오 트랙 추가
    localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
    document.getElementById("localAudio").srcObject = localStream;

    // 상대 오디오 수신
    peerConnection.ontrack = (event) => {
        document.getElementById("remoteAudio").srcObject = event.streams[0];
    };

    // ICE candidate를 Firebase로 전송
    peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
            database.ref(`calls/${targetId}`).push({
                type: "candidate",
                ice: event.candidate.toJSON(),
                sender: myId
            });
        }
    };

    // Firebase에서 메시지 수신
    signalingRef = database.ref(`calls/${myId}`);
    signalingRef.on("child_added", async (snapshot) => {
        const message = snapshot.val();
        if (!message || message.sender === myId) return;

        try {
            if (message.type === "offer") {
                await peerConnection.setRemoteDescription(new RTCSessionDescription(message));
                document.getElementById("status").innerText = "Offer received";
            } else if (message.type === "answer") {
                await peerConnection.setRemoteDescription(new RTCSessionDescription(message));
                document.getElementById("status").innerText = "Answer received ✅ Connected!";
            } else if (message.type === "candidate" && message.ice) {
                await peerConnection.addIceCandidate(new RTCIceCandidate(message.ice));
            }
        } catch (err) {
            console.error("Signaling error:", err);
        }
    });
}

// Offer 생성
async function createOffer() {
    const offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    database.ref(`calls/${targetId}`).push({ ...offer, sender: myId });
    document.getElementById("status").innerText = "Offer sent 🚀";
}

// Answer 생성
async function createAnswer() {
    const answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    database.ref(`calls/${targetId}`).push({ ...answer, sender: myId });
    document.getElementById("status").innerText = "Answer sent 🔄";
}

document.addEventListener("DOMContentLoaded", () => {
    // 버튼의 id를 사용하여 요소를 가져오고, 이벤트 리스너 할당
    document.getElementById("startButton").onclick = start;
    document.getElementById("createOfferButton").onclick = createOffer;
    document.getElementById("createAnswerButton").onclick = createAnswer;
});