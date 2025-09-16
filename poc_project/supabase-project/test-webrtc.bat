@echo off
echo WebRTC 클라이언트 통합 테스트
echo ==============================

REM 프로젝트 루트 디렉토리로 이동
cd /d "%~dp0"

echo [INFO] 프로젝트 루트 디렉토리: %CD%

REM 1. Supabase 인프라 상태 확인
echo [INFO] Supabase 인프라 상태 확인 중...

docker compose ps | findstr "supabase-db.*Up" >nul
if %errorlevel% equ 0 (
    echo [SUCCESS] Supabase 데이터베이스가 실행 중입니다.
) else (
    echo [WARNING] Supabase 데이터베이스가 실행되지 않았습니다.
    echo [INFO] Supabase 인프라를 시작합니다...
    docker compose up -d
    timeout /t 10 /nobreak >nul
)

REM 2. CoTURN 서버 상태 확인
echo [INFO] CoTURN 서버 상태 확인 중...

docker compose -f docker-compose.coturnTest.yml ps | findstr "coturn.*Up" >nul
if %errorlevel% equ 0 (
    echo [SUCCESS] CoTURN 서버가 실행 중입니다.
) else (
    echo [WARNING] CoTURN 서버가 실행되지 않았습니다.
    echo [INFO] CoTURN 서버를 시작합니다...
    docker compose -f docker-compose.coturnTest.yml up -d
    timeout /t 5 /nobreak >nul
)

REM 3. 데이터베이스 연결 테스트
echo [INFO] 데이터베이스 연결 테스트 중...

docker compose exec -T db psql -U postgres -d postgres -c "SELECT 1;" >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] 데이터베이스 연결 성공
) else (
    echo [ERROR] 데이터베이스 연결 실패
    pause
    exit /b 1
)

REM 4. WebRTC 테이블 존재 확인
echo [INFO] WebRTC 테이블 존재 확인 중...

docker compose exec -T db psql -U postgres -d postgres -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('webrtc_signaling', 'webrtc_rooms');" | findstr "webrtc_signaling" >nul
if %errorlevel% equ 0 (
    echo [SUCCESS] webrtc_signaling 테이블이 존재합니다.
) else (
    echo [WARNING] webrtc_signaling 테이블이 없습니다. 데이터베이스를 재시작하세요.
)

docker compose exec -T db psql -U postgres -d postgres -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('webrtc_signaling', 'webrtc_rooms');" | findstr "webrtc_rooms" >nul
if %errorlevel% equ 0 (
    echo [SUCCESS] webrtc_rooms 테이블이 존재합니다.
) else (
    echo [WARNING] webrtc_rooms 테이블이 없습니다. 데이터베이스를 재시작하세요.
)

REM 5. Supabase Realtime 서비스 확인
echo [INFO] Supabase Realtime 서비스 확인 중...

curl -s -o nul -w "%%{http_code}" http://localhost:4000/health >temp_status.txt 2>nul
set /p REALTIME_STATUS=<temp_status.txt
del temp_status.txt

if "%REALTIME_STATUS%"=="200" (
    echo [SUCCESS] Supabase Realtime 서비스가 정상 작동 중입니다.
) else (
    echo [WARNING] Supabase Realtime 서비스에 연결할 수 없습니다. (HTTP %REALTIME_STATUS%)
)

REM 6. CoTURN 서버 연결 테스트
echo [INFO] CoTURN 서버 연결 테스트 중...

powershell -Command "Test-NetConnection -ComputerName localhost -Port 3478 -InformationLevel Quiet" >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] CoTURN 서버 포트 3478이 열려있습니다.
) else (
    echo [WARNING] CoTURN 서버 포트 3478에 연결할 수 없습니다.
)

REM 7. WebRTC 클라이언트 파일 확인
echo [INFO] WebRTC 클라이언트 파일 확인 중...

if exist "webrtc-client\index.html" (
    echo [SUCCESS] index.html 파일이 존재합니다.
) else (
    echo [ERROR] index.html 파일이 없습니다.
)

if exist "webrtc-client\style.css" (
    echo [SUCCESS] style.css 파일이 존재합니다.
) else (
    echo [ERROR] style.css 파일이 없습니다.
)

if exist "webrtc-client\client.js" (
    echo [SUCCESS] client.js 파일이 존재합니다.
) else (
    echo [ERROR] client.js 파일이 없습니다.
)

if exist "webrtc-client\supabase-config.js" (
    echo [SUCCESS] supabase-config.js 파일이 존재합니다.
) else (
    echo [ERROR] supabase-config.js 파일이 없습니다.
)

REM server.py 파일은 Live Server 사용으로 대체됨
echo [INFO] Live Server를 사용하여 클라이언트를 실행하세요.

REM 8. 테스트 요약
echo.
echo 테스트 요약
echo ===========
echo 서비스 상태:
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | findstr "supabase"

echo.
echo CoTURN 서버 상태:
docker compose -f docker-compose.coturnTest.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | findstr "coturn"

REM 9. 사용 방법 안내
echo.
echo 사용 방법
echo =========
echo 1. VS Code Live Server 확장 설치:
echo    - Ctrl+Shift+X로 확장 탭 열기
echo    - "Live Server" 검색 후 설치
echo.
echo 2. WebRTC 클라이언트 실행:
echo    - webrtc-client 폴더를 VS Code에서 열기
echo    - index.html 파일을 우클릭
echo    - "Open with Live Server" 선택
echo.
echo 3. 브라우저에서 접속:
echo    http://localhost:5500 (기본 포트)
echo.
echo 4. 테스트 시나리오:
echo    - 같은 브라우저에서 두 개 탭으로 테스트
echo    - 다른 브라우저에서 접속하여 통화 테스트
echo    - 다른 기기에서 네트워크를 통한 테스트
echo.

echo [SUCCESS] 통합 테스트 완료!
echo [INFO] WebRTC 클라이언트를 시작하려면 VS Code Live Server를 사용하세요.

pause
