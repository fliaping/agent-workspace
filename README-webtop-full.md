# LinuxServer Webtop 完整版

基于 LinuxServer Webtop 的完整 Agent 环境，支持 DinD、GPU 加速和完整开发工具链。

## ✨ 特性

- **开发工具**：Node.js + Go + Rust + Python + Homebrew
- **DinD**：完全隔离的 Docker 环境
- **GPU**：Wayland 模式支持
- **中文**：KasmVNC IME 输入法
- **持久化**：LinuxServer 标准 `/config` 方式

## 🔧 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_DIND` | `true` | 启用 Docker-in-Docker |
| `USE_CHINA_MIRROR` | `false` | 使用国内镜像源 |
| `SYSTEM_LANG` | `zh_CN` | 系统语言 |

## 🚀 使用

### Docker

```bash
docker run -d --name webtop --privileged \
  -p 3000:3000 \
  -v $(pwd)/webtop-data:/config \
  my-webtop-full:latest
```

### Docker Compose

```bash
docker compose -f docker-compose.webtop-full.yml up -d
```

## 📁 持久化

挂载 `./webtop-data:/config`，所有数据自动持久化：

- 桌面配置
- 开发工具数据
- 安装的软件

## 🌐 访问

```
http://localhost:3000
```

用户：abc
