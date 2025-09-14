// Supabase 설정
const SUPABASE_URL = 'http://localhost:8000';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

// Supabase 클라이언트 초기화
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// WebRTC 설정
const RTC_CONFIG = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        {
            urls: 'turn:localhost:3478',
            username: 'testuser',
            credential: 'testpass'
        }
    ]
};

// 전역 변수
let currentRoomId = null;
let currentUserId = null;
let peerConnection = null;
let localStream = null;
let isMuted = false;
let channel = null;

// DOM 요소
const elements = {
    roomSection: document.getElementById('roomSection'),
    callSection: document.getElementById('callSection'),
    roomIdInput: document.getElementById('roomId'),
    userIdInput: document.getElementById('userId'),
    joinRoomBtn: document.getElementById('joinRoomBtn'),
    currentRoomId: document.getElementById('currentRoomId'),
    currentUserId: document.getElementById('currentUserId'),
    connectionStatus: document.getElementById('connectionStatus'),
    muteBtn: document.getElementById('muteBtn'),
    endCallBtn: document.getElementById('endCallBtn'),
    logs: document.getElementById('logs'),
    audioVisualizer: document.getElementById('audioVisualizer')
};

// 로그 함수
function log(message, type = 'info') {
    const timestamp = new Date().toLocaleTimeString();
    const logElement = document.createElement('div');
    logElement.className = `log-message log-${type}`;
    logElement.textContent = `[${timestamp}] ${message}`;
    elements.logs.appendChild(logElement);
    elements.logs.scrollTop = elements.logs.scrollHeight;
    console.log(`[${type.toUpperCase()}] ${message}`);
}

// 연결 상태 업데이트
function updateConnectionStatus(status) {
    elements.connectionStatus.textContent = status;
    elements.connectionStatus.className = status.toLowerCase();
}

// WebRTC 클라이언트 클래스
class WebRTCClient {
    constructor(roomId, userId) {
        this.roomId = roomId;
        this.userId = userId;
        this.peerConnection = null;
        this.localStream = null;
        this.channel = null;
        this.isInitiator = false;
    }

    // Supabase Realtime 채널 구독
    async subscribeToChannel() {
        try {
            log('Realtime 채널 구독 시작...', 'info');
            
            this.channel = supabase
                .channel(`webrtc-signaling-${this.roomId}`)
                .on('postgres_changes', {
                    event: 'INSERT',
                    schema: 'public',
                    table: 'webrtc_signaling',
                    filter: `room_id=eq.${this.roomId}`
                }, (payload) => {
                    this.handleSignalingMessage(payload.new);
                })
                .subscribe();

            log('Realtime 채널 구독 완료', 'success');
            return true;
        } catch (error) {
            log(`채널 구독 실패: ${error.message}`, 'error');
            return false;
        }
    }

    // 시그널링 메시지 처리
    async handleSignalingMessage(message) {
        try {
            // 자신의 메시지는 무시
            if (message.user_id === this.userId) {
                return;
            }

            log(`시그널링 메시지 수신: ${message.message_type}`, 'info');

            switch (message.message_type) {
                case 'offer':
                    await this.handleOffer(message.message_data);
                    break;
                case 'answer':
                    await this.handleAnswer(message.message_data);
                    break;
                case 'ice-candidate':
                    await this.handleIceCandidate(message.message_data);
                    break;
            }
        } catch (error) {
            log(`시그널링 메시지 처리 실패: ${error.message}`, 'error');
        }
    }

    // 오퍼 처리
    async handleOffer(offerData) {
        try {
            log('오퍼 수신, 앤서 생성 중...', 'info');
            
            await this.createPeerConnection();
            await this.peerConnection.setRemoteDescription(offerData);
            
            const answer = await this.peerConnection.createAnswer();
            await this.peerConnection.setLocalDescription(answer);
            
            await this.sendSignalingMessage('answer', answer);
            log('앤서 전송 완료', 'success');
        } catch (error) {
            log(`오퍼 처리 실패: ${error.message}`, 'error');
        }
    }

    // 앤서 처리
    async handleAnswer(answerData) {
        try {
            log('앤서 수신', 'info');
            await this.peerConnection.setRemoteDescription(answerData);
            log('앤서 처리 완료', 'success');
        } catch (error) {
            log(`앤서 처리 실패: ${error.message}`, 'error');
        }
    }

