<div align="center">
  <h1>Agent Workspace</h1>
  <p>Cloud Desktop for AI Agents</p>
  <p>
    <a href="README.md">中文</a> &bull;
    <a href="README_en.md">English</a>
  </p>
</div>

---

A containerized cloud desktop based on [LinuxServer Webtop](https://docs.linuxserver.io/images/docker-webtop/) (Selkies WebRTC), providing an isolated development and runtime environment for Codex, Claude Code, Hermes, and other AI agents.

![web-desktop-example](./images/web-desktop-example.png)

## Features

- **Selkies WebRTC Desktop** — Full Linux desktop via browser (HTTPS), inheriting LinuxServer Webtop's upstream display, encoding, and DPI defaults
- **3 Desktop Environments** — XFCE (default, recommended ~800MB) / LXQt (lightweight ~300MB) / KDE (full ~1.1GB)
- **Complete Dev Toolchain** — Node.js 22, Go 1.22, Rust, Python 3, Homebrew, uv
- **Multiple Docker Modes** — Disabled / DinD (standalone Docker inside container) / Host Docker socket mount
- **GPU Acceleration** — Auto-detect NVIDIA / Intel / AMD GPU for hardware rendering and encoding
- **China Mirror Support** — Switch to China mirrors at runtime with `USE_CHINA_MIRROR=true` (APT, npm, pip, Go, Rust, Homebrew)
- **Data Persistence** — LinuxServer `/config` standard mount for all tools, caches, and user data
- **Ready-to-run Agent** — Choose Codex, Claude Code, or Hermes on first boot, then complete its normal sign-in
- **Unified Workspace Control** — Agents use `workspacectl` for services, logs, ports, routes, and optional capabilities
- **systemctl Process Management** — Manage daemon-style agent processes via docker-systemctl-replacement
- **Secure Remote Workspace** — Webtop and code-server use a generated password and HTTPS, with first-boot foundation setup

## Quick Start

### Secure Remote Start (Recommended)

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace
./scripts/remote-up.sh
```

The script asks for one preferred Agent (Codex by default), creates a user-only
`.env.remote`, and starts Webtop. First boot installs that Agent, code-server,
and the workspace extensions. It prints credentials, endpoints, and the final
sign-in command:

```text
https://localhost:3001  # Webtop desktop
https://localhost:8443  # code-server
```

Here, `localhost` means the Docker host. From another machine, use the server
hostname/IP when the ports are reachable. If a firewall, WSL, or NAT keeps them
private, create an SSH tunnel from the client:

```bash
ssh -N -L 3001:127.0.0.1:3001 -L 8443:127.0.0.1:8443 user@server
```

Then open the same `localhost` URLs in the client browser.

The defaults use self-signed certificates. For Internet exposure, put the
workspace behind a reverse proxy, VPN, or zero-trust gateway with strong TLS and
authentication.

See [Remote Workspace Profiles](docs/remote-workspace.md) for the direct and
authenticated-gateway architectures.

### Interactive Install

Interactive script with 9-step guided setup (language, desktop, Docker mode, registry, version, data dir, port, agents, agent ports):

**Linux / macOS**
```bash
# China users (GitCode mirror)
curl -fsSL https://raw.gitcode.com/fliaping0/agent-workspace/raw/main/install.sh | bash

# International users (GitHub)
curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
# China users (GitCode mirror)
irm https://raw.gitcode.com/fliaping0/agent-workspace/raw/main/install.ps1 -OutFile install.ps1; .\install.ps1

# International users (GitHub)
irm https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.ps1 -OutFile install.ps1; .\install.ps1
```

### Docker CLI

```bash
docker run -d --name agent-workspace \
  --restart unless-stopped --shm-size 2gb \
  -e PUID=1000 -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e CUSTOM_USER=agent \
  -e PASSWORD='replace-with-a-long-random-password' \
  -p 3001:3001 \
  -v ~/agent-workspace-data:/config \
  xuping/agent-workspace:ubuntu-xfce
```

Access the desktop at **https://localhost:3001**.

> China mirror: `registry.cn-hangzhou.aliyuncs.com/fliaping/agent-workspace:ubuntu-xfce`

### Docker Compose

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace
# Edit docker-compose.yml as needed
docker compose up -d
```

## Image Tags

| Tag | Description |
|-----|-------------|
| `ubuntu-xfce` | XFCE desktop (default, recommended) |
| `ubuntu-lxqt` | LXQt desktop (lightest) |
| `ubuntu-kde` | KDE desktop |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` / `PGID` | `1000` | Container user/group ID |
| `CUSTOM_USER` / `PASSWORD` | unset | Webtop HTTP Basic authentication; required for remote access |
| `TZ` | `Etc/UTC` | Timezone |
| `LC_ALL` | - | Locale (e.g., `zh_CN.UTF-8`) |
| `START_DOCKER` | `false` | Enable Docker inside container (requires `--privileged`) |
| `USE_CHINA_MIRROR` | `false` | Switch to China mirrors at runtime |
| `AGENT_WORKSPACE_AGENT` | `codex` | First-boot Agent: `codex`, `claude-code`, `hermes`, or `none` |
| `SSH_PASSWORD` | unset | Set to enable SSH service (port 22), value is abc user password |
| `NODE_OPTIONS` | - | Node.js options (e.g., `--max-old-space-size=2048`) |
| `XFCE_PANEL_SCALING` | `true` | Keep XFCE panel rows and icons in step with Wayland scaling; set to `false` to disable |

## Docker Modes

| Mode | Configuration | Description |
|------|---------------|-------------|
| Disabled | Default | No Docker functionality |
| DinD | `--privileged` + `START_DOCKER=true` | Standalone Docker engine inside container |
| Host Socket | `-v /var/run/docker.sock:/var/run/docker.sock` | Share host Docker daemon |

## GPU Acceleration

| GPU Type | Configuration |
|----------|---------------|
| NVIDIA | `--gpus all -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=all --device /dev/dri:/dev/dri` |
| Intel/AMD | `--device /dev/dri:/dev/dri -e DRINODE=/dev/dri/renderD128 -e DRI_NODE=/dev/dri/renderD128` |

> The install script auto-detects GPU and configures accordingly.
>
> Selkies settings inherit upstream defaults. Add `-e PIXELFLUX_WAYLAND=false` only for a confirmed Wayland compatibility issue; X11 cannot use the upstream Wayland zero-copy encoding path.

## Built-in Toolchain

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 22 LTS | + npm, pnpm, TypeScript |
| Go | 1.22.4 | |
| Rust | stable | + Cargo |
| Python 3 | System | + pip, venv, uv |
| Homebrew | Latest | Linux version, persisted to data dir |
| docker-systemctl-replacement | Latest | systemd replacement for agent process management |

## Application Capability Management

The image focuses on stable system dependencies, desktop/runtime tooling, and
base s6 services. Faster-moving application capabilities such as proxy routing,
code-server extensions, and Agent installers are managed by
`agent-workspace-manager` and installed under the persistent `/config` volume.

Run it inside the container to open the TUI:

```bash
agent-workspace-manager
```

The TUI supports Up/Down selection and Enter to run actions. Download and
installation output stays in the in-app log panel instead of writing back to the
raw terminal. Agent installation is handled by the manager flow itself; it does
not launch a nested TUI.

Common commands:

```bash
# Update application source to /config/agent-workspace-manager/source
agent-workspace-manager update

# Install the secure remote foundation: code-server, extensions, custom s6 registration
agent-workspace-manager install foundation

# Optional: Caddy/proxyctl for an existing wildcard domain and upstream gateway
PROXY_ROOT_DOMAIN=dev.example.com agent-workspace-manager install proxyctl

# Show application capability status
agent-workspace-manager status
```

Set `AGENT_WORKSPACE_SOURCE_DIR` to use an existing checkout while developing.
By default, source is persisted at `/config/agent-workspace-manager/source`.
See [Agent Workspace Manager](docs/agent-workspace-manager.md).

## Agent Software

`agent-workspace-manager install agents` installs Codex by default, or accepts
one or more explicit Agent names:

```bash
agent-workspace-manager install agents codex
agent-workspace-manager install agents claude-code hermes
```

| Agent | Type | Installer | Post-install setup |
|-------|------|-----------|--------------------|
| Codex | Interactive CLI | [Official OpenAI installer](https://learn.chatgpt.com/docs/codex/cli) | `codex` |
| Claude Code | Interactive CLI | [Official Anthropic installer](https://code.claude.com/docs/en/quickstart) | `claude` |
| Hermes Agent | Interactive CLI | [Official Nous Research installer](https://hermes-agent.nousresearch.com/docs/) | `hermes setup --portal` |
| OpenClaw | Daemon, port 18789 | npm | `openclaw onboard` |
| Openfang | Daemon, port 4200 | Official shell installer | `openfang init` |
| ZeroClaw | Daemon, port 42617 | brew | `zeroclaw onboard` |

Codex, Claude Code, and Hermes run directly in a project terminal and are not
registered as background services. Daemon-style Agents use the user service
manager. All three interactive Agents receive workspace instructions and can
operate the current container through one stable command surface:

```bash
workspacectl info
workspacectl services
workspacectl service restart openclaw
workspacectl s6 status svc-selkies
workspacectl logs openclaw
workspacectl ports

# Once one Agent works, ask it to install another as needed
workspacectl install agent claude-code
```

`/config` is the only persistence boundary. Seeded `/config/Workspace/AGENTS.md`
and `CLAUDE.md` files explain it to Agents without overwriting existing user
files. Mounting the host Docker socket gives an Agent high privilege outside the
container; `workspacectl info` makes that boundary explicit.
Agent sign-in state and configuration are written beneath `HOME=/config`, so
they persist with the single `/config` data volume.

## Optional Capability Modules

The repository includes optional modules that can be installed into a running
workspace when needed. Use `agent-workspace-manager` for normal installation;
the module source remains available for development:

| Module | Path | Description |
|--------|------|-------------|
| code-server | `addons/code-server` | Official standalone runtime, password authentication, and persistent user service |
| proxyctl + Caddy routing | `addons/proxyctl` | Optional wildcard routing for deployments with existing DNS, TLS, and gateway authentication |
| Service Manager extension | `extensions/service-manager` | View and manage s6 / systemd services from the code-server sidebar |
| Caddy Proxy extension | `extensions/caddy-proxy-manager` | View and manage proxyctl routes from the code-server sidebar |
| Selkies Desktop extension | `extensions/selkies-desktop` | Open and initialize the Selkies desktop inside code-server |
| Custom s6 services | `scripts/register-config-services.sh` | Automatically register `/config/custom-services.d/<name>/run` with s6 |

Install the code-server extensions:

```bash
agent-workspace-manager install code-server-extensions
```

See `addons/proxyctl/README.md` for proxyctl details and [code-server Extensions](docs/code-server-extensions.md) for extension usage.

## Data Persistence

The container's `/config` directory is mapped to the host data directory. Persisted data includes:

- Homebrew packages (`/config/.linuxbrew`; `/home/linuxbrew/.linuxbrew` is only a compatibility symlink and does not need a separate mount)
- npm global packages (`/config/.npm-global`)
- Go workspace (`/config/go`)
- Cargo packages (`/config/.cargo`)
- pip/uv cache (`/config/.cache`)
- Desktop settings and user files
- code-server runtime and configuration (`/config/opt/code-server`, `/config/.config/code-server`)
- Custom s6 services (`/config/custom-services.d/<name>/run`, automatically registered into `/run/service` at startup)

### Custom s6 Services

At startup, the built-in `custom-services` s6 service scans `/config/custom-services.d` after the base `init` service completes and registers services with s6.

Create services as:

```text
/config/custom-services.d/<service-name>/run
```

The `run` file must be executable. After container recreation, services are automatically registered and started as long as `/config` is persisted. See [Persistent Custom s6 Services](docs/custom-s6-services.md).

## Custom Build

```bash
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace

# Default build (XFCE + international mirrors)
docker compose build

# KDE desktop
DESKTOP=kde docker compose build

# China mirrors for faster build
USE_CHINA_MIRROR=true docker compose build
```

## Common Commands

```bash
# View logs
docker logs -f agent-workspace

# Enter container
docker exec -it agent-workspace bash

# Stop/Start
docker stop agent-workspace
docker start agent-workspace
```

## Notes

- Selkies WebRTC has no password by default. Use a reverse proxy with authentication for public exposure.
- Homebrew is persisted to `/config/.linuxbrew`; do not mount `/home/linuxbrew/.linuxbrew` separately.
- LinuxServer automatically initializes the `/config` directory on first startup.

## Architecture Support

| Architecture | Docker Platform |
|-------------|-----------------|
| x86-64 | `linux/amd64` |
| ARM64 | `linux/arm64` |

## Links

- [LinuxServer Webtop Docs](https://docs.linuxserver.io/images/docker-webtop/)
- [Docker Hub](https://hub.docker.com/r/xuping/agent-workspace)
- [GitHub](https://github.com/fliaping/agent-workspace)
