const http = require('http');
const vscode = require('vscode');

const INTEGRATED_BROWSER_COMMAND = 'workbench.action.browser.open';
const PANEL_VIEW_TYPE = 'selkiesDesktop.panel';
const FIRST_OPEN_KEY = 'selkiesDesktop.firstOpenCompleted.v2';

let bootstrapServer;
let activePanel;
let extensionContext;
let activeTarget;

function configuration() {
  const value = vscode.workspace.getConfiguration('selkiesDesktop');
  return {
    url: value.get('url', 'auto'),
    openOnStartup: value.get('openOnStartup', 'never'),
    browserMode: value.get('browserMode', 'panel'),
    openLocation: value.get('openLocation', 'active'),
    pageZoom: value.get('pageZoom', '80%'),
    dataStorage: value.get('dataStorage', 'workspace'),
    uiDpi: value.get('uiDpi', 96),
    hidpi: value.get('hidpi', true),
    showStatusBarButton: value.get('showStatusBarButton', true)
  };
}

async function resolveTarget(rawUrl) {
  if (rawUrl === 'auto') {
    return { href: '/proxy/3000/', origin: '', sameOrigin: true };
  }
  const external = normalizeTarget(rawUrl);
  return { href: external.toString(), origin: external.origin, sameOrigin: false };
}

function normalizeTarget(rawUrl) {
  let target;
  try {
    target = new URL(rawUrl);
  } catch {
    throw new Error(`Invalid selkiesDesktop.url: ${rawUrl}`);
  }
  if (!['http:', 'https:'].includes(target.protocol)) {
    throw new Error('selkiesDesktop.url must use http or https');
  }
  target.hash = '';
  if (!target.pathname.endsWith('/')) target.pathname += '/';
  return target;
}

async function updateWorkbenchDefault(key, value) {
  const config = vscode.workspace.getConfiguration();
  const inspected = config.inspect(key);
  if (inspected && inspected.globalValue !== undefined) return;
  try {
    await config.update(key, value, vscode.ConfigurationTarget.Global);
  } catch {
    // Integrated Browser settings differ across VS Code/code-server releases.
    // Client bootstrapping still works when an older build lacks one of them.
  }
}

async function applyBrowserDefaults() {
  const c = configuration();
  await Promise.all([
    updateWorkbenchDefault('workbench.browser.dataStorage', c.dataStorage),
    updateWorkbenchDefault('workbench.browser.pageZoom', c.pageZoom),
    updateWorkbenchDefault('workbench.browser.newTabPlacement', 'sideGroup')
  ]);
}

function bootstrapHtml(target, c) {
  const settings = {
    use_css_scaling: String(!c.hidpi),
    useCssScaling: String(!c.hidpi),
    scaling_dpi: String(c.uiDpi)
  };
  const targetJson = JSON.stringify(target.href);
  const settingsJson = JSON.stringify(settings);
  return `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="background:#1e1e1e;color:#ddd;font:14px sans-serif;padding:24px">
Preparing Selkies Desktop…
<script>
(() => {
  const target = new URL(${targetJson}, location.origin).toString();
  // Match Selkies' own URL-derived localStorage prefix exactly. Its character
  // class intentionally preserves URL separators such as ':' and '/'.
  const prefix = target.split('#')[0].replace(/[^a-zA-Z0-9.-_]/g, '_');
  const settings = ${settingsJson};
  for (const [key, value] of Object.entries(settings)) {
    localStorage.setItem(prefix + '_' + key, value);
  }
  location.replace(target);
})();
</script>
</body>
</html>`;
}

function startBootstrapServer() {
  if (bootstrapServer) return bootstrapServer;
  bootstrapServer = new Promise((resolve, reject) => {
    const server = http.createServer((request, response) => {
      if (request.url === '/favicon.ico') {
        response.writeHead(204);
        response.end();
        return;
      }
      const c = configuration();
      const target = activeTarget;
      if (!target) {
        response.writeHead(503, { 'Content-Type': 'text/plain; charset=utf-8' });
        response.end('Selkies target is not ready');
        return;
      }
      const body = bootstrapHtml(target, c);
      response.writeHead(200, {
        'Content-Type': 'text/html; charset=utf-8',
        'Content-Length': Buffer.byteLength(body),
        'Cache-Control': 'no-store',
        'Content-Security-Policy': "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'"
      });
      response.end(body);
    });
    server.once('error', (error) => {
      bootstrapServer = undefined;
      reject(error);
    });
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({ server, port: address.port });
    });
  });
  return bootstrapServer;
}

