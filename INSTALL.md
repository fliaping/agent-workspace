# Agent Workspace 安装指南

## 📋 系统要求

### Linux 服务器
- **操作系统**: Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+, Fedora 30+, Arch Linux, Alpine
- **内存**: 至少 4GB 可用内存（推荐 8GB+）
- **磁盘**: 至少 20GB 可用空间
- **网络**: 可访问 Docker Hub 或配置了镜像加速

### Windows 桌面
- **操作系统**: Windows 10/11 (64-bit)
- **内存**: 至少 8GB 可用内存
- **前置软件**: Docker Desktop for Windows

### macOS 桌面
- **操作系统**: macOS 10.15+ (Intel/Apple Silicon)
- **内存**: 至少 8GB 可用内存
- **前置软件**: Docker Desktop for Mac 或 OrbStack

---

## 🚀 安装方式

### 方式一：一键安装脚本（推荐）

#### Linux/macOS
```bash
# 使用 curl
curl -fsSL https://raw.githubusercontent.com/fliaping/agent-workspace/main/quick-install.sh | bash

# 或使用 wget
wget -qO- https://raw.githubusercontent.com/fliaping/agent-workspace/main/quick-install.sh | bash
```

#### Windows (PowerShell 管理员)
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fliaping/agent-workspace/main/install.ps1" -OutFile "install.ps1"; .\install.ps1
```

**脚本会自动完成：**
1. 检测操作系统类型
2. Linux服务器：自动安装Docker（如未安装）
3. 桌面环境：检查Docker Desktop/OrbStack是否运行
4. 选择镜像版本（中文/英文）
5. 配置VNC密码（可选）
6. 创建数据持久化目录
7. 拉取并启动容器

---

### 方式二：手动安装

#### 步骤 1: 安装 Docker

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

**Linux (CentOS/RHEL/Fedora):**
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
```

**Windows/macOS:**
下载并安装 [Docker Desktop](https://www.docker.com/products/docker-desktop)

#### 步骤 2: 启动容器

```bash
# 中文版（推荐国内用户）
docker run -d --name agent-workspace -p 6901:6901 -p 19789:18789 --privileged \
  -v $(pwd)/agent-workspace-data:/home/kasm-user \
  xuping/agent-workspace:v1.0.0-zh

# 英文版
docker run -d --name agent-workspace -p 6901:6901 -p 19789:18789 --privileged \
  -v $(pwd)/agent-workspace-data:/home/kasm-user \
  xuping/agent-workspace:v1.0.0-en
```

---

### 方式三：Docker Compose

```bash
# 克隆仓库
git clone https://github.com/fliaping/agent-workspace.git
cd agent-workspace

# 编辑 docker-compose.yml 选择版本（zh/en）
# 然后启动
docker compose up -d
```

---

## 🔧 配置说明

### 端口映射
| 端口 | 用途 |
|------|------|
| 6901 | VNC Web 桌面访问 |
| 19789 | Agent 服务端口 |

### 环境变量
| 变量 | 说明 | 默认值 |
|------|------|--------|
| `VNC_PW` | VNC 密码 | 无（不设置则免密） |
| `VNCOPTIONS` | VNC 选项 | `-disableBasicAuth` |

### 数据持久化
容器内的 `/home/kasm-user` 目录会映射到宿主机的 `./agent-workspace-data`，包含：
- 用户配置文件
- 安装的软件包缓存 (pip/npm/cargo/homebrew)
- 项目代码和工作文件

---

## 🌐 访问服务

启动后访问：
- **VNC 桌面**: `http://localhost:6901/vnc/`
- **Agent 端口**: `localhost:19789`

如果是远程服务器，将 `localhost` 替换为服务器 IP。

---

## ❓ 常见问题

### Q: 镜像拉取超时/失败
**A:** 配置 Docker 镜像加速：
```bash
# Linux
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://docker.m.daocloud.io",
    "https://dockerproxy.net"
  ]
}
EOF
sudo systemctl restart docker
```

### Q: Windows 上 Docker Desktop 启动失败
**A:** 
1. 确保已启用 WSL2: `wsl --install`
2. 在 Docker Desktop 设置中启用 WSL2 后端
3. 重启电脑后重试

### Q: 容器启动后立即退出
**A:** 查看日志排查问题：
```bash
docker logs agent-workspace
```

### Q: 如何更新到最新版本
**A:**
```bash
docker pull xuping/agent-workspace:v1.0.0-zh
docker stop agent-workspace
docker rm agent-workspace
# 重新运行安装命令
```

---

## 📞 获取帮助

- **GitHub Issues**: https://github.com/fliaping/agent-workspace/issues
- **文档**: https://github.com/fliaping/agent-workspace/blob/main/README.md
