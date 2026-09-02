const vscode = require('vscode');
const fs = require('fs/promises');
const path = require('path');
const { execFile } = require('child_process');

const OUTPUT = vscode.window.createOutputChannel('Caddy Proxy Manager');

function cfg() {
  const c = vscode.workspace.getConfiguration('caddyProxyManager');
  return {
    workspacectlPath: c.get('workspacectlPath', '/config/bin/workspacectl'),
    stateDir: c.get('stateDir', '/config/proxyctl'),
    publicScheme: c.get('publicScheme', 'https'),
    publicPort: c.get('publicPort', '7555'),
    logTailLines: c.get('logTailLines', 200)
  };
}

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, {
      timeout: options.timeout ?? 15000,
      maxBuffer: options.maxBuffer ?? 1024 * 1024,
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

async function readText(file) {
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    return '';
  }
}

async function tailFile(file, lines) {
  const text = await readText(file);
  if (!text) return '';
  return text.split(/\r?\n/).slice(-lines).join('\n');
}

function parseEnv(text) {
  const env = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;
    env[match[1]] = match[2].trim().replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
  }
  return env;
}

function routeLabelFromHost(host, env) {
  const root = env.PROXY_ROOT_DOMAIN || '';
  let label = host;
  if (root && host.endsWith(`.${root}`)) {
    label = host.slice(0, -(root.length + 1));
  }
  const prefix = env.PROXY_HOST_PREFIX;
  if (prefix && label.startsWith(`${prefix}-`)) {
    label = label.slice(prefix.length + 1);
  }
  return label;
}

function publicUrl(host) {
  const c = cfg();
  const port = String(c.publicPort || '').trim();
  return `${c.publicScheme}://${host}${port ? `:${port}` : ''}`;
}

class InfoItem extends vscode.TreeItem {
  constructor(label, description, icon = 'info') {
    super(label, vscode.TreeItemCollapsibleState.None);
    this.description = description;
    this.iconPath = new vscode.ThemeIcon(icon);
    this.contextValue = 'caddyInfo';
  }
}

class RouteItem extends vscode.TreeItem {
  constructor(route, env) {
    super(routeLabelFromHost(route.host, env), vscode.TreeItemCollapsibleState.None);
    this.route = route;
    this.description = `${route.host} -> ${route.target}`;
    this.tooltip = `${publicUrl(route.host)}\n${route.target}`;
    this.iconPath = new vscode.ThemeIcon('link');
    this.contextValue = 'caddyRoute';
    this.command = {
      command: 'caddyProxyManager.openUrl',
      title: 'Open Route',
      arguments: [this]
    };
  }
}

class GroupItem extends vscode.TreeItem {
  constructor(label, children, icon = 'folder') {
    super(label, vscode.TreeItemCollapsibleState.Expanded);
    this.children = children;
    this.description = String(children.length);
    this.iconPath = new vscode.ThemeIcon(icon);
    this.contextValue = 'caddyGroup';
  }
}

class ProxyProvider {
  constructor() {
    this._onDidChangeTreeData = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._onDidChangeTreeData.event;
  }

  refresh() {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element) {
    return element;
  }

  async getChildren(element) {
    if (element instanceof GroupItem) return element.children;

    const state = await loadState();
    const info = [
      new InfoItem('Root domain', state.env.PROXY_ROOT_DOMAIN || '(unset)', 'globe'),
      new InfoItem('Host prefix', state.env.PROXY_HOST_PREFIX || '(none)', 'symbol-string'),
      new InfoItem('Listen', state.env.PROXY_LISTEN || '(unset)', 'radio-tower'),
      new InfoItem('Code server', `${codeHost(state.env)} -> ${state.env.CODE_SERVER_TARGET || '(unset)'}`, 'server')
    ];
    const routes = state.routes.map((route) => new RouteItem(route, state.env));
    return [
      new GroupItem('Environment', info, 'settings-gear'),
      new GroupItem('Named Routes', routes, 'list-tree')
    ];
  }
}

function codeHost(env) {
  const label = env.CODE_SERVER_SUBDOMAIN || 'code';
  const prefix = env.PROXY_HOST_PREFIX ? `${env.PROXY_HOST_PREFIX}-` : '';
  return `${prefix}${label}.${env.PROXY_ROOT_DOMAIN || ''}`;
}

async function loadState() {
  const c = cfg();
  const env = parseEnv(await readText(path.join(c.stateDir, 'env')));
  let routes = [];
  try {
    routes = JSON.parse(await readText(path.join(c.stateDir, 'routes.json')) || '[]');
  } catch (error) {
    OUTPUT.appendLine(`Failed to parse routes.json: ${error.message}`);
  }
  return { env, routes };
}

async function routingCommand(args, timeout = 20000) {
  const c = cfg();
  OUTPUT.appendLine(`$ ${c.workspacectlPath} proxy ${args.join(' ')}`);
  const result = await run(c.workspacectlPath, ['proxy', ...args], { timeout, maxBuffer: 4 * 1024 * 1024 });
  if (result.stdout.trim()) OUTPUT.appendLine(result.stdout.trim());
  if (result.stderr.trim()) OUTPUT.appendLine(result.stderr.trim());
  return result;
}

