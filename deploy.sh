#!/bin/bash
set -e

echo "🚀 방명록 배포 시작... ($(date))"

# 도메인 설정
DOMAIN="t1324.p.ssafy.io"
FRONTEND_URL="https://$DOMAIN"
BACKEND_URL="https://$DOMAIN/api"

# 필수 환경변수 확인
if [ -z "$IMAGE_TAG" ]; then
  echo "❌ IMAGE_TAG 환경변수가 설정되지 않았습니다."
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN 환경변수가 설정되지 않았습니다."
  exit 1
fi

echo "📦 배포할 이미지 태그: $IMAGE_TAG"
echo "🌐 도메인: $DOMAIN"

# Docker Compose 명령어 확인
if command -v docker-compose &> /dev/null; then
  COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
  COMPOSE_CMD="docker compose"
else
  echo "❌ Docker Compose를 찾을 수 없습니다."
  exit 1
fi

echo "✅ 사용할 Docker Compose: $COMPOSE_CMD"

# GitHub Container Registry 로그인
echo "🔐 Container Registry 로그인 중..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin

# 🧹 기존 컨테이너 정리
echo "🛑 기존 서비스 정리 중..."
timeout 60s $COMPOSE_CMD -f docker-compose.prod.yml down --remove-orphans || true

# 🗑️ 사용하지 않는 이미지 정리 (배포 전)
echo "🗑️ 사용하지 않는 이미지 정리 중..."
docker image prune -f || true

# 이전 버전의 guestbook 이미지들 제거 (현재 태그 제외)
if [ "$IMAGE_TAG" != "latest" ]; then
  echo "🔄 이전 버전 이미지 정리 중..."
  # backend 이미지 정리
  docker images ghcr.io/juniqu-e/guestbook-cicd/backend --format "table {{.Repository}}:{{.Tag}}" | \
    grep -v "$IMAGE_TAG" | grep -v "TAG" | \
    xargs -r docker rmi || true
  
  # frontend 이미지 정리
  docker images ghcr.io/juniqu-e/guestbook-cicd/frontend --format "table {{.Repository}}:{{.Tag}}" | \
    grep -v "$IMAGE_TAG" | grep -v "TAG" | \
    xargs -r docker rmi || true
fi

# 📥 새 이미지 다운로드
echo "📥 새 이미지 다운로드 중..."
export IMAGE_TAG=$IMAGE_TAG
timeout 300s $COMPOSE_CMD -f docker-compose.prod.yml pull

# 🚀 새 서비스 시작
echo "🚀 새 서비스 시작 중..."
timeout 180s $COMPOSE_CMD -f docker-compose.prod.yml up -d

# ⏳ 서비스 시작 대기 및 상태 확인
echo "⏳ 서비스 시작 대기 중..."
sleep 15

# 헬스체크 함수
check_service_health() {
  local service_name=$1
  local url=$2
  local max_attempts=30
  local attempt=1
  
  echo "🔍 $service_name 헬스체크 시작..."
  
  while [ $attempt -le $max_attempts ]; do
    if curl -f -s --max-time 5 "$url" >/dev/null 2>&1; then
      echo "✅ $service_name 정상 동작 확인!"
      return 0
    fi
    echo "⏳ $service_name 확인 중... ($attempt/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
  done
  
  echo "❌ $service_name 헬스체크 실패"
  return 1
}

# 서비스 헬스체크
backend_healthy=false
frontend_healthy=false

# 로컬 포트로 헬스체크
if check_service_health "Backend" "http://localhost:8080/actuator/health"; then
  backend_healthy=true
fi

if check_service_health "Frontend" "http://localhost:3000/health"; then
  frontend_healthy=true
elif check_service_health "Frontend" "http://localhost:3000"; then
  frontend_healthy=true
fi

# 🔍 도메인 설정 검증
echo ""
echo "🔍 도메인 설정 검증 중..."

