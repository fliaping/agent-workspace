<div align="center">
  <h3>Agent Workspace (For OpenClaw, Openfang 等)</h3>
  <p>
    <a href="README.md">中文（简体）</a> •
    <a href="README_en.md">English</a>
  </p>
</div>

---

这是一个为 **AI 智能体 (Autonomous Agents) 及智能体操作系统 (如 OpenClaw, Openfang 等)** 打造的通用型云桌面开发与运行环境镜像。

随着 AI 智能体框架的爆发，现代智能体（Agent）正从简单的聊天机器人进化为能够连接外部世界（如浏览器、Shell、文件系统及各类工具）的“操作系统”。这些 Agent 的运行往往伴随着极其复杂的环境依赖以及越权风险。

本工作空间基于 Kasmweb Ubuntu Noble，内置完全隔离的 Docker-in-Docker (DinD Rootless) 和全套预优化的开发语言环境体系，旨在为各类前沿 AI 框架的二次开发、插件编写以及本地化安全沙盒部署提供完美的底座支持。

## ✨ 核心特性

- **极致环境持久化**：所有的 `PypI/Pip`、`NPM`、`Cargo` 包缓存、以及 `Homebrew` 都实现了持久化软连接转移。无论怎么重启重做容器，拉包永远极速。
- **全系内置国内源**：完全抛弃海外源。底层配置了中科大/清华的 `apt-get`、`rustup`、`go`、`node`、`homebrew`、`docker.daemon` 以及 `PIP`。国内直接一脚油门构建到底，彻底告别 403 和 404！
- **完美兼容智能体沙盒模式 (Sandbox Mode)**：镜像原生搭载了极其强悍的 **Rootless DinD (Docker-in-Docker)** 技术及就绪的 Docker Socket。当你使用的智能体框架（如 OpenClaw）需要开启沙盒安全验证时，它可以直接在当前容器内部**无限套娃**生成一次性阅后即焚的子容器来执行不受信任的浏览器会话、Shell 命令与文件编辑。这一切都在你的开发宿主隔离区内悄然进行，提供了无以复加的安全验证场！
- **开箱即用的全功能图形桌面**：超越传统死板的 CLI 容器环境，原生附带流畅的 KasmVNC 桌面和多语言底层环境配置。极其适合搭配 `browser-use` 等基于视觉驱动的主流 Web Agent 框架执行网页自动化测试和流程接管。

## 🚀 快速启动

### 1. 解决基础镜像拉取超时问题（必看！）
由于底层依赖的巨大基础包（`kasmweb/ubuntu-noble-dind-rootless`）鲜有国内公共源缓存。如果在首次环境组装时执行 `docker compose build` 后遇到 `context deadline exceeded`，说明在国外官方仓库拉取阶段被墙。

你需要采用以下两种方式之一让宿主机的母体 Docker 服务端走代理：

#### 方案 A：让宿主机 Docker 服务走代理流量 (推荐，最稳妥)
如果机器本机能上外网或跑了科学代理（如 v2ray，clash 等），请直接修改 Docker 守护进程的全局配置文件（Linux 下通常为 `/etc/docker/daemon.json`）：
```json
{
  "proxies": {
    "http-proxy": "http://127.0.0.1:7890",
    "https-proxy": "http://127.0.0.1:7890",
    "no-proxy": "localhost,127.0.0.1,.aliyun.com,.tsinghua.edu.cn,.ustc.edu.cn"
  }
}
```
*提示：IP 和端口请替换为你宿主机实际代理监听的地址。修改后执行 `sudo systemctl restart docker` 重启生效。*

#### 方案 B：更换更强效的公共镜像加速源 
编辑相同的 Docker 配置文件（`/etc/docker/daemon.json`）：
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
*提示：修改后同样需要执行 `sudo systemctl restart docker` 重启生效。加速源极具时效性，如果失效可随时在站内寻找最新的补充。*

### 2. 快速启动服务 (基于预构建镜像)

本项目已经为您提供了开箱即用的官方预构建镜像。这里提供两种启动方式（纯 Docker 命令或 Docker Compose）：

#### 方式 A：使用 Docker 单行命令启动（最快捷）
无需 clone 仓库，只需一行命令即可在后台拉起您的智能体工作台：

```bash
# ⚡️ 启动中文特供版 (内置极速国内加速源)
docker run -d --name agent-workspace -p 6901:6901 -p 19789:18789 --privileged \
  -v $(pwd)/home:/home/kasm-user xuping/agent-workspace:v1.0.0-zh

# 或者启动国际纯净版 (全系官方直连)
# docker run -d --name agent-workspace -p 6901:6901 -p 19789:18789 --privileged \
#   -v $(pwd)/home:/home/kasm-user xuping/agent-workspace:v1.0.0-en
```

#### 方式 B：使用 Docker Compose 启动（适合复杂项目集成）
如果您已经下载了本仓库的代码，可以直接使用根目录下的 `docker-compose.yml`。
修改 `docker-compose.yml` 中的 `image` 标签以选择您需要的版本：
- 中文版配置：`image: xuping/agent-workspace:v1.0.0-zh`
- 英文版配置：`image: xuping/agent-workspace:v1.0.0-en`

修改完毕后，在项目根目录执行：
```bash
docker compose up -d
```

### 3. 数据与使用
第一次启动容器时，会在项目路径下自动创建一个 `./home` 文件夹，这就是你的云端持久化用户“主目录”。
你可以在里面肆意使用 `uv venv` 建立环境、装各种 `brew install xxx` 包。就算删掉容器再建立，那些依赖也不用再重下一次！

## ⚠️ 注意事项

* 本镜像默认使用 `oauth-proxy`，在 VNC 配置中关闭了 Auth 验证 (`-disableBasicAuth`)。如需公网裸露使用，请在 `docker-compose.yml` 中开启 `VNC_PW=你的密码`。
* `Homebrew` 巧妙使用了 `linuxbrew` 官方标准目录安装法配合持久化软连接转移。请绝对**不要改变 `/home/linuxbrew/.linuxbrew` 的系统路径结构**，否则将失去从国内镜像拉取免编译包的究极提速加持。
