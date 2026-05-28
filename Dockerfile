FROM node:20-alpine

WORKDIR /app

# 安装必需工具
RUN apk add --no-cache git curl dumb-init tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 从 GitHub 拉取 Chat2API 源码
RUN git clone https://github.com/xiaoY233/Chat2API.git /tmp/chat2api \
    && cp -r /tmp/chat2api/src /app/ \
    && cp /tmp/chat2api/package.json /app/ \
    && cp /tmp/chat2api/package-lock.json /app/ \
    && rm -rf /tmp/chat2api \
    && apk del git

# 安装依赖
RUN npm install --production

# 创建简单的 Web 服务器
RUN printf 'const http = require("http");\n\
const fs = require("fs");\n\
const path = require("path");\n\
\n\
const server = http.createServer((req, res) => {\n\
  if (req.url === "/health") {\n\
    res.writeHead(200, { "Content-Type": "application/json" });\n\
    res.end(JSON.stringify({ status: "ok" }));\n\
    return;\n\
  }\n\
  let filePath = req.url === "/" ? "/index.html" : req.url;\n\
  filePath = path.join("/app/web", filePath);\n\
  const ext = path.extname(filePath);\n\
  const mimeTypes = { ".html": "text/html", ".css": "text/css", ".js": "application/javascript" };\n\
  const contentType = mimeTypes[ext] || "text/plain";\n\
  fs.readFile(filePath, (err, content) => {\n\
    if (err) {\n\
      res.writeHead(404);\n\
      res.end("Not Found");\n\
    } else {\n\
      res.writeHead(200, { "Content-Type": contentType });\n\
      res.end(content);\n\
    }\n\
  });\n\
});\n\
server.listen(3000, () => console.log("Web server on port 3000"));' > /app/web-server.js

# 创建启动脚本
RUN printf '#!/bin/sh\n\
echo "Starting Chat2API API server..."\n\
node /app/src/main/index.js &\n\
echo "Starting Web admin panel..."\n\
node /app/web-server.js &\n\
echo "All services started!"\n\
echo "API: http://localhost:8080/v1"\n\
echo "Web: http://localhost:3000"\n\
wait' > /start.sh \
    && chmod +x /start.sh

# 创建用户和数据目录
RUN mkdir -p /app/data/logs \
    && addgroup -g 1001 -S chat2api \
    && adduser -S chat2api -u 1001 -G chat2api \
    && chown -R chat2api:chat2api /app

# 复制 Web 文件
COPY web/ /app/web/

USER chat2api

ENV NODE_ENV=production

EXPOSE 8080 3000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["/start.sh"]
