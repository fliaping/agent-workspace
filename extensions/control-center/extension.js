const vscode = require('vscode');
const fs = require('fs/promises');
const path = require('path');
const { execFile } = require('child_process');

const VIEW_ID = 'agentWorkspace.quickView';
const PANEL_TYPE = 'agentWorkspace.controlCenter';
const OUTPUT = vscode.window.createOutputChannel('Agent Workspace');
const ONBOARDING_MARKER = '/config/.local/state/agent-workspace/onboarding-v1.complete';
const VALID_NAME = /^[A-Za-z0-9_.@-]+$/;
const AGENT_IDS = new Set(['codex', 'claude-code', 'hermes']);

function nonce() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let value = '';
  for (let index = 0; index < 32; index += 1) {
    value += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  }
  return value;
}

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, {
      timeout: options.timeout ?? 20000,
      maxBuffer: options.maxBuffer ?? 8 * 1024 * 1024,
      env: { ...process.env, HOME: process.env.HOME || '/config' }
    }, (error, stdout, stderr) => {
      resolve({
        ok: !error,
        code: error && typeof error.code === 'number' ? error.code : 0,
        stdout: stdout.toString(),
        stderr: stderr.toString(),
        error
      });
    });
  });
}

function strings() {
  const zh = vscode.env.language.toLowerCase().startsWith('zh');
  if (!zh) {
    return {
      overview: 'Overview', agents: 'Agents', services: 'Services', network: 'Network', diagnostics: 'Diagnostics',
      title: 'Agent Workspace', subtitle: 'One place to understand and operate your remote Agent environment.',
      ready: 'Workspace ready', attention: 'Needs attention', refreshing: 'Refreshing', refresh: 'Refresh',
      openDesktop: 'Open desktop', openTerminal: 'Open terminal', openWorkspace: 'Open workspace',
      quickStart: 'Quick start', environment: 'Environment', installedAgents: 'Ready Agents', runningServices: 'Running services',
      secureMode: 'Docker boundary', capabilities: 'Capabilities', recentServices: 'Workspace services', viewAll: 'View all',
      install: 'Install', launch: 'Launch', installed: 'Installed', optional: 'Optional', missing: 'Missing', selected: 'Selected',
      versionUnknown: 'Version unavailable', noAgents: 'No Agent installed yet', agentHelp: 'Install one Agent first; it can help configure everything else.',
      service: 'Service', kind: 'Kind', status: 'Status', actions: 'Actions', searchServices: 'Filter services…',
      start: 'Start', stop: 'Stop', restart: 'Restart', logs: 'Logs', noServices: 'No services found',
      access: 'Access', listeningPorts: 'Listening ports', proxyRoutes: 'Proxy routes', installProxy: 'Install proxy routing',
      addRoute: 'Add route', checkProxy: 'Check proxy', remove: 'Remove', open: 'Open', noRoutes: 'No named routes configured.',
      command: 'Process', address: 'Address', doctor: 'Environment checks', revision: 'Application revision',
      onboardingTitle: 'Welcome to Agent Workspace', onboardingSubtitle: 'Your environment is running. Take a minute to learn the important entry points.',
      stepWelcome: 'Welcome', stepAgent: 'Agent', stepWorkspace: 'Workspace', stepAccess: 'Access', stepOptional: 'Finish',
      back: 'Back', next: 'Continue', finish: 'Finish setup', skip: 'Skip guide',
      welcomeBody: 'The foundation is installed automatically. Control Center will stay available from the Agent Workspace icon.',
      agentBody: 'Start with one working Agent. Sign in from a terminal, then let it help with the rest of the environment.',
      workspaceBody: 'Projects and Agent context live in the durable workspace directory.',
      accessBody: 'Desktop and code-server are password protected. Use a private network, gateway, or SSH tunnel for remote access.',
      optionalBody: 'Everything else is optional. Add another Agent or proxy routing only when you need it.',
      foundationReady: 'Foundation ready', foundationWorking: 'Foundation is still being prepared',
      signInHint: 'Launch the Agent and follow its normal sign-in flow.',
      dockerSafe: 'Safe default', dockerElevated: 'Elevated access', dockerMedium: 'Isolated daemon',
      dockerSocketLabel: 'Docker socket connected', dockerSocketDetail: 'Agents can control containers reachable through the mounted socket.',
      dockerIsolatedLabel: 'Isolated Docker available', dockerIsolatedDetail: 'Agents can create containers in this workspace Docker daemon.',
      dockerDisabledLabel: 'Docker disabled', dockerDisabledDetail: 'No Docker daemon is available inside this workspace.',
      copyTunnel: 'Copy SSH tunnel', localAddresses: 'Docker-host addresses', detail: 'Details',
      healthy: 'Healthy', failed: 'Failed', unknown: 'Unknown', noPorts: 'No listening ports detected.',
      installCapability: 'Install capability', updateSource: 'Update application source', showOutput: 'Show operation log'
    };
  }
  return {
    overview: '总览', agents: 'Agents', services: '服务', network: '网络', diagnostics: '诊断',
    title: 'Agent Workspace', subtitle: '在一个地方了解和管理你的远程 Agent 环境。',
    ready: '工作区已就绪', attention: '需要处理', refreshing: '正在刷新', refresh: '刷新',
    openDesktop: '打开桌面', openTerminal: '打开终端', openWorkspace: '打开工作区',
    quickStart: '快速开始', environment: '环境', installedAgents: '可用 Agent', runningServices: '运行中服务',
    secureMode: 'Docker 权限边界', capabilities: '功能组件', recentServices: '工作区服务', viewAll: '查看全部',
    install: '安装', launch: '启动', installed: '已安装', optional: '可选', missing: '缺失', selected: '首选',
    versionUnknown: '未知版本', noAgents: '尚未安装 Agent', agentHelp: '先安装一个 Agent，它就可以继续协助配置其他能力。',
    service: '服务', kind: '类型', status: '状态', actions: '操作', searchServices: '筛选服务…',
    start: '启动', stop: '停止', restart: '重启', logs: '日志', noServices: '未发现服务',
    access: '访问方式', listeningPorts: '监听端口', proxyRoutes: '代理路由', installProxy: '安装代理路由',
    addRoute: '添加路由', checkProxy: '检查代理', remove: '删除', open: '打开', noRoutes: '尚未配置命名路由。',
    command: '进程', address: '地址', doctor: '环境检查', revision: '应用版本',
    onboardingTitle: '欢迎使用 Agent Workspace', onboardingSubtitle: '环境已经运行，用一分钟了解最重要的入口。',
    stepWelcome: '欢迎', stepAgent: 'Agent', stepWorkspace: '工作区', stepAccess: '访问', stepOptional: '完成',
    back: '上一步', next: '继续', finish: '完成向导', skip: '跳过向导',
    welcomeBody: '基础能力会自动安装。以后随时可以从左侧 Agent Workspace 图标回到控制中心。',
    agentBody: '先保证一个 Agent 可用。在终端完成登录后，就可以让它继续配置其他环境能力。',
    workspaceBody: '项目与 Agent 上下文都放在持久化工作区目录中，容器重建后仍会保留。',
    accessBody: '桌面和 code-server 都有密码保护。远程访问请使用内网、认证网关或 SSH 隧道。',
    optionalBody: '其他功能都是可选的。只有需要时再安装其他 Agent 或代理路由。',
    foundationReady: '基础环境已就绪', foundationWorking: '基础环境仍在准备',
    signInHint: '启动 Agent，并按照它的正常流程完成登录。',
    dockerSafe: '安全默认值', dockerElevated: '高权限访问', dockerMedium: '隔离 Docker',
    dockerSocketLabel: '已连接 Docker Socket', dockerSocketDetail: 'Agent 可以控制通过该 Socket 可达的容器，请把它视为容器外的高权限。',
    dockerIsolatedLabel: '可用的隔离 Docker', dockerIsolatedDetail: 'Agent 可以在工作区自己的 Docker 守护进程中创建容器。',
    dockerDisabledLabel: 'Docker 未启用', dockerDisabledDetail: '当前工作区内没有可用的 Docker 守护进程。',
    copyTunnel: '复制 SSH 隧道', localAddresses: 'Docker 主机地址', detail: '详情',
    healthy: '正常', failed: '失败', unknown: '未知', noPorts: '未检测到监听端口。',
    installCapability: '安装能力', updateSource: '更新应用源码', showOutput: '查看操作日志'
  };
}