# Frontend 환경변수 확인
echo "📱 Frontend 설정 확인:"
if docker exec guestbook-frontend find /usr/share/nginx/html -name "*.js" | head -1 | xargs docker exec guestbook-frontend grep -o "$DOMAIN" >/dev/null 2>&1; then
  echo "✅ Frontend에서 도메인 설정 확인됨: $DOMAIN"
else
  echo "⚠️ Frontend 도메인 설정 확인 불가 (정상일 수 있음)"
fi

# Backend CORS 설정 확인
echo "🔧 Backend CORS 설정 확인:"
backend_logs=$(docker logs guestbook-backend 2>&1 | grep -i cors | tail -3 || echo "CORS 로그 없음")
if [[ $backend_logs == *"CORS"* ]]; then
  echo "✅ Backend CORS 설정 활성화됨"
else
  echo "⚠️ Backend CORS 로그 확인 불가"
fi

# 🧹 배포 후 정리
echo ""
echo "🧹 배포 후 정리 작업..."
docker volume prune -f || true
docker network prune -f || true

# 📊 배포 결과 요약
echo ""
echo "📊 배포 결과 요약"
echo "===================="
echo "🔧 Backend 상태: $([ "$backend_healthy" = true ] && echo "✅ 정상" || echo "❌ 문제")"
echo "🌐 Frontend 상태: $([ "$frontend_healthy" = true ] && echo "✅ 정상" || echo "❌ 문제")"
echo "🏷️ 도메인: $DOMAIN"

# 📋 서비스 상태 출력
echo ""
echo "📋 실행 중인 서비스:"
$COMPOSE_CMD -f docker-compose.prod.yml ps

# 💾 디스크 사용량 확인
echo ""
echo "💾 Docker 디스크 사용량:"
docker system df

# 📜 유용한 명령어들
echo ""
echo "📜 유용한 명령어들:"
echo "  백엔드 로그: docker logs guestbook-backend"
echo "  프론트엔드 로그: docker logs guestbook-frontend"
echo "  전체 로그: docker compose -f docker-compose.prod.yml logs"
echo "  CORS 로그: docker logs guestbook-backend 2>&1 | grep -i cors"

# 🌐 접속 정보
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
echo ""
echo "🌐 서비스 접속 정보:"
echo "  🎯 메인 도메인: $FRONTEND_URL"
echo "  🔧 API 엔드포인트: $BACKEND_URL"
echo "  📊 헬스체크: $BACKEND_URL/../actuator/health"
echo ""
echo "  🔍 로컬 테스트 (서버 내부):"
echo "  - Frontend: http://$PUBLIC_IP:3000"
echo "  - Backend: http://$PUBLIC_IP:8080"

# 🎯 도메인 연결 테스트 안내
echo ""
echo "🎯 도메인 연결 확인 방법:"
echo "  1. 브라우저에서 $FRONTEND_URL 접속"
echo "  2. 개발자 도구 Network 탭에서 API 호출 확인"
echo "  3. API 요청이 $BACKEND_URL로 전송되는지 확인"

# 최종 결과
if [ "$backend_healthy" = true ] && [ "$frontend_healthy" = true ]; then
  echo ""
  echo "🎉 배포 완료! 모든 서비스가 정상 동작 중입니다."
  echo "🌍 서비스 URL: $FRONTEND_URL"
  exit 0
elif [ "$backend_healthy" = true ] || [ "$frontend_healthy" = true ]; then
  echo ""
  echo "⚠️ 배포 완료되었으나 일부 서비스에 문제가 있을 수 있습니다."
  echo "🌍 서비스 URL: $FRONTEND_URL"
  exit 0
else
  echo ""
  echo "❌ 배포 중 문제가 발생했습니다. 로그를 확인해주세요."
  echo "🔍 빠른 문제 진단:"
  $COMPOSE_CMD -f docker-compose.prod.yml logs --tail=20
  exit 1
fi