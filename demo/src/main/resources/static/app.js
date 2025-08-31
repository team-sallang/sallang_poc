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

// ICE 서버 설정 (Google의 STUN 서버를 사용)
const servers = {
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
};

// ✅ 오디오 볼륨을 분석하고 업데이트하는 함수
function setupAudioMeter(stream, elementId) {
    const audioContext = new AudioContext();
    const source = audioContext.createMediaStreamSource(stream);
    const analyser = audioContext.createAnalyser();

    // 오디오 데이터 분석 설정
    analyser.fftSize = 256;
    source.connect(analyser);

    const dataArray = new Uint8Array(analyser.fftSize);
    const volumeBar = document.getElementById(elementId);

    // 프레임마다 볼륨을 업데이트하는 함수
    function updateVolume() {
        // 주파수 데이터 획득
        analyser.getByteFrequencyData(dataArray);
        let sum = 0;
        for (let i = 0; i < dataArray.length; i++) {
            sum += dataArray[i];
        }
        let average = sum / dataArray.length; // 평균 볼륨 계산

        // 볼륨 바의 너비(%) 업데이트
        // 최대 음량을 128로 가정하고 비율 계산 (analyser data는 0-255 범위)
        const volumePercentage = Math.min(100, (average / 128) * 100);
        volumeBar.style.width = `${volumePercentage}%`;

        // 다음 프레임에 다시 함수 호출
        requestAnimationFrame(updateVolume);
    }

    requestAnimationFrame(updateVolume);
}

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

    // 내 오디오 트랙 추가 및 볼륨 미터 설정
    localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    localStream.getTracks().forEach(track => peerConnection.addTrack(track, localStream));
    document.getElementById("localAudio").srcObject = localStream;
    // ✅ 내 로컬 스트림에 대한 볼륨 미터 설정
    setupAudioMeter(localStream, "localVolumeBar");

    // 상대 오디오 수신 이벤트
    peerConnection.ontrack = (event) => {
        const remoteStream = event.streams[0];
        document.getElementById("remoteAudio").srcObject = remoteStream;
        // ✅ 상대방 스트림에 대한 볼륨 미터 설정
        setupAudioMeter(remoteStream, "remoteVolumeBar");
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
        if (!message || message.sender === myId) {
            // ✅ 내 메시지이거나 유효하지 않은 메시지면 즉시 삭제
            snapshot.ref.remove();
            return;
        }

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
            // ✅ 메시지 처리가 성공적으로 완료되면 데이터베이스에서 해당 메시지 삭제
            snapshot.ref.remove();
        } catch (err) {
            console.error("Signaling error:", err);
            // ✅ 오류 발생 시에도 메시지 삭제 (오류를 유발하는 메시지가 반복되지 않도록)
            snapshot.ref.remove();
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