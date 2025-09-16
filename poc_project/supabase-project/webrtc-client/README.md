# WebRTC 음성 통화 클라이언트

Supabase Realtime을 시그널링 서버로 사용하는 WebRTC 클라이언트입니다.

## 🚀 기능

- **실시간 음성 통화**: WebRTC를 통한 P2P 음성 통화
- **Supabase Realtime 시그널링**: PostgreSQL 기반 실시간 시그널링
- **CoTURN 서버 연동**: NAT 환경에서의 연결 지원
- **오디오 시각화**: 실시간 오디오 레벨 표시
- **연결 상태 모니터링**: 실시간 연결 상태 표시

## 🛠️ 기술 스택

- **Frontend**: HTML5, CSS3, JavaScript (ES6+)
- **WebRTC**: RTCPeerConnection API
- **시그널링**: Supabase Realtime
- **데이터베이스**: PostgreSQL
- **TURN 서버**: CoTURN

## 📋 사전 요구사항

1. **Supabase 인프라 실행**

   ```bash
   cd poc_project/supabase-project
   docker compose up
   ```

2. **CoTURN 서버 실행**

   ```bash
   docker compose -f docker-compose.coturnTest.yml up
   ```

3. **HTTPS 환경** (WebRTC는 HTTPS에서만 작동)
   - 로컬 개발: `localhost` 사용
   - 프로덕션: SSL 인증서 필요

## 🧪 자동 테스트

프로젝트에는 환경 상태를 자동으로 확인하는 테스트 스크립트가 포함되어 있습니다.

### Windows 환경

```bash
# 프로젝트 루트에서 실행
test-webrtc.bat
```

### Linux/macOS 환경

```bash
# 프로젝트 루트에서 실행
chmod +x test-webrtc.sh
./test-webrtc.sh
```

### 테스트 항목

- ✅ Supabase 인프라 상태 확인
- ✅ CoTURN 서버 상태 확인
- ✅ 데이터베이스 연결 테스트
- ✅ WebRTC 테이블 존재 확인
- ✅ Realtime 서비스 상태 확인
- ✅ CoTURN 서버 포트 연결 테스트
- ✅ 클라이언트 파일 존재 확인

## 🚀 사용 방법

### 1. 인프라 시작

```bash
# Supabase 인프라 + CoTURN 서버 한 번에 시작
cd poc_project/supabase-project
docker compose -f docker-compose.coturnTest.yml up -d
```

### 2. VS Code Live Server 설정

1. **Live Server 확장 설치**

   - VS Code에서 `Ctrl+Shift+X` (확장 탭 열기)
   - "Live Server" 검색 후 설치

2. **클라이언트 실행**

   - `webrtc-client` 폴더를 VS Code에서 열기
   - `index.html` 파일을 우클릭
   - "Open with Live Server" 선택
   - 브라우저에서 자동으로 열림

3. **통화 테스트**
   - 방 ID와 사용자 ID 입력
   - "방 참여" 버튼 클릭

### 3. 통화 테스트

1. **같은 브라우저**: 두 개의 탭으로 테스트
2. **다른 브라우저**: 다른 브라우저에서 접속
3. **다른 기기**: 네트워크를 통한 테스트

## 🔧 Live Server 설정 팁

### HTTPS 설정 (선택사항)

- Live Server는 기본적으로 HTTP로 실행됩니다
- `localhost`에서는 WebRTC가 정상 작동합니다
- HTTPS가 필요한 경우 Live Server 설정에서 SSL 인증서를 설정할 수 있습니다

### 포트 변경

- 기본 포트: 5500
- 설정에서 포트 변경 가능
- 여러 프로젝트를 동시에 실행할 때 유용

## 🔧 설정

### Supabase 설정

`supabase-config.js`에서 Supabase 연결 정보를 수정:

```javascript
const SUPABASE_URL = "http://localhost:8000";
const SUPABASE_ANON_KEY = "your-anon-key";
```

### TURN 서버 설정

`client.js`에서 TURN 서버 정보를 수정:

```javascript
const RTC_CONFIG = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
    {
      urls: "turn:your-turn-server:3478",
      username: "your-username",
      credential: "your-password",
    },
  ],
};
```

## 📊 데이터베이스 스키마

### webrtc_signaling 테이블

```sql
CREATE TABLE webrtc_signaling (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  room_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  message_type TEXT NOT NULL, -- 'offer', 'answer', 'ice-candidate'
  message_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### webrtc_rooms 테이블

```sql
CREATE TABLE webrtc_rooms (
  id TEXT PRIMARY KEY,
  created_by TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);
```

## 🔍 테스트 시나리오

### 1. 로컬 테스트

- 같은 브라우저에서 두 개 탭으로 테스트
- Supabase Realtime 연결 확인
- CoTURN 서버 연동 확인

### 2. 네트워크 테스트

- 다른 기기에서 접속하여 통화 테스트
- NAT 환경에서 TURN 서버 동작 확인

### 3. 품질 테스트

- 오디오 지연 시간 측정
- 연결 안정성 확인
- 에러 복구 테스트

## 🐛 문제 해결

### 마이크 권한 오류

- 브라우저에서 마이크 권한 허용 필요
- HTTPS 환경에서만 작동

### 연결 실패

- TURN 서버 상태 확인
- 방화벽 설정 확인
- 네트워크 연결 상태 확인

### 시그널링 오류

- Supabase Realtime 서비스 상태 확인
- 데이터베이스 연결 상태 확인

## 📝 개발 로그

### Phase 1: 기본 구조 ✅

- [x] Supabase 클라이언트 설정
- [x] HTML 기본 UI 구성
- [x] Realtime 채널 구독 설정

### Phase 2: WebRTC 구현 ✅

- [x] PeerConnection 설정
- [x] 마이크 스트림 캡처
- [x] ICE 후보 수집 및 교환
- [x] 오퍼/앤서 처리

### Phase 3: CoTURN 연동 ✅

- [x] TURN 서버 설정 (localhost:3478)
- [x] 인증 구현 (static-auth-secret)
- [x] 릴레이 연결 테스트

### Phase 4: 테스트 및 최적화

- [ ] 다중 클라이언트 테스트
- [ ] 에러 핸들링 개선
- [ ] 연결 품질 모니터링

## 🤝 기여

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.
