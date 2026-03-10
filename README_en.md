<div align="center">
  <h3>Agent Workspace (For OpenClaw, Openfang etc.)</h3>
  <p>
    <a href="README.md">中文（简体）</a> •
    <a href="README_en.md">English</a>
  </p>
</div>

---

This is a globally customized cloud desktop development and runtime environment image tailored for **Autonomous AI Agents and Agent Operating Systems (like OpenClaw, Openfang, etc.)**.

As AI agent frameworks evolve rapidly, modern agents are shifting from simple chatbots to complex "operating systems" capable of connecting to the outside world (e.g., browsers, shells, file systems, and various tools). Running these agents often involves extremely complex environment dependencies and significant security/privilege risks.

Built upon Kasmweb Ubuntu Noble, this workspace embeds fully isolated Docker-in-Docker (DinD Rootless) capabilities along with a pre-optimized multi-language ecosystem. It is designed to act as the perfect foundation for secondary development, plugin creation, and secure local sandbox deployments for any cutting-edge AI framework.

## ✨ Core Features

- **Extreme Environment Persistence**: Package caches for `PyPI/Pip`, `NPM`, `Cargo`, and binaries for `Homebrew` are completely persisted via symlink mapping. Your package fetching speeds remain instant across container restarts or rebuilds.
- **Built-in Fast Mirrors**: Say goodbye to 403 and 404 errors! The underlying environment overrides default overseas sources with rock-solid mirrors (USTC / TUNA) for `apt-get`, `rustup`, `go`, `node`, `homebrew`, `docker.daemon`, and `PIP`, guaranteeing full-speed building.
- **Flawless Support for Agent "Sandbox Mode"**: Native inclusion of powerful **Rootless DinD (Docker-in-Docker)** and an active Docker Socket. When your agent frameworks (such as OpenClaw) enable Sandbox Mode, they can dynamically spin up ephemeral "Russian Doll" sub-containers *inside* this workspace to execute untrusted browser sessions, shell commands, and file manipulations. This provides an absolutely shielded proving ground without any risk of polluting the host machine!
- **Out-of-the-Box Full GUI Desktop**: Far beyond a rigid CLI container. It features a buttery-smooth KasmVNC graphical desktop equipped with comprehensive language environments. Perfectly suited for pairing with visually driven Web Agent frameworks (like `browser-use`) to handle browser automation and flow interception.

## 🚀 Quick Start

### 1. Launch Services
```bash
# Build the International version (using Dockerfile_en, tagged with -en)
docker build -t fliaping/agent-workspace:v1.0.0-en -f Dockerfile_en .

# Or build the Chinese mirror-accelerated version (using Dockerfile_zh, tagged with -zh)
docker build -t fliaping/agent-workspace:v1.0.0-zh -f Dockerfile_zh .

# Spin up the Background Workspace 
# (Make sure to update docker-compose.yml to the image version you just built)
docker compose up -d
```

### 2. Usage & Data
Upon initial startup, a `./home` directory is automatically generated in your project path. This serves as your persistent cloud user "Home."
You can freely establish `uv venv` domains and install software via `brew install xxx` directly in the persistent drive. Destroying and recreating the container won't wipe your dependencies!

## ⚠️ Important Notices

* This image relies on `oauth-proxy` and therefore disables basic VNC authorization by default (`-disableBasicAuth`). For direct public internet exposure, ensure you enact authentication by adding `VNC_PW=YourPassword` in your `docker-compose.yml`.
* `Homebrew` leverages an ingenious method of sticking to the official `linuxbrew` standard directory via persistent symlinks. **Never alter the system path structure of `/home/linuxbrew/.linuxbrew`**, as doing so disables rapid, pre-compiled "bottle" installations.
