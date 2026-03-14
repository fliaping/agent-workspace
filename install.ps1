#
# Agent Workspace 一键部署脚本 (Windows PowerShell)
# 支持: Windows 10/11 (需预装 Docker Desktop)
# 项目地址: https://github.com/fliaping/agent-workspace
#

# 配置
$IMAGE_ZH = "xuping/agent-workspace:v1.0.0-zh"
$IMAGE_EN = "xuping/agent-workspace:v1.0.0-en"
$CONTAINER_NAME = "agent-workspace"
$VNC_PORT = "6901"
$AGENT_PORT = "19789"

# 颜色定义
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# 检测Docker
function Test-Docker {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Success "Docker已安装: $dockerVersion"
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# 检测Docker Compose
function Test-DockerCompose {
    try {
        $composeVersion = docker compose version 2>$null
        if ($composeVersion) {
            Write-Success "Docker Compose已安装"
            return $true
        }
        $composeVersion = docker-compose --version 2>$null
        if ($composeVersion) {
            Write-Success "Docker Compose已安装"
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# 检查Docker Desktop是否运行
function Test-DockerRunning {
    try {
        $dockerInfo = docker info 2>$null
        if ($dockerInfo) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# 主函数
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Agent Workspace 一键部署脚本 (Windows)" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 检查Docker
    Write-Info "检查Docker环境..."
    if (-not (Test-Docker)) {
        Write-Error "未检测到Docker"
        Write-Host ""
        Write-Info "请先安装Docker Desktop:"
        Write-Host "  下载地址: https://www.docker.com/products/docker-desktop"
        Write-Host ""
        Write-Info "安装完成后请重新运行此脚本"
        exit 1
    }
    
    # 检查Docker Compose
    if (-not (Test-DockerCompose)) {
        Write-Error "Docker Compose未安装"
        Write-Info "请更新Docker Desktop到最新版本"
        exit 1
    }
    
    # 检查Docker是否运行
    if (-not (Test-DockerRunning)) {
        Write-Error "Docker Desktop未运行"
        Write-Info "请启动Docker Desktop后重试"
        exit 1
    }
    Write-Success "Docker运行正常"
    
    # 选择版本
    Write-Host ""
    Write-Info "请选择镜像版本："
    Write-Host "  1) 中文版 (内置国内加速源，推荐国内用户)"
    Write-Host "  2) 英文版 (官方源，适合海外用户)"
    Write-Host ""
    $versionChoice = Read-Host "请输入选项 [1-2，默认1]"
    
    switch ($versionChoice) {
        "2" { $selectedImage = $IMAGE_EN; Write-Info "已选择: 英文版" }
        default { $selectedImage = $IMAGE_ZH; Write-Info "已选择: 中文版" }
    }
    
    # 配置VNC密码
    Write-Host ""
    $setVncPass = Read-Host "是否设置VNC密码? [y/N]"
    $vncPw = ""
    $vncOptions = "-disableBasicAuth"
    
    if ($setVncPass -eq "y" -or $setVncPass -eq "Y") {
        $securePassword = Read-Host "请输入VNC密码" -AsSecureString
        $vncPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
        $vncOptions = ""
        Write-Info "VNC密码已设置"
    } else {
        Write-Warning "VNC将不使用密码 (仅建议本地使用)"
    }
    
    # 设置数据目录
    $dataDir = Join-Path $PWD "agent-workspace-data"
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir | Out-Null
        Write-Info "创建数据目录: $dataDir"
    }
    
    # 拉取镜像
    Write-Info "正在拉取镜像: $selectedImage"
    try {
        docker pull $selectedImage
        Write-Success "镜像拉取成功"
    } catch {
        Write-Error "镜像拉取失败"
        Write-Host ""
        Write-Info "可能的原因："
        Write-Host "  1. 网络连接问题，请检查网络"
        Write-Host "  2. Docker Hub访问受限，请配置镜像加速"
        Write-Host ""
        Write-Info "配置镜像加速方法："
        Write-Host "  打开Docker Desktop → Settings → Docker Engine"
        Write-Host '  添加: "registry-mirrors": ["https://docker.1panel.live"]'
        exit 1
    }
    
    # 检查并删除旧容器
    $existingContainer = docker ps -a --format "{{.Names}}" | Select-String "^$CONTAINER_NAME$"
    if ($existingContainer) {
        Write-Warning "容器 $CONTAINER_NAME 已存在"
        $recreate = Read-Host "是否删除旧容器并重新创建? [y/N]"
        if ($recreate -eq "y" -or $recreate -eq "Y") {
            docker stop $CONTAINER_NAME 2>$null
            docker rm $CONTAINER_NAME 2>$null
            Write-Info "旧容器已删除"
        } else {
            Write-Info "尝试启动已有容器..."
            docker start $CONTAINER_NAME
            Write-Success "容器已启动"
            Print-AccessInfo -VncPassword $vncPw
            return
        }
    }
    
    # 启动容器
    Write-Info "正在启动Agent Workspace容器..."
    
    $dockerArgs = @(
        "run", "-d",
        "--name", $CONTAINER_NAME,
        "-p", "${VNC_PORT}:6901",
        "-p", "${AGENT_PORT}:18789",
        "--privileged",
        "--restart", "unless-stopped",
        "--shm-size", "2gb"
    )
    
    if ($vncOptions) {
        $dockerArgs += @("-e", "VNCOPTIONS=$vncOptions")
    }
    if ($vncPw) {
        $dockerArgs += @("-e", "VNC_PW=$vncPw")
    }
    
    $dockerArgs += @(
        "-e", "NODE_OPTIONS=--max-old-space-size=2048",
        "-e", "CHROME_FLAGS=--js-flags='--max-old-space-size=512' --memory-model=low",
        "-v", "${dataDir}:/home/kasm-user",
        $selectedImage
    )
    
    try {
        & docker @dockerArgs
        Write-Success "容器启动成功"
    } catch {
        Write-Error "容器启动失败"
        exit 1
    }
    
    # 等待服务就绪
    Write-Info "等待服务启动..."
    $maxAttempts = 30
    $attempt = 1
    $ready = $false
    
    while ($attempt -le $maxAttempts) {
        $logs = docker logs $CONTAINER_NAME 2>&1
        if ($logs -match "KasmVNC") {
            Start-Sleep -Seconds 2
            Write-Success "服务已就绪"
            $ready = $true
            break
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    if (-not $ready) {
        Write-Warning "服务启动可能需要更长时间，请稍后手动检查"
    }
    
    Print-AccessInfo -VncPassword $vncPw
}

# 打印访问信息
function Print-AccessInfo {
    param(
        [string]$VncPassword = ""
    )
    
    $dataDir = Join-Path $PWD "agent-workspace-data"
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Success "Agent Workspace 部署完成!"
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Info "🖥️  VNC桌面访问:"
    Write-Host "    http://localhost:$VNC_PORT/vnc/"
    Write-Host ""
    Write-Info "📡 Agent服务端口: $AGENT_PORT"
    Write-Host ""
    Write-Info "💾 数据持久化目录: $dataDir"
    Write-Host ""
    
    if ($VncPassword) {
        Write-Info "🔒 VNC密码: 已设置"
    } else {
        Write-Warning "⚠️  VNC未设置密码，建议仅本地使用"
    }
    
    Write-Host ""
    Write-Info "📋 常用命令："
    Write-Host "    查看日志: docker logs -f $CONTAINER_NAME"
    Write-Host "    停止服务: docker stop $CONTAINER_NAME"
    Write-Host "    启动服务: docker start $CONTAINER_NAME"
    Write-Host "    进入容器: docker exec -it $CONTAINER_NAME bash"
    Write-Host "    删除容器: docker rm -f $CONTAINER_NAME"
    Write-Host ""
    Write-Info "📖 文档地址: https://github.com/fliaping/agent-workspace"
    Write-Host "========================================" -ForegroundColor Green
}

# 运行主函数
Main
