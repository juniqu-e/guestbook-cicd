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

# 이미지 존재 확인
echo "🔍 이미지 존재 확인 중..."
BACKEND_IMAGE="ghcr.io/juniqu-e/guestbook-cicd/backend:$IMAGE_TAG"
FRONTEND_IMAGE="ghcr.io/juniqu-e/guestbook-cicd/frontend:$IMAGE_TAG"

if ! docker manifest inspect "$BACKEND_IMAGE" > /dev/null 2>&1; then
  echo "❌ Backend 이미지를 찾을 수 없습니다: $BACKEND_IMAGE"
  echo "🔍 사용 가능한 태그 확인 중..."
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://ghcr.io/v2/juniqu-e/guestbook-cicd/backend/tags/list" | \
    jq -r '.tags[]?' | head -5 || echo "태그 목록을 가져올 수 없습니다."
  exit 1
fi

if ! docker manifest inspect "$FRONTEND_IMAGE" > /dev/null 2>&1; then
  echo "❌ Frontend 이미지를 찾을 수 없습니다: $FRONTEND_IMAGE"
  echo "🔍 사용 가능한 태그 확인 중..."
  curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://ghcr.io/v2/juniqu-e/guestbook-cicd/frontend/tags/list" | \
    jq -r '.tags[]?' | head -5 || echo "태그 목록을 가져올 수 없습니다."
  exit 1
fi

echo "✅ 모든 이미지가 존재합니다."

# 기존 서비스 정리
echo "🛑 기존 서비스 정리 중..."
timeout 60s $COMPOSE_CMD -f docker-compose.prod.yml down --remove-orphans || true

# 새 이미지 다운로드
echo "📥 새 이미지 다운로드 중..."
export IMAGE_TAG=$IMAGE_TAG
timeout 300s $COMPOSE_CMD -f docker-compose.prod.yml pull

# 새 서비스 시작
echo "🚀 새 서비스 시작 중..."
timeout 180s $COMPOSE_CMD -f docker-compose.prod.yml up -d

# 헬스체크 (더 견고하게)
echo "🏥 서비스 헬스체크 중..."
for i in {1..20}; do
  sleep 10
  
  # Backend 헬스체크
  if curl -f -s http://localhost:8080/actuator/health >/dev/null 2>&1; then
    echo "✅ Backend 서비스 정상!"
    
    # Frontend 헬스체크
    if curl -f -s http://localhost:3000 >/dev/null 2>&1; then
      echo "✅ Frontend 서비스 정상!"
      break
    else
      echo "⏳ Frontend 대기 중... ($i/20)"
    fi
  else
    echo "⏳ Backend 대기 중... ($i/20)"
  fi
  
  if [ $i -eq 20 ]; then
    echo "❌ 헬스체크 타임아웃"
    echo "📋 서비스 상태:"
    $COMPOSE_CMD -f docker-compose.prod.yml ps
    echo "📜 Backend 로그:"
    $COMPOSE_CMD -f docker-compose.prod.yml logs backend --tail=20
    echo "📜 Frontend 로그:"
    $COMPOSE_CMD -f docker-compose.prod.yml logs frontend --tail=20
    exit 1
  fi
done

# 최종 상태 확인
echo "📋 실행 중인 서비스:"
$COMPOSE_CMD -f docker-compose.prod.yml ps

# 사용하지 않는 이미지 정리
echo "🧹 이전 이미지 정리 중..."
docker image prune -f

echo "🎉 배포 완료!"
echo "🌐 서비스 확인:"
echo "  - Frontend: http://$(curl -s ifconfig.me || echo 'localhost'):3000"
echo "  - Backend: http://$(curl -s ifconfig.me || echo 'localhost'):8080"
echo "  - Health Check: http://$(curl -s ifconfig.me || echo 'localhost'):8080/actuator/health"