    // ICE 후보 처리
    async handleIceCandidate(candidateData) {
        try {
            if (this.peerConnection && this.peerConnection.remoteDescription) {
                await this.peerConnection.addIceCandidate(candidateData);
                log('ICE 후보 추가 완료', 'info');
            }
        } catch (error) {
            log(`ICE 후보 처리 실패: ${error.message}`, 'error');
        }
    }

    // 시그널링 메시지 전송
    async sendSignalingMessage(type, data) {
        try {
            const { error } = await supabase
                .from('webrtc_signaling')
                .insert({
                    room_id: this.roomId,
                    user_id: this.userId,
                    message_type: type,
                    message_data: data
                });

            if (error) throw error;
            log(`${type} 메시지 전송 완료`, 'success');
        } catch (error) {
            log(`${type} 메시지 전송 실패: ${error.message}`, 'error');
        }
    }

    // WebRTC PeerConnection 생성
    async createPeerConnection() {
        try {
            log('PeerConnection 생성 중...', 'info');
            
            this.peerConnection = new RTCPeerConnection(RTC_CONFIG);
            
            // 로컬 스트림 추가
            if (this.localStream) {
                this.localStream.getTracks().forEach(track => {
                    this.peerConnection.addTrack(track, this.localStream);
                });
            }

            // ICE 후보 이벤트 처리
            this.peerConnection.onicecandidate = (event) => {
                if (event.candidate) {
                    this.sendSignalingMessage('ice-candidate', event.candidate);
                }
            };

            // 연결 상태 변경 이벤트
            this.peerConnection.onconnectionstatechange = () => {
                const state = this.peerConnection.connectionState;
                log(`연결 상태 변경: ${state}`, 'info');
                updateConnectionStatus(state);
            };

            // 원격 스트림 수신
            this.peerConnection.ontrack = (event) => {
                log('원격 오디오 스트림 수신', 'success');
                const remoteAudio = new Audio();
                remoteAudio.srcObject = event.streams[0];
                remoteAudio.play();
            };

            log('PeerConnection 생성 완료', 'success');
        } catch (error) {
            log(`PeerConnection 생성 실패: ${error.message}`, 'error');
        }
    }

    // 마이크 스트림 시작
    async startLocalStream() {
        try {
            log('마이크 권한 요청 중...', 'info');
            
            this.localStream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });

