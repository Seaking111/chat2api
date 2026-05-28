# Chat2API Docker

> Chat2API Docker 部署版 —— 一键部署多平台 AI 模型代理服务

## ✨ 特性

- 🚀 **一键部署**：只需一个 docker-compose.yml 文件
- 🌐 **Web 管理面板**：可视化配置供应商和模型
- 🔌 **多供应商支持**：DeepSeek、GLM、Kimi、MiniMax、Qwen 等
- 📡 **OpenAI 兼容**：标准 `/v1` 接口，兼容所有 OpenAI 客户端
- 💾 **数据持久化**：配置和日志保存在本地
- 🔒 **内网部署**：数据不出门，安全可靠

## 📦 快速部署

### 方法一：群晖 Container Manager

1. 在 File Station 的 `docker` 文件夹中创建 `chat2api` 文件夹
2. 创建 `docker-compose.yml` 文件，内容如下：

```yaml
version: '3.8'

services:
  chat2api:
    build:
      context: https://github.com/你的用户名/chat2api-docker.git#main
    container_name: chat2api
    restart: unless-stopped
    ports:
      - "8080:8080"  # API 接口
      - "3000:3000"  # Web 管理面板
    volumes:
      - ./data:/app/data
    environment:
      - TZ=Asia/Shanghai