class ControlCenter {
  constructor(context) {
    this.context = context;
    this.panel = undefined;
    this.quickView = undefined;
    this.snapshot = undefined;
    this.refreshPromise = undefined;
    this.interval = undefined;
    this.forceWelcome = false;
    this.statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 45);
    this.statusBar.command = 'agentWorkspace.openControlCenter';
    this.statusBar.name = 'Agent Workspace';
    this.statusBar.text = '$(loading~spin) Agent Workspace';
    this.statusBar.tooltip = 'Open Agent Workspace Control Center';
    this.statusBar.show();
    context.subscriptions.push(this.statusBar, OUTPUT);
  }

  config() {
    const cfg = vscode.workspace.getConfiguration('agentWorkspace');
    return {
      workspacectl: cfg.get('workspacectlPath', '/config/bin/workspacectl'),
      autoOpen: cfg.get('autoOpenOnFirstRun', true),
      refreshInterval: cfg.get('refreshInterval', 30),
      desktopUrl: cfg.get('desktopUrl', 'https://localhost:3001')
    };
  }

  async loadSnapshot() {
    const result = await run(this.config().workspacectl, ['status', '--json'], { timeout: 30000 });
    if (!result.ok) {
      throw new Error((result.stderr || result.stdout || 'workspacectl failed').trim());
    }
    return JSON.parse(result.stdout);
  }

  async refresh(showError = false) {
    if (this.refreshPromise) return this.refreshPromise;
    this.broadcast({ type: 'refreshing' });
    this.refreshPromise = this.loadSnapshot()
      .then((snapshot) => {
        this.snapshot = snapshot;
        this.updateStatusBar();
        this.broadcast({ type: 'snapshot', data: snapshot, forceWelcome: this.forceWelcome });
        return snapshot;
      })
      .catch((error) => {
        OUTPUT.appendLine(`Refresh failed: ${error.message}`);
        this.statusBar.text = '$(warning) Agent Workspace';
        this.statusBar.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
        this.broadcast({ type: 'error', message: error.message });
        if (showError) vscode.window.showErrorMessage(`Agent Workspace: ${error.message}`);
        return undefined;
      })
      .finally(() => {
        this.refreshPromise = undefined;
      });
    return this.refreshPromise;
  }

  updateStatusBar() {
    const healthy = this.snapshot && this.snapshot.summary && this.snapshot.summary.healthy;
    const ready = this.snapshot && this.snapshot.bootstrap && this.snapshot.bootstrap.foundation_ready;
    this.statusBar.text = healthy && ready ? '$(check) Agent Workspace' : '$(warning) Agent Workspace';
    this.statusBar.backgroundColor = healthy && ready
      ? undefined
      : new vscode.ThemeColor('statusBarItem.warningBackground');
    this.statusBar.tooltip = healthy && ready
      ? 'Agent Workspace is ready — open Control Center'
      : 'Agent Workspace needs attention — open Control Center';
  }

  broadcast(message) {
    if (this.panel) this.panel.webview.postMessage(message);
    if (this.quickView) this.quickView.webview.postMessage(message);
  }

  attach(webview, kind) {
    webview.options = { enableScripts: true };
    webview.html = kind === 'quick' ? quickViewHtml(webview) : controlCenterHtml(webview, this.forceWelcome);
    webview.onDidReceiveMessage((message) => this.handleMessage(message));
  }

  resolveWebviewView(view) {
    this.quickView = view;
    this.attach(view.webview, 'quick');
    if (typeof view.onDidDispose === 'function') {
      view.onDidDispose(() => {
        if (this.quickView === view) this.quickView = undefined;
      });
    }
  }

  open(forceWelcome = false) {
    this.forceWelcome = forceWelcome;
    if (this.panel) {
      this.panel.reveal(vscode.ViewColumn.Active, false);
      this.panel.webview.postMessage({ type: 'showWelcome', value: forceWelcome });
      this.refresh();
      return;
    }
    const panel = vscode.window.createWebviewPanel(
      PANEL_TYPE,
      'Agent Workspace',
      vscode.ViewColumn.Active,
      { enableScripts: true, retainContextWhenHidden: true }
    );
    this.panel = panel;
    this.attach(panel.webview, 'panel');
    panel.onDidDispose(() => {
      if (this.panel === panel) this.panel = undefined;
      this.stopInterval();
    });
    panel.onDidChangeViewState(() => {
      if (panel.visible) {
        this.startInterval();
        this.refresh();
      } else {
        this.stopInterval();
      }
    });
    this.startInterval();
    this.refresh();
  }

  startInterval() {
    this.stopInterval();
    const seconds = Number(this.config().refreshInterval);
    if (seconds > 0) this.interval = setInterval(() => this.refresh(), seconds * 1000);
  }

  stopInterval() {
    if (this.interval) clearInterval(this.interval);
    this.interval = undefined;
  }

  terminal(command = '') {
    const terminal = vscode.window.createTerminal({
      name: 'Agent Workspace',
      cwd: '/config/Workspace',
      env: { HOME: '/config' }
    });
    terminal.show();
    if (command) terminal.sendText(command, true);
  }

  async operation(title, args, timeout = 15 * 60 * 1000) {
    OUTPUT.show(true);
    OUTPUT.appendLine(`\n==> ${title}`);
    OUTPUT.appendLine(`$ workspacectl ${args.join(' ')}`);
    const result = await vscode.window.withProgress(
      { location: vscode.ProgressLocation.Notification, title, cancellable: false },
      () => run(this.config().workspacectl, args, { timeout, maxBuffer: 16 * 1024 * 1024 })
    );
    if (result.stdout.trim()) OUTPUT.appendLine(result.stdout.trim());
    if (result.stderr.trim()) OUTPUT.appendLine(result.stderr.trim());
    if (!result.ok) {
      vscode.window.showErrorMessage(`${title} failed. See Agent Workspace output.`);
      return false;
    }
    vscode.window.showInformationMessage(`${title} complete.`);
    await this.refresh();
    return true;
  }

  async completeOnboarding() {
    await fs.mkdir(path.dirname(ONBOARDING_MARKER), { recursive: true });
    await fs.writeFile(ONBOARDING_MARKER, `${new Date().toISOString()}\n`, { mode: 0o600 });
    this.forceWelcome = false;
    await this.refresh();
  }

  async openDesktop() {
    const commands = await vscode.commands.getCommands(true);
    if (commands.includes('selkiesDesktop.open')) {
      await vscode.commands.executeCommand('selkiesDesktop.open');
      return;
    }
    await vscode.env.openExternal(vscode.Uri.parse(this.config().desktopUrl));
  }

  async handleMessage(message) {
    try {
      switch (message && message.type) {
        case 'ready':
          await this.refresh();
          break;
        case 'open':
          this.open(false);
          break;
        case 'refresh':
          await this.refresh(true);
          break;
        case 'terminal':
          this.terminal(typeof message.command === 'string' ? message.command : '');
          break;
        case 'openWorkspace':
          await vscode.commands.executeCommand('vscode.openFolder', vscode.Uri.file('/config/Workspace'));
          break;
        case 'openDesktop':
          await this.openDesktop();
          break;
        case 'installAgent':
          if (AGENT_IDS.has(message.id)) {
            await this.operation(`Install ${message.id}`, ['install', 'agent', message.id]);
          }
          break;
        case 'serviceAction':
          if (VALID_NAME.test(message.id) && ['start', 'stop', 'restart'].includes(message.action)) {
            const scope = message.kind === 's6' ? 's6' : 'service';
            await this.operation(`${message.action} ${message.id}`, [scope, message.action, message.id], 60000);
          }
          break;
        case 'showLogs':
          if (VALID_NAME.test(message.id)) {
            const result = await run(this.config().workspacectl, ['logs', message.id, '200'], { timeout: 10000 });
            OUTPUT.appendLine(`\n== ${message.id} ==`);
            OUTPUT.appendLine((result.stdout || result.stderr || '(no log output)').trim());
            OUTPUT.show(true);
          }
          break;
        case 'installProxy':
          await this.operation('Install proxy routing', ['install', 'proxyctl']);
          break;
        case 'checkProxy':
          await this.operation('Check proxy routing', ['proxy', 'check'], 60000);
          break;
        case 'addRoute':
          await this.addRoute();
          break;
        case 'removeRoute':
          await this.removeRoute(message.name, message.host);
          break;
        case 'openUrl':
          if (typeof message.url === 'string' && /^https?:\/\//.test(message.url)) {
            await vscode.env.openExternal(vscode.Uri.parse(message.url));
          }
          break;
        case 'copyTunnel':
          await vscode.env.clipboard.writeText('ssh -N -L 3001:127.0.0.1:3001 -L 8443:127.0.0.1:8443 user@server');
          vscode.window.showInformationMessage('SSH tunnel command copied.');
          break;
        case 'completeOnboarding':
          await this.completeOnboarding();
          break;
        case 'showOutput':
          OUTPUT.show(true);
          break;
        case 'updateSource':
          await this.operation('Update Agent Workspace', ['update']);
          break;
        case 'settings':
          await vscode.commands.executeCommand('workbench.action.openSettings', '@ext:agent-workspace.control-center');
          break;
      }
    } catch (error) {
      OUTPUT.appendLine(`Action failed: ${error.stack || error.message}`);
      vscode.window.showErrorMessage(`Agent Workspace: ${error.message}`);
    }
  }

  async addRoute() {
    const name = await vscode.window.showInputBox({
      title: 'Agent Workspace: Route name',
      prompt: 'Short route label, for example api or dashboard.',
      validateInput: (value) => VALID_NAME.test(value) ? undefined : 'Use letters, numbers, dot, underscore, @ or dash.'
    });
    if (!name) return;
    const target = await vscode.window.showInputBox({
      title: 'Agent Workspace: Route target',
      prompt: 'Upstream host:port reachable from this container.',
      placeHolder: '127.0.0.1:3000',
      validateInput: (value) => /^[^:\s]+:\d{1,5}$/.test(value) ? undefined : 'Use host:port.'
    });
    if (!target) return;
    await this.operation(`Add route ${name}`, ['proxy', 'add', name.trim(), target.trim()], 60000);
  }

  async removeRoute(name, host) {
    if (!VALID_NAME.test(name || '')) return;
    const choice = await vscode.window.showWarningMessage(
      `Remove route ${host || name}?`,
      { modal: true },
      'Remove'
    );
    if (choice === 'Remove') {
      await this.operation(`Remove route ${name}`, ['proxy', 'remove', name], 60000);
    }
  }
}