async function addRoute(provider) {
  const name = await vscode.window.showInputBox({
    title: 'Route name',
    prompt: 'Subdomain label. The configured prefix/root domain will be applied by workspacectl.',
    placeHolder: 'app'
  });
  if (!name) return;

  const target = await vscode.window.showInputBox({
    title: 'Route target',
    prompt: 'Upstream host:port reachable from this container.',
    placeHolder: '127.0.0.1:3000',
    validateInput(value) {
      return /^[^:\s]+:\d{1,5}$/.test(value) ? undefined : 'Use host:port, for example 127.0.0.1:3000';
    }
  });
  if (!target) return;

  const result = await routingCommand(['add', name.trim(), target.trim()]);
  if (result.ok) {
    vscode.window.showInformationMessage(`Added route ${name} -> ${target}`);
    provider.refresh();
  } else {
    vscode.window.showErrorMessage(`Failed to add route ${name}`);
  }
}

async function removeRoute(item, provider) {
  if (!item || !item.route) return;
  const state = await loadState();
  const label = routeLabelFromHost(item.route.host, state.env);
  const choice = await vscode.window.showWarningMessage(
    `Remove route ${item.route.host}?`,
    { modal: true },
    'Remove'
  );
  if (choice !== 'Remove') return;

  const result = await routingCommand(['remove', label]);
  if (result.ok) {
    vscode.window.showInformationMessage(`Removed route ${item.route.host}`);
    provider.refresh();
  } else {
    vscode.window.showErrorMessage(`Failed to remove route ${item.route.host}`);
  }
}

async function check() {
  OUTPUT.show(true);
  const result = await routingCommand(['check']);
  if (result.ok) vscode.window.showInformationMessage('Custom-domain routing check: ok');
  else vscode.window.showErrorMessage('Custom-domain routing check failed');
}

async function showConfig() {
  OUTPUT.show(true);
  OUTPUT.appendLine('\n== Generated Caddy Config ==');
  await routingCommand(['render'], 20000);
}

async function showAccessLog() {
  const c = cfg();
  const env = parseEnv(await readText(path.join(c.stateDir, 'env')));
  const file = env.PROXY_ACCESS_LOG || path.join(c.stateDir, 'access.log');
  OUTPUT.show(true);
  OUTPUT.appendLine(`\n== Access Log: ${file} ==`);
  OUTPUT.appendLine(await tailFile(file, c.logTailLines) || '(no access log found)');
}

async function showCaddyLog() {
  const c = cfg();
  const candidates = [
    '/config/.local/log/user-systemd/proxy-caddy.log',
    '/config/logs/proxy-caddy.log',
    path.join(c.stateDir, 'caddy.log')
  ];
  OUTPUT.show(true);
  OUTPUT.appendLine('\n== Caddy Service Log ==');
  let found = false;
  for (const file of candidates) {
    const text = await tailFile(file, c.logTailLines);
    if (!text) continue;
    found = true;
    OUTPUT.appendLine(`--- ${file} ---`);
    OUTPUT.appendLine(text);
  }
  if (!found) OUTPUT.appendLine('(no Caddy service log found)');
}

async function rollback(provider) {
  const choice = await vscode.window.showWarningMessage(
    'Roll back the last custom-domain route change?',
    { modal: true },
    'Rollback'
  );
  if (choice !== 'Rollback') return;
  const result = await routingCommand(['rollback'], 30000);
  if (result.ok) {
    vscode.window.showInformationMessage('Rolled back proxy routes');
    provider.refresh();
  } else {
    vscode.window.showErrorMessage('Rollback failed');
  }
}

async function openUrl(item) {
  if (!item || !item.route) return;
  await vscode.env.openExternal(vscode.Uri.parse(publicUrl(item.route.host)));
}

function activate(context) {
  const provider = new ProxyProvider();
  vscode.window.registerTreeDataProvider('caddyProxyManager.routes', provider);

  context.subscriptions.push(
    OUTPUT,
    vscode.commands.registerCommand('caddyProxyManager.refresh', () => provider.refresh()),
    vscode.commands.registerCommand('caddyProxyManager.addRoute', () => addRoute(provider)),
    vscode.commands.registerCommand('caddyProxyManager.removeRoute', (item) => removeRoute(item, provider)),
    vscode.commands.registerCommand('caddyProxyManager.check', check),
    vscode.commands.registerCommand('caddyProxyManager.showConfig', showConfig),
    vscode.commands.registerCommand('caddyProxyManager.showAccessLog', showAccessLog),
    vscode.commands.registerCommand('caddyProxyManager.showCaddyLog', showCaddyLog),
    vscode.commands.registerCommand('caddyProxyManager.rollback', () => rollback(provider)),
    vscode.commands.registerCommand('caddyProxyManager.openUrl', openUrl)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
