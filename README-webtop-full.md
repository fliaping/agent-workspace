# LinuxServer Webtop 完整版 (DinD + GPU + 开发环境)

基于 LinuxServer Webtop 的完整 Agent 环境，支持 Docker-in-Docker、GPU 加速和完整开发工具链。

## ✨ 特性

### 1. 完整开发工具链
- **Node.js** (LTS) + NPM + PNPM + PM2 + TypeScript
- **Python 3** + pip + UV 包管理器
- **Go** (1.22.4)
- **Rust** (stable) + Cargo
- **Homebrew** (Linuxbrew)
- **Docker CLI** (DinD Rootless)

### 2. 中文支持
- 中文 Locale (zh_CN.UTF-8)
- 中文字体 (文泉驿/Noto)
- **KasmVNC IME** 输入法（使用本地电脑输入法）
- 国内镜像源加速

### 3. DinD (Docker-in-Docker)
- 完全隔离的 Docker 环境
- 支持运行容器内的容器
- 可配置启用/禁用

### 4. GPU 加速
- Wayland 模式支持
- Intel/AMD GPU 支持
- NVIDIA GPU 支持（需额外配置）

### 5. 持久化
- 直接挂载 `/home/kasm-user` 目录
- 所有数据自动持久化

## 🔧 运行时环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_DIND` | `true` | 是否启用 Docker-in-Docker |
| `USE_CHINA_MIRROR` | `false` | 是否使用国内软件源 |
| `SYSTEM_LANG` | `zh_CN` | 系统语言 (zh_CN/en_US) |

## 🚀 使用方法

### 构建镜像

```bash
docker build -f Dockerfile.webtop-full -t my-webtop-full:latest .
```

### 运行容器

#### 基础运行（推荐）
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -v $(pwd)/webtop-data:/home/kasm-user \
  my-webtop-full:latest
```

#### 使用国内源 + 英文系统
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -e USE_CHINA_MIRROR=true \
  -e SYSTEM_LANG=en_US \
  -v $(pwd)/webtop-data:/home/kasm-user \
  my-webtop-full:latest
```

#### 带 GPU 加速
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -e PIXELFLUX_WAYLAND=true \
  --device /dev/dri:/dev/dri \
  -v $(pwd)/webtop-data:/home/kasm-user \
  my-webtop-full:latest
```

### Docker Compose

```bash
docker compose -f docker-compose.webtop-full.yml up -d
```

## 📁 持久化说明

直接挂载 `/home/kasm-user` 目录，所有数据自动持久化：

```bash
-v $(pwd)/webtop-data:/home/kasm-user
```

包含：
- NPM 全局包 (`~/.npm-global`)
- Go 工作区 (`~/go`)
- Cargo 缓存 (`~/.cargo`)
- Rust 工具链 (`~/.rustup`)
- Python 缓存 (`~/.cache`)
- Homebrew (`~/.linuxbrew`)
- Docker 数据 (`~/docker-data`)
- 桌面配置 (`~/.config`)
- 工作目录 (`~/agent-workspace`)

## 🌐 访问桌面

```
http://localhost:3000
```

默认用户：abc（无密码）

## 🔧 开发工具使用

### Node.js
```bash
node --version    # v20.x
npm --version
pnpm --version
pm2 --version
```

### Python
```bash
python3 --version
pip --version
uv --version
```

### Go
```bash
go version        # go1.22.4
go env GOPATH
```

### Rust
```bash
cargo --version
rustc --version
```

### Homebrew
```bash
brew --version
brew install <package>
```

### Docker (DinD)
```bash
docker ps
docker run hello-world
```

## 📝 说明

- 所有开发工具在**构建时**安装完成
- 直接挂载 `/home/kasm-user` 实现持久化
- 中文输入法使用**本地电脑输入法**（KasmVNC IME）
- VNC 连接稳定性已优化（idle_timeout: 300s）
