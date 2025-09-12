- 클라이언트에서 시그널링 서버로 어떻게 연결하나
- 웹소켓으로 연결
  - supabase Realtime Websocket에 접속
  - @supabase/realtime-js 또는 Phoenix.Socket을 활용
  - 채널(topic)형식으로 방 생성 및 메시지 송수신
  - 메시지 구조는 JSON

- WebSocket을 통한 signaling
```
websocket 연결 url = ws://<EC2_PUBLIC_IP>:4000/socket/websocket?apikey=<ANON_KEY>&vsn=1.0.0
```