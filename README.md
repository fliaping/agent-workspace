<div align="center">
  <h3>Agent Workspace (For OpenClaw, Openfang 等)</h3>
  <p>
    <a href="README.md">中文（简体）</a> •
    <a href="README_en.md">English</a>
  </p>
</div>

---

这是一个为 **AI 智能体 (Autonomous Agents) 及智能体操作系统 (如 OpenClaw, Openfang 等)** 打造的通用型云桌面开发与运行环境镜像。

随着 AI 智能体框架的爆发，现代智能体（Agent）正从简单的聊天机器人进化为能够连接外部世界（如浏览器、Shell、文件系统及各类工具）的"操作系统"。这些 Agent 的运行往往伴随着极其复杂的环境依赖以及越权风险。

本工作空间基于 Kasmweb Ubuntu Noble，内置完全隔离的 Docker-in-Docker (DinD Rootless) 和全套预优化的开发语言环境体系，旨在为各类前沿 AI 框架的二次开发、插件编写以及本地化安全沙盒部署提供完美的底座支持。

![web-desktop-example](./images/web-desktop-example.png)

## ✨ 核心特性

- **极致环境持久化**：所有的 `PypI/Pip`、`NPM`、`Cargo` 包缓存、以及 `Homebrew` 都实现了持久化软连接转移。无论怎么重启重做容器，拉包永远极速。
- **全系内置国内源**（中文版）：底层配置了中科大/清华的 `apt-get`、`rustup`、`go`、`node`、`homebrew`、`docker.daemon` 以及 `PIP`。国内直接一脚油门构建到底，彻底告别 403 和 404！
- **完美兼容智能体沙盒模式 (Sandbox Mode)**：镜像原生搭载了极其强悍的 **Rootless DinD (Docker-in-Docker)** 技术及就绪的 Docker Socket。当你使用的智能体框架（如 OpenClaw）需要开启沙盒安全验证时，它可以直接在当前容器内部**无限套娃**生成一次性阅后即焚的子容器来执行不受信任的浏览器会话、Shell 命令与文件编辑。
- **开箱即用的全功能图形桌面**：超越传统死板的 CLI 容器环境，原生附带流畅的 KasmVNC 桌面。中文版预装中文 locale 和字体，默认开启 KasmVNC IME 输入模式（直接使用本地电脑输入法输入中文），极其适合搭配 `browser-use` 等基于视觉驱动的主流 Web Agent 框架执行网页自动化测试和流程接管。

## 🚀 快速启动

一条命令即可完成所有安装和配置。脚本会自动引导你完成语言、镜像源、版本、端口、Agent 软件等选择：

**Linux / macOS（国内推荐 - GitCode）**
```bash
curl -fsSL https://raw.gitcode.com/fliaping0/agent-workspace/raw/main/install.sh | bash
```

**Linux / macOS（GitHub - 国际用户）**
```bash
curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.ps1" -OutFile "install.ps1"; .\install.ps1
```

> 脚本会自动检测权限，如需 root 提权会提示你输入密码。

**安装脚本特性：**
- ✅ **多语言**: 中文/英文界面
- ✅ **镜像源独立选择**: 阿里云镜像（国内）/ Docker Hub（海外）
- ✅ **Agent 软件一键安装**: OpenClaw / Openfang / ZeroClaw 可多选，PM2 进程管理
- ✅ **DinD 智能适配**: 自动检测 Docker in Docker 环境，默认使用 bridge 端口映射模式
- ✅ **多平台**: Linux 服务器 / Windows / macOS
- ✅ **智能端口**: 自动检测并更换被占用端口
- ✅ **数据持久化**: 自动创建本地数据目录

---

## 🔧 高级用法

### Docker 单行命令启动

无需安装脚本，直接用 Docker 命令启动：

```bash
# 中文版（阿里云镜像 - 国内推荐）
docker run -d --name agent-workspace \
  --privileged --restart unless-stopped --shm-size 2gb \
  -p 6901:6901 \
  -e VNCOPTIONS=-disableBasicAuth \
  -e NODE_OPTIONS=--max-old-space-size=2048 \
  -v ~/agent-workspace-data:/home/kasm-user \
  registry.cn-hangzhou.aliyuncs.com/fliaping/agent-workspace:latest

# 英文版（Docker Hub）
docker run -d --name agent-workspace \
  --privileged --restart unless-stopped --shm-size 2gb \
  -p 6901:6901 \
  -e VNCOPTIONS=-disableBasicAuth \
  -e NODE_OPTIONS=--max-old-space-size=2048 \
  -v ~/agent-workspace-data:/home/kasm-user \
  xuping/agent-workspace:latest
```

启动后访问 `https://localhost:6901/` 打开 VNC 桌面。

### Docker Compose 启动

