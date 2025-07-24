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

# 동시 배포 방지 (Lock 파일)
LOCK_FILE="/tmp/guestbook_deploy.lock"
if [ -f "$LOCK_FILE" ]; then
  echo "❌ 다른 배포가 진행 중입니다."
  exit 1
fi
echo $$ > "$LOCK_FILE"

# 정리 함수 (스크립트 종료 시 항상 실행)
cleanup() {
  rm -f "$LOCK_FILE"
  echo "🧹 배포 정리 완료"
}
trap cleanup EXIT

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

# 기존 서비스 정리 (타임아웃 적용)
echo "🛑 기존 서비스 정리 중..."
timeout 60s $COMPOSE_CMD -f docker-compose.prod.yml down --remove-orphans || true

# 새 이미지 다운로드
echo "📥 새 이미지 다운로드 중..."
export IMAGE_TAG=$IMAGE_TAG
timeout 300s $COMPOSE_CMD -f docker-compose.prod.yml pull

# 새 서비스 시작
echo "🚀 새 서비스 시작 중..."
timeout 180s $COMPOSE_CMD -f docker-compose.prod.yml up -d

# 헬스체크 (최대 2분 대기)
echo "🏥 서비스 헬스체크 중..."
for i in {1..24}; do
  if $COMPOSE_CMD -f docker-compose.prod.yml ps | grep -q "healthy"; then
    echo "✅ 서비스가 정상적으로 시작되었습니다!"
    break
  fi
  if [ $i -eq 24 ]; then
    echo "❌ 헬스체크 타임아웃"
    echo "📋 서비스 상태:"
    $COMPOSE_CMD -f docker-compose.prod.yml ps
    echo "📜 서비스 로그:"
    $COMPOSE_CMD -f docker-compose.prod.yml logs --tail=20
    exit 1
  fi
  echo "⏳ 헬스체크 대기 중... ($i/24)"
  sleep 5
done

# 최종 상태 확인
echo "📋 실행 중인 서비스:"
$COMPOSE_CMD -f docker-compose.prod.yml ps

# 이전 이미지 정리
echo "🧹 사용하지 않는 이미지 정리 중..."
docker image prune -f

echo "🎉 배포 완료!"
echo "🌐 Frontend: http://$(curl -s ifconfig.me):3000"
echo "🔧 Backend: http://$(curl -s ifconfig.me):8080"