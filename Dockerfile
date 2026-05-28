# 多架构自适应 Dockerfile
# 支持: linux/amd64, linux/arm64, linux/arm/v7
# Docker 会自动选择对应架构的基础镜像

FROM node:20-alpine

# 构建参数，自动识别架构
ARG TARGETARCH
ARG BUILDPLATFORM

LABEL org.opencontainers.image.description="Chat2API - Multi-arch AI Service Proxy"
LABEL org.opencontainers.image.architecture="${TARGETARCH}"

WORKDIR /app

# 打印构建信息
RUN echo "🔨 Building for architecture: ${TARGETARCH}" \
    && echo "📦 Build platform: ${BUILDPLATFORM}"

# 安装基础工具（所有架构通用）
RUN apk add --no-cache \
    git \
    curl \
    dumb-init \
    tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 根据架构决定是否安装编译工具
# ARM 架构需要编译工具，AMD64 通常不需要
RUN case "${TARGETARCH}" in \
      "amd64") \
        echo "AMD64 detected, skipping build tools" ;; \
      "arm64"|"arm") \
        echo "ARM detected, installing build tools for native compilation" \
        && apk add --no-cache python3 make g++ ;; \
      *) \
        echo "Unknown arch: ${TARGETARCH}, installing build tools for safety" \
        && apk add --no-cache python3 make g++ ;; \
    esac

# 从 GitHub 拉取 Chat2API 源码
RUN git clone --depth=1 https://github.com/xiaoY233/Chat2API.git /tmp/chat2api \
    && cp -r /tmp/chat2api/src /app/ \
    && cp /tmp/chat2api/package.json /app/ \
    && cp /tmp/chat2api/package-lock.json /app/ \
    && rm -rf /tmp/chat2api \
    && apk del git

# 安装 npm 依赖
RUN npm install --production

# 根据架构清理编译工具（ARM 编译完不需要了）
RUN case "${TARGETARCH}" in \
      "arm64"|"arm") \
        echo "Cleaning up ARM build tools..." \
        && apk del python3 make g++ ;; \
    esac

# 创建内置 Web 服务器（所有架构通用）
RUN printf 'const http = require("http");\n\
const fs = require("fs");\n\
const path = require("path");\n\
const os = require("os");\n\
\n\
const PORT = 3000;\n\
const WEB_DIR = "/app/web";\n\
\n\
const server = http.createServer((req, res) => {\n\
  if (req.url === "/health") {\n\
    res.writeHead(200, { "Content-Type": "application/json" });\n\
    res.end(JSON.stringify({\n\
      status: "ok",\n\
      arch: os.arch(),\n\
      platform: os.platform(),\n\
      uptime: process.uptime()\n\
    }));\n\
    return;\n\
  }\n\
  \n\
  let filePath = req.url === "/" ? "/index.html" : req.url;\n\
  filePath = path.join(WEB_DIR, filePath);\n\
  \n\
  const mimeTypes = {\n\
    ".html": "text/html; charset=utf-8",\n\
    ".css": "text/css",\n\
    ".js": "application/javascript",\n\
    ".json": "application/json",\n\
    ".png": "image/png",\n\
    ".svg": "image/svg+xml"\n\
  };\n\
  \n\
  const ext = path.extname(filePath);\n\
  const contentType = mimeTypes[ext] || "text/plain";\n\
  \n\
  fs.readFile(filePath, (err, content) => {\n\
    if (err) {\n\
      res.writeHead(err.code === "ENOENT" ? 404 : 500);\n\
      res.end(err.code === "ENOENT" ? "404 Not Found" : "500 Server Error");\n\
    } else {\n\
      res.writeHead(200, { "Content-Type": contentType });\n\
      res.end(content);\n\
    }\n\
  });\n\
});\n\
\n\
server.listen(PORT, () => {\n\
  console.log(`Web Admin Panel: http://0.0.0.0:${PORT} (${os.arch()})`);\n\
});' > /app/web-server.js

# 创建自适应启动脚本
RUN printf '#!/bin/sh\n\
ARCH=$(uname -m)\n\
echo "========================================="\n\
echo "  Chat2API Docker Container"\n\
echo "  Architecture: ${ARCH}"\n\
echo "  Node.js: $(node -v)"\n\
echo "========================================="\n\
echo ""\n\
echo "Starting API Server (port 8080)..."\n\
node /app/src/main/index.js &\n\
API_PID=$!\n\
sleep 2\n\
echo "Starting Web Admin (port 3000)..."\n\
node /app/web-server.js &\n\
WEB_PID=$!\n\
echo ""\n\
echo "========================================="\n\
echo "  ✅ All services started!"\n\
echo "  📡 API: http://0.0.0.0:8080/v1"\n\
echo "  🌐 Web: http://0.0.0.0:3000"\n\
echo "========================================="\n\
wait $API_PID $WEB_PID' > /start.sh \
    && chmod +x /start.sh

# 创建用户和数据目录
RUN mkdir -p /app/data/logs \
    && addgroup -g 1001 -S chat2api \
    && adduser -S chat2api -u 1001 -G chat2api \
    && chown -R chat2api:chat2api /app

# 复制 Web 界面文件
COPY web/ /app/web/

USER chat2api

ENV NODE_ENV=production

EXPOSE 8080 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/start.sh"]