            log('마이크 스트림 시작 완료', 'success');
            this.setupAudioVisualizer();
            return true;
        } catch (error) {
            log(`마이크 스트림 시작 실패: ${error.message}`, 'error');
            return false;
        }
    }

    // 오디오 시각화 설정
    setupAudioVisualizer() {
        if (!this.localStream) return;

        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const analyser = audioContext.createAnalyser();
        const source = audioContext.createMediaStreamSource(this.localStream);
        
        source.connect(analyser);
        analyser.fftSize = 256;
        
        const bufferLength = analyser.frequencyBinCount;
        const dataArray = new Uint8Array(bufferLength);
        
        const canvas = elements.audioVisualizer;
        const ctx = canvas.getContext('2d');
        
        const draw = () => {
            requestAnimationFrame(draw);
            
            analyser.getByteFrequencyData(dataArray);
            
            ctx.fillStyle = '#f7fafc';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            const barWidth = (canvas.width / bufferLength) * 2.5;
            let barHeight;
            let x = 0;
            
            for (let i = 0; i < bufferLength; i++) {
                barHeight = (dataArray[i] / 255) * canvas.height;
                
                const gradient = ctx.createLinearGradient(0, canvas.height, 0, canvas.height - barHeight);
                gradient.addColorStop(0, '#667eea');
                gradient.addColorStop(1, '#764ba2');
                
                ctx.fillStyle = gradient;
                ctx.fillRect(x, canvas.height - barHeight, barWidth, barHeight);
                
                x += barWidth + 1;
            }
        };
        
        draw();
    }

    // 오퍼 생성 및 전송
    async createOffer() {
        try {
            log('오퍼 생성 중...', 'info');
            
            await this.createPeerConnection();
            const offer = await this.peerConnection.createOffer();
            await this.peerConnection.setLocalDescription(offer);
            
            await this.sendSignalingMessage('offer', offer);
            log('오퍼 전송 완료', 'success');
        } catch (error) {
            log(`오퍼 생성 실패: ${error.message}`, 'error');
        }
    }

    // 통화 시작
    async startCall() {
        try {
            log('통화 시작...', 'info');
            
            // 마이크 스트림 시작
            const streamStarted = await this.startLocalStream();
            if (!streamStarted) {
                throw new Error('마이크 스트림 시작 실패');
            }

            // Realtime 채널 구독
            const subscribed = await this.subscribeToChannel();
            if (!subscribed) {
                throw new Error('채널 구독 실패');
            }

            // 방 생성 또는 참여
            await this.createOrJoinRoom();

            // 오퍼 생성 (통화 시작자)
            setTimeout(() => {
                this.createOffer();
            }, 1000);

            log('통화 시작 완료', 'success');
        } catch (error) {
            log(`통화 시작 실패: ${error.message}`, 'error');
        }
    }

    // 방 생성 또는 참여
    async createOrJoinRoom() {
        try {
            const { data, error } = await supabase
                .from('webrtc_rooms')
                .select('*')
                .eq('id', this.roomId)
                .single();

            if (error && error.code === 'PGRST116') {
                // 방이 없으면 생성
                const { error: insertError } = await supabase
                    .from('webrtc_rooms')
                    .insert({
                        id: this.roomId,
                        created_by: this.userId
                    });

                if (insertError) throw insertError;
                this.isInitiator = true;
                log('새 방 생성 완료', 'success');
            } else if (error) {
                throw error;
            } else {
                log('기존 방 참여', 'info');
            }
        } catch (error) {
            log(`방 생성/참여 실패: ${error.message}`, 'error');
        }
    }

    // 통화 종료
    async endCall() {
        try {
            log('통화 종료 중...', 'info');
            
            if (this.localStream) {
                this.localStream.getTracks().forEach(track => track.stop());
                this.localStream = null;
            }

            if (this.peerConnection) {
                this.peerConnection.close();
                this.peerConnection = null;
            }

            if (this.channel) {
                await supabase.removeChannel(this.channel);
                this.channel = null;
            }

            updateConnectionStatus('disconnected');
            log('통화 종료 완료', 'success');
        } catch (error) {
            log(`통화 종료 실패: ${error.message}`, 'error');
        }
    }

    // 음소거 토글
    toggleMute() {
        if (this.localStream) {
            const audioTrack = this.localStream.getAudioTracks()[0];
            if (audioTrack) {
                audioTrack.enabled = !audioTrack.enabled;
                isMuted = !audioTrack.enabled;
                elements.muteBtn.textContent = isMuted ? '🔊 음소거 해제' : '🔇 음소거';
                log(isMuted ? '음소거 활성화' : '음소거 해제', 'info');
            }
        }
    }
}

// 전역 WebRTC 클라이언트 인스턴스
let webrtcClient = null;

// 이벤트 리스너
elements.joinRoomBtn.addEventListener('click', async () => {
    const roomId = elements.roomIdInput.value.trim();
    const userId = elements.userIdInput.value.trim();

    if (!roomId || !userId) {
        alert('방 ID와 사용자 ID를 입력해주세요.');
        return;
    }

    currentRoomId = roomId;
    currentUserId = userId;

    elements.joinRoomBtn.disabled = true;
    elements.joinRoomBtn.innerHTML = '<span class="loading"></span> 연결 중...';

    try {
        webrtcClient = new WebRTCClient(roomId, userId);
        
        elements.currentRoomId.textContent = roomId;
        elements.currentUserId.textContent = userId;
        
        elements.roomSection.style.display = 'none';
        elements.callSection.style.display = 'block';
        
        await webrtcClient.startCall();
    } catch (error) {
        log(`방 참여 실패: ${error.message}`, 'error');
        elements.joinRoomBtn.disabled = false;
        elements.joinRoomBtn.textContent = '방 참여';
    }
});

elements.muteBtn.addEventListener('click', () => {
    if (webrtcClient) {
        webrtcClient.toggleMute();
    }
});

elements.endCallBtn.addEventListener('click', async () => {
    if (webrtcClient) {
        await webrtcClient.endCall();
        
        elements.roomSection.style.display = 'block';
        elements.callSection.style.display = 'none';
        
        elements.joinRoomBtn.disabled = false;
        elements.joinRoomBtn.textContent = '방 참여';
        
        webrtcClient = null;
        currentRoomId = null;
        currentUserId = null;
    }
});

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', () => {
    log('WebRTC 클라이언트 초기화 완료', 'success');
    updateConnectionStatus('disconnected');
});