克隆仓库后使用 `docker-compose.yml`：

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace
# 按需修改 docker-compose.yml 中的 image 和端口
docker compose up -d
```

### Agent 软件端口映射

安装 Agent 软件后，通过 `-p` 参数映射端口（容器内端口不可修改）：

| Agent 软件 | 容器内端口 | 启动命令 | 映射示例 |
|-----------|-----------|---------|---------|
| OpenClaw | 18789 | `openclaw gateway run` | `-p 18789:18789` |
| Openfang | 4200 | `openfang start` | `-p 4200:4200` |
| ZeroClaw | 42617 | `zeroclaw gateway` | `-p 42617:42617` |

所有 Agent 进程通过 **PM2** 管理：
```bash
docker exec agent-workspace pm2 list          # 查看进程
docker exec agent-workspace pm2 logs openclaw  # 查看日志
docker exec agent-workspace pm2 restart all    # 重启全部
```

### 自定义用户启动脚本

容器支持用户自定义启动脚本 `~/.startup.sh`，在 VNC 桌面就绪后自动执行。适合自动启动 Agent 软件或其他服务：

```bash
# 在数据目录中创建 .startup.sh
cat > ~/agent-workspace-data/.startup.sh << 'EOF'
#!/bin/bash
# 自动启动 Agent 软件
pm2 start "openclaw gateway run" --name openclaw
pm2 save
EOF
chmod +x ~/agent-workspace-data/.startup.sh
```

### 自定义构建镜像

如需定制化修改，可以基于 Dockerfile 自行构建：

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace

# 构建中文版（内置国内镜像源加速）
docker build -f Dockerfile_zh -t my-agent-workspace:zh .

# 构建英文版（使用官方源）
docker build -f Dockerfile_en -t my-agent-workspace:en .
```

**两个 Dockerfile 的区别：**

| 特性 | Dockerfile_zh（中文版） | Dockerfile_en（英文版） |
|-----|----------------------|----------------------|
| 系统语言 | zh_CN.UTF-8 | 默认英文 |
| 中文字体 | ✅ 文泉驿 + Noto CJK | ❌ |
| 中文输入 | ✅ KasmVNC IME 默认开启 | ❌ |
| APT 源 | 中科大镜像 | Ubuntu 官方 |
| NPM 源 | 淘宝镜像 | NPM 官方 |
| Pip 源 | 清华镜像 | PyPI 官方 |
| Rust 源 | 中科大镜像 | 官方源 |
| Go 源 | 阿里云/goproxy.cn | 官方源 |
| Homebrew | 中科大镜像 | 官方源 |
| Docker 镜像加速 | ✅ 多源加速 | ❌ |

### 内置环境与工具链

镜像预装了完整的开发环境，无需额外安装：

- **Node.js**（最新 LTS）+ NPM + PNPM + PM2 + TypeScript
- **Python 3** + pip + venv + UV 包管理器
- **Go**（1.22.4）
- **Rust**（stable）+ Cargo
- **Homebrew**（Linux 版，持久化到数据目录）
- **Docker CLI**（DinD Rootless，支持沙盒模式）
- **常用工具**：git、curl、wget、jq、unzip、build-essential

### 数据持久化

容器将 `/home/kasm-user` 映射到宿主机目录（默认 `~/agent-workspace-data`），以下内容全部持久化：

- Homebrew 安装的所有软件（通过软连接 `/home/linuxbrew/.linuxbrew` → `~/.linuxbrew`）
- NPM 全局包（`~/.npm-global`）
- Python 虚拟环境和 pip/uv 缓存
- Cargo 包和编译缓存
- Go 工作区（`~/go`）
- Agent 软件配置和数据
- 桌面配置和个人文件

### 资源限制

在 `docker-compose.yml` 中可配置资源限制：

```yaml
deploy:
  resources:
    limits:
      memory: 16G
      cpus: '12'
    reservations:
      memory: 4G
```

单行命令方式：
```bash
docker run -d --name agent-workspace --memory=16g --cpus=12 ...
```

---

## ⚠️ 注意事项

* 本镜像默认使用 `oauth-proxy`，在 VNC 配置中关闭了 Auth 验证 (`-disableBasicAuth`)。如需公网裸露使用，请设置 VNC 密码：`-e VNC_PW=你的密码`。
* `Homebrew` 使用了 `linuxbrew` 官方标准目录安装法配合持久化软连接转移。请**不要改变 `/home/linuxbrew/.linuxbrew` 的系统路径结构**，否则将失去免编译包的提速加持。
* 首次挂载空数据目录时，容器会自动从内置模板恢复完整环境（包括所有预装工具和配置）。

---

## ❓ FAQ

### 基础镜像拉取超时怎么办？

底层依赖的基础包（`kasmweb/ubuntu-noble-dind-rootless`）较大。如果使用英文版/Docker Hub 镜像时遇到 `context deadline exceeded`，可以尝试以下方式：

**方案 A：让宿主机 Docker 走代理流量（推荐）**

修改 Docker 守护进程配置（`/etc/docker/daemon.json`）：
```json
{
  "proxies": {
    "http-proxy": "http://127.0.0.1:7890",
    "https-proxy": "http://127.0.0.1:7890",
    "no-proxy": "localhost,127.0.0.1,.aliyun.com,.tsinghua.edu.cn,.ustc.edu.cn"
  }
}
```
修改后执行 `sudo systemctl restart docker` 重启生效。

**方案 B：配置公共镜像加速源**

```json
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.net",
    "https://hub-mirror.c.163.com"
  ]
}
```

> 💡 **推荐国内用户直接使用中文版阿里云镜像**（安装脚本中选择"阿里云镜像"），可避免大部分网络问题。
