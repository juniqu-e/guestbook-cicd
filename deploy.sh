#!/bin/bash
set -e

echo "🚀 방명록 배포 시작... ($(date))"

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

# 기존 서비스 정리
echo "🛑 기존 서비스 정리 중..."
$COMPOSE_CMD -f docker-compose.prod.yml down --remove-orphans || true

# 새 이미지 다운로드
echo "📥 새 이미지 다운로드 중..."
export IMAGE_TAG=$IMAGE_TAG
$COMPOSE_CMD -f docker-compose.prod.yml pull

# 새 서비스 시작
echo "🚀 새 서비스 시작 중..."
$COMPOSE_CMD -f docker-compose.prod.yml up -d

# 간단한 대기 (헬스체크 대신)
echo "⏳ 서비스 시작 대기 중..."
sleep 30

# 서비스 상태 확인
echo "📋 서비스 상태:"
$COMPOSE_CMD -f docker-compose.prod.yml ps

# 간단한 접근성 테스트
echo "🔍 서비스 접근성 확인..."
if curl -f -s --max-time 10 http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Backend 접근 가능"
else
    echo "⚠️ Backend 접근 확인 불가 (정상일 수 있음)"
fi

if curl -f -s --max-time 10 http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Frontend 접근 가능"
else
    echo "⚠️ Frontend 접근 확인 불가 (정상일 수 있음)"
fi

echo "🎉 배포 완료!"
echo "🌐 서비스 정보:"
echo "  - Frontend: http://your-server-ip:3000"
echo "  - Backend: http://your-server-ip:8080"
echo ""
echo "📜 Backend 로그 확인: docker compose -f docker-compose.prod.yml logs backend"
echo "📜 Frontend 로그 확인: docker compose -f docker-compose.prod.yml logs frontend"