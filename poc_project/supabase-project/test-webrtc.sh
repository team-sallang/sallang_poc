#!/bin/bash

echo "WebRTC 클라이언트 통합 테스트"
echo "=============================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 프로젝트 루트 디렉토리로 이동
cd "$(dirname "$0")/.."

print_status "프로젝트 루트 디렉토리: $(pwd)"

# 1. Supabase 인프라 상태 확인
print_status "Supabase 인프라 상태 확인 중..."

if docker compose ps | grep -q "supabase-db.*Up"; then
    print_success "Supabase 데이터베이스가 실행 중입니다."
else
    print_warning "Supabase 데이터베이스가 실행되지 않았습니다."
    print_status "Supabase 인프라를 시작합니다..."
    docker compose up -d
    sleep 10
fi

# 2. CoTURN 서버 상태 확인
print_status "CoTURN 서버 상태 확인 중..."

if docker compose -f docker-compose.coturnTest.yml ps | grep -q "coturn.*Up"; then
    print_success "CoTURN 서버가 실행 중입니다."
else
    print_warning "CoTURN 서버가 실행되지 않았습니다."
    print_status "CoTURN 서버를 시작합니다..."
    docker compose -f docker-compose.coturnTest.yml up -d
    sleep 5
fi

# 3. 데이터베이스 연결 테스트
print_status "데이터베이스 연결 테스트 중..."

DB_CONNECTION=$(docker compose exec -T db psql -U postgres -d postgres -c "SELECT 1;" 2>/dev/null)
if [ $? -eq 0 ]; then
    print_success "데이터베이스 연결 성공"
else
    print_error "데이터베이스 연결 실패"
    exit 1
fi

# 4. WebRTC 테이블 존재 확인
print_status "WebRTC 테이블 존재 확인 중..."

TABLE_CHECK=$(docker compose exec -T db psql -U postgres -d postgres -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('webrtc_signaling', 'webrtc_rooms');" 2>/dev/null)

if echo "$TABLE_CHECK" | grep -q "webrtc_signaling"; then
    print_success "webrtc_signaling 테이블이 존재합니다."
else
    print_warning "webrtc_signaling 테이블이 없습니다. 데이터베이스를 재시작하세요."
fi

if echo "$TABLE_CHECK" | grep -q "webrtc_rooms"; then
    print_success "webrtc_rooms 테이블이 존재합니다."
else
    print_warning "webrtc_rooms 테이블이 없습니다. 데이터베이스를 재시작하세요."
fi

# 5. Supabase Realtime 서비스 확인
print_status "Supabase Realtime 서비스 확인 중..."

REALTIME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4000/health 2>/dev/null)
if [ "$REALTIME_STATUS" = "200" ]; then
    print_success "Supabase Realtime 서비스가 정상 작동 중입니다."
else
    print_warning "Supabase Realtime 서비스에 연결할 수 없습니다. (HTTP $REALTIME_STATUS)"
fi

# 6. CoTURN 서버 연결 테스트
print_status "CoTURN 서버 연결 테스트 중..."

TURN_STATUS=$(nc -z localhost 3478 2>/dev/null && echo "open" || echo "closed")
if [ "$TURN_STATUS" = "open" ]; then
    print_success "CoTURN 서버 포트 3478이 열려있습니다."
else
    print_warning "CoTURN 서버 포트 3478에 연결할 수 없습니다."
fi

# 7. WebRTC 클라이언트 파일 확인
print_status "WebRTC 클라이언트 파일 확인 중..."

CLIENT_DIR="webrtc-client"
REQUIRED_FILES=("index.html" "style.css" "client.js" "supabase-config.js")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$CLIENT_DIR/$file" ]; then
        print_success "$file 파일이 존재합니다."
    else
        print_error "$file 파일이 없습니다."
    fi
done

# server.py 파일은 Live Server 사용으로 대체됨
print_status "Live Server를 사용하여 클라이언트를 실행하세요."

# 8. 테스트 요약
echo ""
echo "테스트 요약"
echo "==========="

# 서비스 상태 요약
echo "서비스 상태:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | grep -E "(supabase|db|realtime)"

echo ""
echo "CoTURN 서버 상태:"
docker compose -f docker-compose.coturnTest.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | grep coturn

# 9. 사용 방법 안내
echo ""
echo "사용 방법"
echo "========="
echo "1. VS Code Live Server 확장 설치:"
echo "   - Ctrl+Shift+X로 확장 탭 열기"
echo "   - 'Live Server' 검색 후 설치"
echo ""
echo "2. WebRTC 클라이언트 실행:"
echo "   - webrtc-client 폴더를 VS Code에서 열기"
echo "   - index.html 파일을 우클릭"
echo "   - 'Open with Live Server' 선택"
echo ""
echo "3. 브라우저에서 접속:"
echo "   http://localhost:5500 (기본 포트)"
echo ""
echo "4. 테스트 시나리오:"
echo "   - 같은 브라우저에서 두 개 탭으로 테스트"
echo "   - 다른 브라우저에서 접속하여 통화 테스트"
echo "   - 다른 기기에서 네트워크를 통한 테스트"
echo ""

print_success "통합 테스트 완료!"
print_status "WebRTC 클라이언트를 시작하려면 VS Code Live Server를 사용하세요."