function quickViewHtml(webview) {
  const scriptNonce = nonce();
  const copy = strings();
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${scriptNonce}';">
<style>
  *{box-sizing:border-box} body{margin:0;padding:14px;color:var(--vscode-foreground);font:13px var(--vscode-font-family);background:var(--vscode-sideBar-background)}
  .hero{padding:16px;border:1px solid var(--vscode-widget-border);border-radius:12px;background:linear-gradient(145deg,color-mix(in srgb,var(--vscode-button-background) 18%,transparent),transparent)}
  .mark{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;background:var(--vscode-button-background);color:var(--vscode-button-foreground);font-weight:800;margin-bottom:12px}
  h2{font-size:16px;margin:0 0 5px}.muted{color:var(--vscode-descriptionForeground);line-height:1.5}.status{display:flex;align-items:center;gap:7px;margin:13px 0}.dot{width:8px;height:8px;border-radius:50%;background:var(--vscode-charts-green)}
  button{width:100%;border:0;border-radius:7px;padding:8px 10px;margin-top:8px;cursor:pointer;background:var(--vscode-button-background);color:var(--vscode-button-foreground);font:inherit;font-weight:600}
  button.secondary{background:var(--vscode-button-secondaryBackground);color:var(--vscode-button-secondaryForeground)}
  .facts{margin-top:14px;display:grid;gap:8px}.fact{display:flex;justify-content:space-between;padding-bottom:8px;border-bottom:1px solid var(--vscode-widget-border)}
</style></head><body>
<div class="hero"><div class="mark">AW</div><h2>${copy.title}</h2><div class="muted">${copy.subtitle}</div><div class="status"><span class="dot" id="dot"></span><span id="status">${copy.refreshing}</span></div><button data-action="open">${copy.overview}</button><button class="secondary" data-action="desktop">${copy.openDesktop}</button></div>
<div class="facts"><div class="fact"><span>${copy.installedAgents}</span><strong id="agents">—</strong></div><div class="fact"><span>${copy.runningServices}</span><strong id="services">—</strong></div><div class="fact"><span>${copy.secureMode}</span><strong id="docker">—</strong></div></div>
<script nonce="${scriptNonce}">const vscode=acquireVsCodeApi();document.addEventListener('click',e=>{const a=e.target.closest('[data-action]');if(!a)return;vscode.postMessage({type:a.dataset.action==='desktop'?'openDesktop':'open'});});window.addEventListener('message',e=>{if(e.data.type!=='snapshot')return;const d=e.data.data;document.getElementById('status').textContent=d.summary.healthy?'${copy.ready}':'${copy.attention}';document.getElementById('dot').style.background=d.summary.healthy?'var(--vscode-charts-green)':'var(--vscode-charts-orange)';document.getElementById('agents').textContent=d.summary.ready_agents;document.getElementById('services').textContent=d.summary.running_services+'/'+d.summary.service_count;document.getElementById('docker').textContent=d.workspace.docker.mode;});vscode.postMessage({type:'ready'});</script>
</body></html>`;
}

function controlCenterHtml(webview, forceWelcome) {
  const scriptNonce = nonce();
  const copy = strings();
  return `<!doctype html>
<html lang="${vscode.env.language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-${scriptNonce}';">
<style>
  :root{--aw-accent:#8b7cf6;--aw-cyan:#45c9c2;--aw-good:#55c98f;--aw-warn:#e5ac58;--aw-bad:#ed6b75;--aw-radius:14px;--aw-border:color-mix(in srgb,var(--vscode-foreground) 13%,transparent);--aw-soft:color-mix(in srgb,var(--vscode-editor-background) 78%,var(--aw-accent) 22%)}
  *{box-sizing:border-box}html,body{margin:0;min-height:100%;background:var(--vscode-editor-background);color:var(--vscode-foreground);font:13px/1.5 var(--vscode-font-family)}button,input{font:inherit}.app{min-height:100vh;background:radial-gradient(circle at 82% -5%,color-mix(in srgb,var(--aw-accent) 16%,transparent),transparent 32%),radial-gradient(circle at 8% 100%,color-mix(in srgb,var(--aw-cyan) 10%,transparent),transparent 30%)}
  .topbar{height:70px;padding:0 26px;display:flex;align-items:center;gap:14px;border-bottom:1px solid var(--aw-border);background:color-mix(in srgb,var(--vscode-editor-background) 88%,transparent);position:sticky;top:0;z-index:5;backdrop-filter:blur(12px)}.brand{display:flex;align-items:center;gap:11px;min-width:0}.logo{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:linear-gradient(135deg,var(--aw-accent),#5a9bf8);color:white;font-weight:800;box-shadow:0 8px 26px color-mix(in srgb,var(--aw-accent) 28%,transparent)}.brand h1{font-size:16px;margin:0}.brand p{margin:1px 0 0;color:var(--vscode-descriptionForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.top-actions{margin-left:auto;display:flex;align-items:center;gap:9px}.pill{display:inline-flex;align-items:center;gap:7px;border:1px solid var(--aw-border);border-radius:999px;padding:5px 10px;background:var(--vscode-editorWidget-background)}.pill .dot{width:7px;height:7px;border-radius:50%;background:var(--aw-good)}
  .shell{display:grid;grid-template-columns:210px minmax(0,1fr);max-width:1440px;margin:0 auto;min-height:calc(100vh - 70px)}.nav{padding:24px 16px;border-right:1px solid var(--aw-border)}.nav-list{display:grid;gap:5px;position:sticky;top:94px}.nav button{border:0;background:transparent;color:var(--vscode-foreground);border-radius:9px;padding:9px 11px;text-align:left;cursor:pointer;display:flex;gap:10px;align-items:center}.nav button:hover{background:var(--vscode-list-hoverBackground)}.nav button.active{background:color-mix(in srgb,var(--aw-accent) 18%,transparent);color:color-mix(in srgb,var(--vscode-foreground) 86%,var(--aw-accent) 14%);font-weight:650}.nav .icon{width:19px;text-align:center}.nav-note{margin-top:22px;padding:12px;border:1px solid var(--aw-border);border-radius:11px;color:var(--vscode-descriptionForeground);font-size:12px;overflow-wrap:anywhere}
  main{padding:30px clamp(20px,4vw,52px) 60px;min-width:0}.page-head{display:flex;align-items:flex-end;justify-content:space-between;gap:16px;margin-bottom:22px}.page-head h2{font-size:25px;letter-spacing:-.02em;margin:0}.page-head p{margin:5px 0 0;color:var(--vscode-descriptionForeground);font-size:14px}.grid{display:grid;grid-template-columns:repeat(12,minmax(0,1fr));gap:15px}.card{border:1px solid var(--aw-border);border-radius:var(--aw-radius);background:color-mix(in srgb,var(--vscode-editorWidget-background) 86%,transparent);padding:18px;box-shadow:0 9px 30px color-mix(in srgb,#000 8%,transparent)}.span-12{grid-column:span 12}.span-8{grid-column:span 8}.span-6{grid-column:span 6}.span-4{grid-column:span 4}.span-3{grid-column:span 3}.card h3{font-size:14px;margin:0 0 4px}.muted{color:var(--vscode-descriptionForeground)}.metric{font-size:27px;letter-spacing:-.03em;font-weight:720;margin-top:11px}.metric small{font-size:12px;font-weight:500;color:var(--vscode-descriptionForeground)}
  .hero{padding:25px;background:linear-gradient(135deg,color-mix(in srgb,var(--aw-accent) 22%,var(--vscode-editorWidget-background)),color-mix(in srgb,var(--aw-cyan) 9%,var(--vscode-editorWidget-background)));overflow:hidden;position:relative}.hero:after{content:'';position:absolute;width:220px;height:220px;border-radius:50%;right:-80px;top:-120px;border:35px solid color-mix(in srgb,#fff 7%,transparent)}.hero h2{font-size:25px;margin:0 0 7px;letter-spacing:-.025em}.hero p{max-width:650px;margin:0;color:var(--vscode-descriptionForeground);font-size:14px}.hero-actions{display:flex;gap:9px;flex-wrap:wrap;margin-top:20px;position:relative;z-index:1}
  .button{border:1px solid transparent;border-radius:8px;padding:7px 12px;cursor:pointer;background:var(--vscode-button-background);color:var(--vscode-button-foreground);font-weight:620;display:inline-flex;align-items:center;justify-content:center;gap:7px;text-decoration:none}.button:hover{background:var(--vscode-button-hoverBackground)}.button.secondary{background:var(--vscode-button-secondaryBackground);color:var(--vscode-button-secondaryForeground)}.button.ghost{background:transparent;color:var(--vscode-foreground);border-color:var(--aw-border)}.button.danger{background:color-mix(in srgb,var(--aw-bad) 18%,transparent);color:var(--vscode-foreground);border-color:color-mix(in srgb,var(--aw-bad) 42%,transparent)}.button.small{padding:4px 8px;font-size:12px}.button:disabled{opacity:.48;cursor:not-allowed}.icon-button{width:32px;height:32px;padding:0;border-radius:9px}.section-title{display:flex;justify-content:space-between;align-items:center;margin-bottom:13px}.section-title h3{margin:0;font-size:15px}
  .agent-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:15px}.agent-card{position:relative;overflow:hidden}.agent-card:before{content:'';position:absolute;inset:0 auto 0 0;width:3px;background:var(--agent,var(--aw-accent))}.agent-top{display:flex;align-items:center;gap:11px}.agent-avatar{width:39px;height:39px;border-radius:12px;display:grid;place-items:center;background:color-mix(in srgb,var(--agent,var(--aw-accent)) 18%,transparent);color:var(--agent,var(--aw-accent));font-weight:800}.agent-name{font-size:15px;font-weight:680}.agent-actions{display:flex;gap:8px;margin-top:16px}.badge{display:inline-flex;border-radius:999px;padding:2px 8px;font-size:11px;font-weight:650;background:color-mix(in srgb,var(--vscode-foreground) 9%,transparent)}.badge.ready,.state-running{color:var(--aw-good)}.badge.optional{color:var(--vscode-descriptionForeground)}.badge.warning,.state-failed{color:var(--aw-warn)}
  .list{display:grid;gap:8px}.list-row{display:flex;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid var(--aw-border)}.list-row:last-child{border-bottom:0}.list-main{min-width:0;flex:1}.list-main strong{display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.list-main small{display:block;color:var(--vscode-descriptionForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.status-dot{width:9px;height:9px;border-radius:50%;background:var(--vscode-descriptionForeground)}.status-dot.running,.status-dot.ready{background:var(--aw-good);box-shadow:0 0 0 4px color-mix(in srgb,var(--aw-good) 14%,transparent)}.status-dot.failed,.status-dot.missing{background:var(--aw-bad)}.status-dot.optional,.status-dot.inactive,.status-dot.stopped{background:var(--vscode-descriptionForeground)}
  .table-wrap{overflow:auto;border:1px solid var(--aw-border);border-radius:12px}table{width:100%;border-collapse:collapse;min-width:720px}th,td{text-align:left;padding:10px 12px;border-bottom:1px solid var(--aw-border)}th{font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--vscode-descriptionForeground);background:color-mix(in srgb,var(--vscode-editorWidget-background) 75%,transparent);position:sticky;top:0}tr:last-child td{border-bottom:0}.row-actions{display:flex;gap:5px;justify-content:flex-end}.filter{width:min(320px,100%);border:1px solid var(--aw-border);border-radius:8px;padding:7px 10px;background:var(--vscode-input-background);color:var(--vscode-input-foreground);outline:0}.filter:focus{border-color:var(--vscode-focusBorder)}
  .risk{display:flex;align-items:flex-start;gap:12px}.risk-icon{width:38px;height:38px;border-radius:12px;display:grid;place-items:center;background:color-mix(in srgb,var(--aw-good) 14%,transparent);color:var(--aw-good);font-weight:800}.risk.high .risk-icon{background:color-mix(in srgb,var(--aw-bad) 14%,transparent);color:var(--aw-bad)}.risk.medium .risk-icon{background:color-mix(in srgb,var(--aw-warn) 14%,transparent);color:var(--aw-warn)}.code{font:12px/1.55 var(--vscode-editor-font-family);background:var(--vscode-textCodeBlock-background);padding:9px 11px;border-radius:8px;overflow-wrap:anywhere;margin-top:9px}.empty{padding:28px;text-align:center;color:var(--vscode-descriptionForeground)}
  .wizard{max-width:980px;margin:0 auto}.wizard-shell{display:grid;grid-template-columns:190px minmax(0,1fr);padding:0;overflow:hidden;min-height:510px}.steps{padding:25px 18px;background:linear-gradient(180deg,color-mix(in srgb,var(--aw-accent) 18%,var(--vscode-editorWidget-background)),var(--vscode-editorWidget-background))}.steps h3{font-size:17px;margin:0 0 4px}.step-list{display:grid;gap:7px;margin-top:25px}.step{display:flex;align-items:center;gap:9px;padding:8px;border-radius:9px;color:var(--vscode-descriptionForeground)}.step.active{background:color-mix(in srgb,var(--aw-accent) 20%,transparent);color:var(--vscode-foreground);font-weight:650}.step.done .step-index{background:var(--aw-good);color:#10281e}.step-index{width:24px;height:24px;display:grid;place-items:center;border-radius:50%;border:1px solid var(--aw-border);font-size:11px}.wizard-content{padding:38px clamp(24px,5vw,58px);display:flex;flex-direction:column}.wizard-content h2{font-size:27px;margin:0 0 9px;letter-spacing:-.03em}.wizard-content>p{font-size:14px;color:var(--vscode-descriptionForeground);max-width:640px}.wizard-body{margin-top:24px;flex:1}.wizard-actions{display:flex;align-items:center;gap:9px;margin-top:26px}.wizard-actions .skip{margin-right:auto}
  .toast{position:fixed;right:20px;bottom:20px;padding:10px 14px;border-radius:9px;background:var(--vscode-notifications-background);border:1px solid var(--aw-border);box-shadow:0 8px 28px #0005;display:none;z-index:20}.loading{display:grid;place-items:center;min-height:55vh}.spinner{width:28px;height:28px;border:3px solid var(--aw-border);border-top-color:var(--aw-accent);border-radius:50%;animation:spin .8s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
  @media(max-width:900px){.shell{grid-template-columns:1fr}.nav{border-right:0;border-bottom:1px solid var(--aw-border);padding:10px 16px}.nav-list{position:static;display:flex;overflow:auto}.nav button{white-space:nowrap}.nav-note{display:none}.span-8,.span-6,.span-4,.span-3{grid-column:span 12}.agent-grid{grid-template-columns:1fr}.wizard-shell{grid-template-columns:1fr}.steps{padding:18px}.step-list{grid-template-columns:repeat(5,1fr);margin-top:15px}.step{justify-content:center;padding:5px}.step span:last-child{display:none}.topbar{padding:0 16px}.brand p{display:none}}
  @media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
</style></head><body><div class="app">
  <header class="topbar"><div class="brand"><div class="logo">AW</div><div><h1>${copy.title}</h1><p>${copy.subtitle}</p></div></div><div class="top-actions"><span class="pill"><span class="dot" id="health-dot"></span><span id="health-label">${copy.refreshing}</span></span><button class="button ghost icon-button" data-action="refresh" title="${copy.refresh}">↻</button></div></header>
  <div class="shell"><aside class="nav"><div class="nav-list" id="nav"></div><div class="nav-note"><strong>/config/Workspace</strong><br><span id="nav-revision"></span></div></aside><main id="content"><div class="loading"><div><div class="spinner"></div><p>${copy.refreshing}…</p></div></div></main></div>
</div><div class="toast" id="toast"></div>
<script nonce="${scriptNonce}">
const vscode=acquireVsCodeApi();const copy=${JSON.stringify(copy)};let data=null;let page='overview';let wizardStep=0;let forceWelcome=${forceWelcome ? 'true' : 'false'};let serviceFilter='';
const esc=(value)=>String(value??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const post=(type,extra={})=>vscode.postMessage({type,...extra});
const stateLabel=(value)=>({ready:copy.installed,missing:copy.missing,optional:copy.optional,running:copy.ready,active:copy.ready,stopped:copy.optional,inactive:copy.optional,failed:copy.failed,unknown:copy.unknown}[value]||value);
const dot=(state)=>'<span class="status-dot '+esc(state)+'"></span>';
const dockerText=(docker)=>docker.mode==='socket'?{label:copy.dockerSocketLabel,detail:copy.dockerSocketDetail}:docker.mode==='isolated'?{label:copy.dockerIsolatedLabel,detail:copy.dockerIsolatedDetail}:{label:copy.dockerDisabledLabel,detail:copy.dockerDisabledDetail};
function toast(message){const el=document.getElementById('toast');el.textContent=message;el.style.display='block';setTimeout(()=>el.style.display='none',2600)}
function nav(){const items=[['overview','⌂',copy.overview],['agents','✦',copy.agents],['services','◫',copy.services],['network','⌁',copy.network],['diagnostics','◇',copy.diagnostics]];document.getElementById('nav').innerHTML=items.map(([id,icon,label])=>'<button class="'+(page===id?'active':'')+'" data-nav="'+id+'"><span class="icon">'+icon+'</span><span>'+label+'</span></button>').join('');}
function health(){if(!data)return;const ok=data.summary.healthy&&data.bootstrap.foundation_ready;document.getElementById('health-label').textContent=ok?copy.ready:copy.attention;document.getElementById('health-dot').style.background=ok?'var(--aw-good)':'var(--aw-warn)';document.getElementById('nav-revision').textContent=(data.revision?copy.revision+' '+data.revision:'');}
function pageHead(title,body,actions=''){return '<div class="page-head"><div><h2>'+title+'</h2><p>'+body+'</p></div><div>'+actions+'</div></div>';}
function overview(){const agents=data.agents.filter(a=>a.installed);const services=data.services.filter(s=>s.status==='running');const docker=data.workspace.docker;const dockerCopy=dockerText(docker);const featured=data.services.filter(s=>s.kind==='systemd').slice(0,5);return pageHead(copy.overview,copy.subtitle)+
'<div class="grid"><section class="card hero span-12"><h2>'+esc(data.bootstrap.foundation_ready?copy.foundationReady:copy.foundationWorking)+'</h2><p>'+esc(data.workspace.root)+' · '+esc(data.access.hostname)+'</p><div class="hero-actions"><button class="button" data-action="terminal">⌁ '+copy.openTerminal+'</button><button class="button secondary" data-action="openWorkspace">▣ '+copy.openWorkspace+'</button><button class="button ghost" data-action="openDesktop">▰ '+copy.openDesktop+'</button></div></section>'+
'<section class="card span-4"><h3>'+copy.installedAgents+'</h3><div class="metric">'+agents.length+' <small>/ '+data.agents.length+'</small></div><div class="muted">'+(agents.map(a=>esc(a.label)).join(' · ')||copy.noAgents)+'</div></section>'+
'<section class="card span-4"><h3>'+copy.runningServices+'</h3><div class="metric">'+services.length+' <small>/ '+data.services.length+'</small></div><div class="muted">systemd user + s6</div></section>'+
'<section class="card span-4"><h3>'+copy.secureMode+'</h3><div class="metric" style="font-size:18px">'+esc(dockerCopy.label)+'</div><div class="muted">'+esc(dockerCopy.detail)+'</div></section>'+
'<section class="card span-6"><div class="section-title"><h3>'+copy.quickStart+'</h3></div><div class="list"><div class="list-row">'+dot(agents.length?'ready':'missing')+'<div class="list-main"><strong>'+copy.agents+'</strong><small>'+esc(agents.length?agents[0].version:copy.agentHelp)+'</small></div><button class="button ghost small" data-nav="agents">'+copy.viewAll+'</button></div><div class="list-row">'+dot('ready')+'<div class="list-main"><strong>'+copy.openWorkspace+'</strong><small>'+esc(data.workspace.root)+'</small></div><button class="button ghost small" data-action="openWorkspace">'+copy.open+'</button></div><div class="list-row">'+dot(data.network.installed?'ready':'optional')+'<div class="list-main"><strong>'+copy.proxyRoutes+'</strong><small>'+esc(data.network.installed?(data.network.root_domain||copy.installed):copy.optional)+'</small></div><button class="button ghost small" data-nav="network">'+copy.detail+'</button></div></div></section>'+
'<section class="card span-6"><div class="section-title"><h3>'+copy.recentServices+'</h3><button class="button ghost small" data-nav="services">'+copy.viewAll+'</button></div><div class="list">'+(featured.length?featured.map(serviceRow).join(''):'<div class="empty">'+copy.noServices+'</div>')+'</div></section></div>';}
function serviceRow(s){return '<div class="list-row">'+dot(s.status)+'<div class="list-main"><strong>'+esc(s.name)+'</strong><small>'+esc(s.kind+' · '+s.status+(s.pid?' · PID '+s.pid:''))+'</small></div></div>';}
function agentsPage(){return pageHead(copy.agents,copy.agentHelp)+ '<div class="agent-grid">'+data.agents.map(a=>{const color=a.accent==='amber'?'#dda65c':a.accent==='cyan'?'#45c9c2':'#8b7cf6';return '<section class="card agent-card" style="--agent:'+color+'"><div class="agent-top"><div class="agent-avatar">'+esc(a.label.slice(0,2).toUpperCase())+'</div><div><div class="agent-name">'+esc(a.label)+'</div><span class="badge '+(a.installed?'ready':'optional')+'">'+(a.installed?copy.installed:copy.optional)+'</span> '+(a.selected?'<span class="badge">'+copy.selected+'</span>':'')+'</div></div><p class="muted">'+esc(a.version||copy.versionUnknown)+'</p><div class="code">'+esc(a.launch)+'</div><div class="agent-actions">'+(a.installed?'<button class="button" data-action="launchAgent" data-command="'+esc(a.launch)+'">'+copy.launch+'</button>':'<button class="button" data-action="installAgent" data-id="'+esc(a.id)+'">'+copy.install+'</button>')+'<button class="button ghost" data-action="terminal">'+copy.openTerminal+'</button></div></section>';}).join('')+'</div>';}
function servicesPage(){const needle=serviceFilter.toLowerCase();const rows=data.services.filter(s=>(s.name+' '+s.id+' '+s.kind).toLowerCase().includes(needle));return pageHead(copy.services,copy.recentServices,'<input id="service-filter" class="filter" placeholder="'+copy.searchServices+'" value="'+esc(serviceFilter)+'">')+'<div class="table-wrap"><table><thead><tr><th>'+copy.service+'</th><th>'+copy.kind+'</th><th>'+copy.status+'</th><th>PID</th><th style="text-align:right">'+copy.actions+'</th></tr></thead><tbody>'+(rows.length?rows.map(s=>'<tr><td>'+dot(s.status)+' <strong>'+esc(s.name)+'</strong><div class="muted">'+esc(s.id)+'</div></td><td>'+esc(s.kind+(s.scope?' · '+s.scope:''))+'</td><td class="state-'+esc(s.status)+'">'+esc(stateLabel(s.status))+'</td><td>'+esc(s.pid||'—')+'</td><td><div class="row-actions">'+(s.status==='running'?'<button class="button ghost small" data-action="service" data-op="stop" data-kind="'+esc(s.kind)+'" data-id="'+esc(s.id)+'">'+copy.stop+'</button>':'<button class="button ghost small" data-action="service" data-op="start" data-kind="'+esc(s.kind)+'" data-id="'+esc(s.id)+'">'+copy.start+'</button>')+'<button class="button ghost small" data-action="service" data-op="restart" data-kind="'+esc(s.kind)+'" data-id="'+esc(s.id)+'">'+copy.restart+'</button>'+(s.kind==='systemd'?'<button class="button ghost small" data-action="logs" data-id="'+esc(s.id)+'">'+copy.logs+'</button>':'')+'</div></td></tr>').join(''):'<tr><td colspan="5" class="empty">'+copy.noServices+'</td></tr>')+'</tbody></table></div>';}
function networkPage(){const net=data.network;const dockerCopy=dockerText(data.workspace.docker);const routeActions=net.installed?'<button class="button" data-action="addRoute">＋ '+copy.addRoute+'</button> <button class="button ghost" data-action="checkProxy">'+copy.checkProxy+'</button>':'<button class="button" data-action="installProxy">'+copy.installProxy+'</button>';return pageHead(copy.network,copy.access,routeActions)+'<div class="grid"><section class="card span-6"><div class="section-title"><h3>'+copy.access+'</h3></div><div class="list"><div class="list-row">'+dot('ready')+'<div class="list-main"><strong>Webtop Desktop</strong><small>'+esc(data.access.desktop_local)+'</small></div><button class="button ghost small" data-action="openDesktop">'+copy.open+'</button></div><div class="list-row">'+dot('ready')+'<div class="list-main"><strong>code-server</strong><small>'+esc(data.access.code_server_local)+'</small></div></div></div><div class="code">ssh -N -L 3001:127.0.0.1:3001 -L 8443:127.0.0.1:8443 user@server</div><button class="button ghost small" style="margin-top:9px" data-action="copyTunnel">'+copy.copyTunnel+'</button></section>'+
'<section class="card span-6"><div class="risk '+esc(data.workspace.docker.risk)+'"><div class="risk-icon">D</div><div><h3>'+copy.secureMode+'</h3><strong>'+esc(dockerCopy.label)+'</strong><p class="muted">'+esc(dockerCopy.detail)+'</p><span class="badge '+(data.workspace.docker.risk==='high'?'warning':'ready')+'">'+esc(data.workspace.docker.risk==='high'?copy.dockerElevated:data.workspace.docker.risk==='medium'?copy.dockerMedium:copy.dockerSafe)+'</span></div></div></section>'+
'<section class="card span-12"><div class="section-title"><h3>'+copy.proxyRoutes+'</h3><span class="muted">'+esc(net.root_domain||copy.optional)+'</span></div><div class="list">'+(net.routes.length?net.routes.map(r=>'<div class="list-row">'+dot('ready')+'<div class="list-main"><strong>'+esc(r.host||r.name)+'</strong><small>'+esc(r.target)+'</small></div>'+(r.public_url?'<button class="button ghost small" data-action="openUrl" data-url="'+esc(r.public_url)+'">'+copy.open+'</button>':'')+'<button class="button danger small" data-action="removeRoute" data-name="'+esc(r.name)+'" data-host="'+esc(r.host)+'">'+copy.remove+'</button></div>').join(''):'<div class="empty">'+copy.noRoutes+'</div>')+'</div></section>'+
'<section class="card span-12"><div class="section-title"><h3>'+copy.listeningPorts+'</h3></div><div class="table-wrap"><table><thead><tr><th>'+copy.command+'</th><th>PID</th><th>'+copy.address+'</th></tr></thead><tbody>'+(data.ports.length?data.ports.slice(0,40).map(p=>'<tr><td>'+esc(p.command)+'</td><td>'+esc(p.pid||'—')+'</td><td><code>'+esc(p.address)+'</code></td></tr>').join(''):'<tr><td colspan="3" class="empty">'+copy.noPorts+'</td></tr>')+'</tbody></table></div></section></div>';}
function diagnosticsPage(){return pageHead(copy.diagnostics,copy.doctor,'<button class="button ghost" data-action="updateSource">'+copy.updateSource+'</button> <button class="button ghost" data-action="showOutput">'+copy.showOutput+'</button>')+'<div class="grid"><section class="card span-6"><div class="section-title"><h3>'+copy.capabilities+'</h3></div><div class="list">'+data.capabilities.map(c=>'<div class="list-row">'+dot(c.state)+'<div class="list-main"><strong>'+esc(c.label)+'</strong><small>'+esc(c.detail)+'</small></div><span class="badge '+(c.state==='ready'?'ready':'optional')+'">'+esc(stateLabel(c.state))+'</span></div>').join('')+'</div></section><section class="card span-6"><div class="section-title"><h3>'+copy.doctor+'</h3><span class="badge '+(data.doctor.healthy?'ready':'warning')+'">'+(data.doctor.healthy?copy.healthy:copy.attention)+'</span></div><div class="list">'+data.doctor.checks.map(c=>'<div class="list-row">'+dot(c.state)+'<div class="list-main"><strong>'+esc(c.id)+'</strong><small>'+esc(c.detail)+'</small></div></div>').join('')+'</div></section></div>';}
function wizard(){const labels=[copy.stepWelcome,copy.stepAgent,copy.stepWorkspace,copy.stepAccess,copy.stepOptional];const dockerCopy=dockerText(data.workspace.docker);let body='';if(wizardStep===0)body='<h2>'+copy.onboardingTitle+'</h2><p>'+copy.onboardingSubtitle+'</p><div class="wizard-body"><section class="card hero"><h2>'+esc(data.bootstrap.foundation_ready?copy.foundationReady:copy.foundationWorking)+'</h2><p>'+copy.welcomeBody+'</p></section></div>';if(wizardStep===1)body='<h2>'+copy.stepAgent+'</h2><p>'+copy.agentBody+'</p><div class="wizard-body"><div class="agent-grid">'+data.agents.map(a=>'<section class="card agent-card"><strong>'+esc(a.label)+'</strong><p class="muted">'+esc(a.version||copy.versionUnknown)+'</p>'+(a.installed?'<button class="button" data-action="launchAgent" data-command="'+esc(a.launch)+'">'+copy.launch+'</button>':'<button class="button" data-action="installAgent" data-id="'+esc(a.id)+'">'+copy.install+'</button>')+'</section>').join('')+'</div></div>';if(wizardStep===2)body='<h2>'+copy.stepWorkspace+'</h2><p>'+copy.workspaceBody+'</p><div class="wizard-body"><section class="card"><h3>'+copy.openWorkspace+'</h3><div class="code">'+esc(data.workspace.root)+'</div><div class="hero-actions"><button class="button" data-action="openWorkspace">'+copy.openWorkspace+'</button><button class="button ghost" data-action="terminal">'+copy.openTerminal+'</button></div></section></div>';if(wizardStep===3)body='<h2>'+copy.stepAccess+'</h2><p>'+copy.accessBody+'</p><div class="wizard-body grid"><section class="card span-6"><h3>Webtop</h3><div class="code">'+esc(data.access.desktop_local)+'</div><button class="button" style="margin-top:12px" data-action="openDesktop">'+copy.openDesktop+'</button></section><section class="card span-6"><div class="risk '+esc(data.workspace.docker.risk)+'"><div class="risk-icon">D</div><div><h3>'+copy.secureMode+'</h3><strong>'+esc(dockerCopy.label)+'</strong><p class="muted">'+esc(dockerCopy.detail)+'</p></div></div></section></div>';if(wizardStep===4)body='<h2>'+copy.stepOptional+'</h2><p>'+copy.optionalBody+'</p><div class="wizard-body"><section class="card"><div class="list"><div class="list-row">'+dot(data.network.installed?'ready':'optional')+'<div class="list-main"><strong>'+copy.proxyRoutes+'</strong><small>'+esc(data.network.installed?copy.installed:copy.optional)+'</small></div>'+(data.network.installed?'':'<button class="button ghost small" data-action="installProxy">'+copy.install+'</button>')+'</div><div class="list-row">'+dot('ready')+'<div class="list-main"><strong>'+copy.diagnostics+'</strong><small>workspacectl doctor</small></div><button class="button ghost small" data-nav="diagnostics">'+copy.detail+'</button></div></div></section></div>';const steps='<div class="steps"><h3>'+copy.quickStart+'</h3><div class="step-list">'+labels.map((label,i)=>'<div class="step '+(i===wizardStep?'active':i<wizardStep?'done':'')+'"><span class="step-index">'+(i<wizardStep?'✓':i+1)+'</span><span>'+label+'</span></div>').join('')+'</div></div>';const actions='<div class="wizard-actions"><button class="button ghost skip" data-action="completeOnboarding">'+copy.skip+'</button>'+(wizardStep?'<button class="button ghost" data-wizard="back">'+copy.back+'</button>':'')+'<button class="button" data-wizard="'+(wizardStep===4?'finish':'next')+'">'+(wizardStep===4?copy.finish:copy.next)+'</button></div>';return '<div class="wizard"><section class="card wizard-shell">'+steps+'<div class="wizard-content">'+body+actions+'</div></section></div>';}
function render(){nav();health();if(!data)return;const onboarding=!data.bootstrap.onboarding.complete||forceWelcome;if(onboarding&&page==='overview'){document.getElementById('content').innerHTML=wizard();return;}const pages={overview,agents:agentsPage,services:servicesPage,network:networkPage,diagnostics:diagnosticsPage};document.getElementById('content').innerHTML=pages[page]();const filter=document.getElementById('service-filter');if(filter){filter.focus();filter.setSelectionRange(filter.value.length,filter.value.length);filter.addEventListener('input',e=>{serviceFilter=e.target.value;render();});}}
document.addEventListener('click',event=>{const navButton=event.target.closest('[data-nav]');if(navButton){page=navButton.dataset.nav;forceWelcome=false;render();return;}const wizardButton=event.target.closest('[data-wizard]');if(wizardButton){if(wizardButton.dataset.wizard==='back')wizardStep=Math.max(0,wizardStep-1);else if(wizardButton.dataset.wizard==='finish')post('completeOnboarding');else wizardStep=Math.min(4,wizardStep+1);render();return;}const button=event.target.closest('[data-action]');if(!button)return;const action=button.dataset.action;if(action==='refresh')post('refresh');else if(action==='terminal')post('terminal');else if(action==='openWorkspace')post('openWorkspace');else if(action==='openDesktop')post('openDesktop');else if(action==='launchAgent')post('terminal',{command:button.dataset.command});else if(action==='installAgent')post('installAgent',{id:button.dataset.id});else if(action==='service')post('serviceAction',{id:button.dataset.id,kind:button.dataset.kind,action:button.dataset.op});else if(action==='logs')post('showLogs',{id:button.dataset.id});else if(action==='installProxy')post('installProxy');else if(action==='checkProxy')post('checkProxy');else if(action==='addRoute')post('addRoute');else if(action==='removeRoute')post('removeRoute',{name:button.dataset.name,host:button.dataset.host});else if(action==='openUrl')post('openUrl',{url:button.dataset.url});else if(action==='copyTunnel'){post('copyTunnel');toast(copy.copyTunnel);}else if(action==='completeOnboarding')post('completeOnboarding');else if(action==='showOutput')post('showOutput');else if(action==='updateSource')post('updateSource');});
window.addEventListener('message',event=>{const message=event.data;if(message.type==='snapshot'){data=message.data;if(typeof message.forceWelcome==='boolean')forceWelcome=message.forceWelcome;render();}else if(message.type==='showWelcome'){forceWelcome=message.value;wizardStep=0;page='overview';render();}else if(message.type==='refreshing'){document.getElementById('health-label').textContent=copy.refreshing;}else if(message.type==='error'){document.getElementById('content').innerHTML='<div class="empty"><h2>'+copy.attention+'</h2><p>'+esc(message.message)+'</p><button class="button" data-action="refresh">'+copy.refresh+'</button></div>';}});post('ready');
</script></body></html>`;
}

function activate(context) {
  const controller = new ControlCenter(context);
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider(VIEW_ID, { resolveWebviewView: (view) => controller.resolveWebviewView(view) }),
    vscode.commands.registerCommand('agentWorkspace.openControlCenter', () => controller.open(false)),
    vscode.commands.registerCommand('agentWorkspace.refresh', () => controller.refresh(true)),
    vscode.commands.registerCommand('agentWorkspace.showWelcome', () => controller.open(true))
  );

  controller.refresh().then((snapshot) => {
    if (!snapshot) return;
    const autoOpen = controller.config().autoOpen;
    const incomplete = snapshot.bootstrap && snapshot.bootstrap.onboarding && !snapshot.bootstrap.onboarding.complete;
    if (autoOpen && incomplete) {
      setTimeout(() => controller.open(true), 900);
    }
  });
}

function deactivate() {}

module.exports = { activate, deactivate };
