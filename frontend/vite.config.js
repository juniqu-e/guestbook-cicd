import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  },
  // 환경변수를 직접 정의
  define: {
    'import.meta.env.VITE_API_BASE_URL': '"http://localhost:8080/api"',
    'import.meta.env.VITE_APP_TITLE': '"방명록"',
    'import.meta.env.VITE_APP_VERSION': '"1.0.0"',
    'import.meta.env.VITE_ENVIRONMENT': '"development"',
    'import.meta.env.VITE_API_TIMEOUT': '"30000"'
  }
})