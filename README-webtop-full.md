# LinuxServer Webtop 完整版 (DinD + GPU)

基于 LinuxServer Webtop 的完整 Agent 环境，支持 Docker-in-Docker 和 GPU 加速。

## ✨ 特性

- **XFCE Ubuntu** 桌面环境
- **DinD** - 完全隔离的 Docker 环境
- **GPU 加速** - Wayland 模式支持
- **Chrome 进程监控** - 防止内存泄漏
- **可配置** - 通过环境变量控制功能

## 🔧 运行时环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_DIND` | `true` | 是否启用 Docker-in-Docker |
| `USE_CHINA_MIRROR` | `false` | 是否使用国内软件源 |
| `SYSTEM_LANG` | `zh_CN` | 系统语言 (`zh_CN` 或 `en_US`) |

## 🚀 使用方法

### 构建镜像

```bash
docker build -f Dockerfile.webtop-full -t my-webtop-full:latest .
```

### 运行容器

#### 基础运行
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  my-webtop-full:latest
```

#### 禁用 DinD
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -e ENABLE_DIND=false \
  my-webtop-full:latest
```

#### 使用国内源 + 英文系统
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -e USE_CHINA_MIRROR=true \
  -e SYSTEM_LANG=en_US \
  my-webtop-full:latest
```

#### 带 GPU 加速
```bash
docker run -d --name webtop-full --privileged \
  -p 3000:3000 \
  -e PIXELFLUX_WAYLAND=true \
  --device /dev/dri:/dev/dri \
  my-webtop-full:latest
```

### Docker Compose

```bash
docker compose -f docker-compose.webtop-full.yml up -d
```

## 📁 文件结构

```
.
├── Dockerfile.webtop-full          # 主构建文件
├── docker-compose.webtop-full.yml  # Compose 配置
├── scripts/                        # 外部脚本
│   ├── kasm-monitor.sh            # Chrome 监控
│   ├── setup-mirror.sh            # 配置软件源
│   └── setup-lang.sh              # 配置语言
└── services/                       # s6 服务
    ├── monitor/run                # 监控服务
    ├── docker/run                 # Docker 服务
    └── docker-ready/run           # Docker 就绪检测
```

## 📝 说明

- 所有依赖在**构建时**安装完成
- 环境变量在**运行时**控制服务启动
- 复杂逻辑放在外部脚本，保持 Dockerfile 精简