async function browserCommand() {
  const commands = await vscode.commands.getCommands(true);
  return commands.includes(INTEGRATED_BROWSER_COMMAND)
    ? INTEGRATED_BROWSER_COMMAND
    : undefined;
}

function nonce() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let value = '';
  for (let index = 0; index < 32; index += 1) {
    value += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
  }
  return value;
}

function zoomFactor(rawValue) {
  const parsed = Number.parseInt(String(rawValue).replace('%', ''), 10);
  return Number.isFinite(parsed) ? Math.max(50, Math.min(125, parsed)) / 100 : 0.8;
}

function panelHtml(webview, target, bootstrapUrl, c) {
  const scriptNonce = nonce();
  const initialZoom = zoomFactor(c.pageZoom);
  const targetJson = JSON.stringify(target.href);
  const bootstrapJson = JSON.stringify(bootstrapUrl);
  const frameSources = target.sameOrigin ? "'self'" : `'self' ${target.origin}`;
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; frame-src ${frameSources}; style-src 'unsafe-inline'; script-src 'nonce-${scriptNonce}';">
  <style>
    html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; background: var(--vscode-editor-background); color: var(--vscode-foreground); }
    body { display: flex; flex-direction: column; }
    .toolbar { height: 34px; flex: 0 0 34px; display: flex; align-items: center; gap: 4px; padding: 0 6px; box-sizing: border-box; border-bottom: 1px solid var(--vscode-panel-border); background: var(--vscode-editorGroupHeader-tabsBackground); }
    button { min-width: 28px; height: 24px; padding: 0 7px; border: 1px solid transparent; border-radius: 3px; color: var(--vscode-foreground); background: transparent; font: inherit; cursor: pointer; }
    button:hover { background: var(--vscode-toolbar-hoverBackground); }
    button:focus-visible { outline: 1px solid var(--vscode-focusBorder); outline-offset: 1px; }
    #zoom { min-width: 48px; font-variant-numeric: tabular-nums; }
    .spacer { flex: 1; }
    .status { opacity: .72; font-size: 12px; white-space: nowrap; }
    .viewport { position: relative; flex: 1; min-height: 0; overflow: hidden; background: #111; }
    iframe { position: absolute; inset: 0 auto auto 0; border: 0; transform-origin: 0 0; background: #111; }
  </style>
</head>
<body>
  <div class="toolbar" role="toolbar" aria-label="Selkies Desktop controls">
    <button id="reload" title="Reload and reapply HiDPI/DPI defaults">↻</button>
    <button id="minus" title="Zoom out">−</button>
    <button id="zoom" title="Reset to 100%">100%</button>
    <button id="plus" title="Zoom in">+</button>
    <span class="spacer"></span>
    <span class="status">HiDPI ${c.hidpi ? 'on' : 'off'} · ${c.uiDpi} DPI</span>
    <button id="external" title="Open in an external browser">↗</button>
  </div>
  <div class="viewport"><iframe id="desktop" title="Selkies Desktop" allow="autoplay; clipboard-read; clipboard-write; fullscreen; microphone"></iframe></div>
  <script nonce="${scriptNonce}">
    const vscode = acquireVsCodeApi();
    const targetUrl = ${targetJson};
    const bootstrapUrl = ${bootstrapJson};
    const frame = document.getElementById('desktop');
    const label = document.getElementById('zoom');
    const saved = vscode.getState() || {};
    let zoom = typeof saved.zoom === 'number' ? saved.zoom : ${initialZoom};

    function clamp(value) { return Math.max(0.5, Math.min(1.25, Math.round(value * 100) / 100)); }
    function applyZoom(value) {
      zoom = clamp(value);
      frame.style.transform = 'scale(' + zoom + ')';
      frame.style.width = (100 / zoom) + '%';
      frame.style.height = (100 / zoom) + '%';
      label.textContent = Math.round(zoom * 100) + '%';
      vscode.setState({ zoom });
    }
    function reload() {
      const separator = bootstrapUrl.includes('?') ? '&' : '?';
      frame.src = bootstrapUrl + separator + 'reload=' + Date.now();
    }

    document.getElementById('reload').addEventListener('click', reload);
    document.getElementById('minus').addEventListener('click', () => applyZoom(zoom - 0.1));
    document.getElementById('plus').addEventListener('click', () => applyZoom(zoom + 0.1));
    label.addEventListener('click', () => applyZoom(1));
    document.getElementById('external').addEventListener('click', () => {
      if (targetUrl.startsWith('/')) window.open(targetUrl, '_blank', 'noopener');
      else vscode.postMessage({ type: 'openExternal', url: targetUrl });
    });
    applyZoom(zoom);
    reload();
  </script>
</body>
</html>`;
}

function panelColumn(c) {
  return c.openLocation === 'beside' ? vscode.ViewColumn.Beside : vscode.ViewColumn.Active;
}

async function renderPanel(panel) {
  const c = configuration();
  const target = await resolveTarget(c.url);
  activeTarget = target;
  let bootstrapUrl = target.href;
  if (target.sameOrigin) {
    const { port } = await startBootstrapServer();
    bootstrapUrl = `/proxy/${port}/`;
  }
  panel.title = 'Selkies Desktop';
  panel.webview.options = { enableScripts: true };
  panel.webview.html = panelHtml(panel.webview, target, bootstrapUrl, c);
}

async function openPanel() {
  const c = configuration();
  if (activePanel) {
    activePanel.reveal(panelColumn(c), false);
    await renderPanel(activePanel);
    return;
  }

  const panel = vscode.window.createWebviewPanel(
    PANEL_VIEW_TYPE,
    'Selkies Desktop',
    panelColumn(c),
    { enableScripts: true, retainContextWhenHidden: true }
  );
  activePanel = panel;
  extensionContext.subscriptions.push(
    panel.onDidDispose(() => {
      if (activePanel === panel) activePanel = undefined;
    }),
    panel.webview.onDidReceiveMessage(async (message) => {
      if (message && message.type === 'openExternal') {
        await vscode.env.openExternal(vscode.Uri.parse(message.url));
      }
    })
  );
  await renderPanel(panel);
}

async function restorePanel(panel) {
  activePanel = panel;
  panel.webview.options = { enableScripts: true };
  extensionContext.subscriptions.push(
    panel.onDidDispose(() => {
      if (activePanel === panel) activePanel = undefined;
    }),
    panel.webview.onDidReceiveMessage(async (message) => {
      if (message && message.type === 'openExternal') {
        await vscode.env.openExternal(vscode.Uri.parse(message.url));
      }
    })
  );
  await renderPanel(panel);
}

async function openSelkies() {
  const c = configuration();
  if (c.browserMode !== 'panel') {
    const command = await browserCommand();
    if (command) {
      const target = await resolveTarget(c.url);
      activeTarget = target;
      let bootstrapUrl = target.href;
      if (target.sameOrigin) {
        const { port } = await startBootstrapServer();
        bootstrapUrl = `/proxy/${port}/`;
      }
      await applyBrowserDefaults();
      await vscode.commands.executeCommand(command, bootstrapUrl);
      return;
    }
    if (c.browserMode === 'integrated') {
      vscode.window.showWarningMessage('Integrated Browser is unavailable in this code-server Web Host. Opening the Selkies panel instead.');
    }
  }

  await openPanel();
}

async function activate(context) {
  extensionContext = context;
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 50);
  status.name = 'Selkies Desktop';
  status.text = '$(device-desktop) Selkies';
  status.tooltip = 'Open Selkies Desktop';
  status.command = 'selkiesDesktop.open';

  const syncStatusVisibility = () => {
    if (configuration().showStatusBarButton) status.show();
    else status.hide();
  };

  context.subscriptions.push(
    status,
    vscode.commands.registerCommand('selkiesDesktop.open', () => openSelkies()),
    vscode.commands.registerCommand('selkiesDesktop.resetClientDefaults', () => openSelkies()),
    vscode.window.registerWebviewPanelSerializer(PANEL_VIEW_TYPE, {
      deserializeWebviewPanel: (panel) => restorePanel(panel)
    }),
    vscode.workspace.onDidChangeConfiguration((event) => {
      if (event.affectsConfiguration('selkiesDesktop.showStatusBarButton')) syncStatusVisibility();
    }),
    {
      dispose() {
        if (!bootstrapServer) return;
        bootstrapServer.then(({ server }) => server.close()).catch(() => {});
      }
    }
  );

  syncStatusVisibility();

  const mode = configuration().openOnStartup;
  const firstOpenCompleted = context.globalState.get(FIRST_OPEN_KEY, false);
  if (mode === 'always' || (mode === 'firstInstall' && !firstOpenCompleted)) {
    try {
      await openSelkies();
      await context.globalState.update(FIRST_OPEN_KEY, true);
    } catch (error) {
      vscode.window.showErrorMessage(`Selkies Desktop could not open: ${error.message}`);
    }
  }
}

function deactivate() {}

module.exports = { activate, deactivate };
