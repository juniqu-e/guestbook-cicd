# Multi-stage build
# 1단계: 빌드 환경
FROM node:20-alpine AS build

WORKDIR /app

# 빌드 시점에 환경변수 받기
ARG VITE_API_BASE_URL
ARG VITE_APP_TITLE
ARG VITE_APP_VERSION
ARG VITE_ENVIRONMENT
ARG VITE_API_TIMEOUT

# 환경변수 설정
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_APP_TITLE=$VITE_APP_TITLE
ENV VITE_APP_VERSION=$VITE_APP_VERSION
ENV VITE_ENVIRONMENT=$VITE_ENVIRONMENT
ENV VITE_API_TIMEOUT=$VITE_API_TIMEOUT

# 의존성 설치 (dev dependencies 포함 - 빌드용)
COPY package*.json ./
RUN npm ci

# 소스 복사 및 빌드
COPY . .
RUN npm run build

# 2단계: 프로덕션 환경
FROM nginx:alpine

# 빌드된 파일 복사
COPY --from=build /app/dist /usr/share/nginx/html

# Nginx 설정 복사 (있다면)
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]