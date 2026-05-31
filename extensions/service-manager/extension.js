const vscode = require('vscode');
const fs = require('fs/promises');
const path = require('path');
const { execFile } = require('child_process');

const OUTPUT = vscode.window.createOutputChannel('Unified Service Manager');

function run(command, args, options = {}) {
  return new Promise((resolve) => {
    execFile(command, args, {
      timeout: options.timeout ?? 10000,
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

function config() {
  const cfg = vscode.workspace.getConfiguration('unifiedServiceManager');
  return {
    s6ServiceDirs: cfg.get('s6ServiceDirs', ['/run/service']),
    systemdScopes: cfg.get('systemdScopes', ['user', 'system']),
    includeSystemdStates: new Set(cfg.get('includeSystemdStates', ['enabled', 'disabled']))
  };
}

function statusIcon(status) {
  if (status === 'running') return new vscode.ThemeIcon('circle-filled', new vscode.ThemeColor('testing.iconPassed'));
  if (status === 'stopped') return new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('testing.iconUnset'));
  if (status === 'failed') return new vscode.ThemeIcon('error', new vscode.ThemeColor('testing.iconFailed'));
  return new vscode.ThemeIcon('question', new vscode.ThemeColor('testing.iconQueued'));
}

function parseKeyValues(text) {
  const values = {};
  for (const line of text.split(/\r?\n/)) {
    const index = line.indexOf('=');
    if (index === -1) continue;
    values[line.slice(0, index)] = line.slice(index + 1);
  }
  return values;
}

function parseS6Pid(rawStatus) {
  const match = rawStatus.match(/\bpid\s+(\d+)/);
  return match ? Number(match[1]) : undefined;
}

function parseS6Pgid(rawStatus) {
  const match = rawStatus.match(/\bpgid\s+(\d+)/);
  return match ? Number(match[1]) : undefined;
}

function formatSection(title, body) {
  const trimmed = String(body || '').trim();
  return `\n## ${title}\n${trimmed || '(none)'}`;
}

async function readText(file) {
  try {
    return await fs.readFile(file, 'utf8');
  } catch {
    return '';
  }
}

async function tailFile(file, lines = 120) {
  const content = await readText(file);
  if (!content) return '';
  return content.split(/\r?\n/).slice(-lines).join('\n');
}

async function fileExists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

function decodeProcAddress(hexAddress, isV6) {
  const [hostHex, portHex] = hexAddress.split(':');
  const port = parseInt(portHex, 16);
  if (!isV6) {
    const bytes = hostHex.match(/../g).reverse().map((part) => parseInt(part, 16));
    return `${bytes.join('.')}:${port}`;
  }
  const groups = [];
  for (let i = 0; i < hostHex.length; i += 8) {
    const word = hostHex.slice(i, i + 8);
    groups.push(word.match(/../g).reverse().join(''));
  }
  return `${groups.join(':')}:${port}`;
}

async function listeningSockets() {
  const sockets = new Map();
  for (const [file, isV6] of [['/proc/net/tcp', false], ['/proc/net/tcp6', true]]) {
    const content = await readText(file);
    for (const line of content.split(/\r?\n/).slice(1)) {
      const cols = line.trim().split(/\s+/);
      if (cols.length < 10 || cols[3] !== '0A') continue;
      sockets.set(cols[9], decodeProcAddress(cols[1], isV6));
    }
  }
  return sockets;
}

async function portsForPids(pids) {
  const sockets = await listeningSockets();
  const ports = new Map();
  for (const pid of pids.filter(Boolean)) {
    let fds = [];
    try {
      fds = await fs.readdir(`/proc/${pid}/fd`);
    } catch {
      continue;
    }
    for (const fd of fds) {
      let link = '';
      try {
        link = await fs.readlink(`/proc/${pid}/fd/${fd}`);
      } catch {
        continue;
      }
      const match = link.match(/^socket:\[(\d+)\]$/);
      if (!match || !sockets.has(match[1])) continue;
      if (!ports.has(pid)) ports.set(pid, new Set());
      ports.get(pid).add(sockets.get(match[1]));
    }
  }
  return [...ports.entries()]
    .map(([pid, values]) => `${pid}: ${[...values].sort().join(', ')}`)
    .join('\n');
}

async function processGroup(pgid) {
  if (!pgid) return '';
  const result = await run('ps', ['-o', 'pid,ppid,pgid,stat,comm,args', '-g', String(pgid)], { timeout: 3000 });
  return (result.stdout || result.stderr).trim();
}

async function childPidsForMain(pid) {
  if (!pid) return [];
  const result = await run('ps', ['-eo', 'pid=,ppid='], { timeout: 3000 });
  const children = new Map();
  for (const line of result.stdout.split(/\r?\n/)) {
    const [child, parent] = line.trim().split(/\s+/).map(Number);
    if (!child || !parent) continue;
    if (!children.has(parent)) children.set(parent, []);
    children.get(parent).push(child);
  }
  const found = [];
  const queue = [pid];
  while (queue.length) {
    const current = queue.shift();
    found.push(current);
    queue.push(...(children.get(current) || []));
  }
  return found;
}

async function processTreeForPid(pid) {
  if (!pid) return '';
  const pids = await childPidsForMain(pid);
  if (pids.length === 0) return '';
  const result = await run('ps', ['-o', 'pid,ppid,pgid,stat,comm,args', '-p', pids.join(',')], { timeout: 3000 });
  return (result.stdout || result.stderr).trim();
}

class ServiceItem extends vscode.TreeItem {
  constructor(service) {
    super(service.name, vscode.TreeItemCollapsibleState.None);
    this.service = service;
    this.description = `${service.kind} ${service.scope || ''}`.trim();
    this.tooltip = `${service.kind}:${service.id}\n${service.rawStatus || service.status}`;
    this.contextValue = `${service.kind}-service`;
    this.iconPath = statusIcon(service.status);
    this.command = {
      command: 'unifiedServiceManager.showDetails',
      title: 'Show Details',
      arguments: [this]
    };
  }
}

class GroupItem extends vscode.TreeItem {
  constructor(label, children) {
    super(label, vscode.TreeItemCollapsibleState.Expanded);
    this.children = children;
    this.contextValue = 'group';
    this.description = `${children.length}`;
    this.iconPath = new vscode.ThemeIcon('folder');
  }
}

class ServiceProvider {
  constructor() {
    this._onDidChangeTreeData = new vscode.EventEmitter();
    this.onDidChangeTreeData = this._onDidChangeTreeData.event;
    this.groups = [];
  }

  refresh() {
    this._onDidChangeTreeData.fire();
  }

  async getChildren(element) {
    if (element instanceof GroupItem) return element.children;
    const services = await discoverServices();
    const s6 = services.filter((s) => s.kind === 's6').map((s) => new ServiceItem(s));
    const systemdUser = services.filter((s) => s.kind === 'systemd' && s.scope === 'user').map((s) => new ServiceItem(s));
    const systemdSystem = services.filter((s) => s.kind === 'systemd' && s.scope === 'system').map((s) => new ServiceItem(s));
    return [
      new GroupItem('s6', s6),
      new GroupItem('systemd user', systemdUser),
      new GroupItem('systemd system', systemdSystem)
    ].filter((g) => g.children.length > 0);
  }

  getTreeItem(element) {
    return element;
  }
}

async function discoverServices() {
  const cfg = config();
  const [s6, systemdGroups] = await Promise.all([
    discoverS6(cfg.s6ServiceDirs),
    Promise.all(cfg.systemdScopes.map((scope) => discoverSystemd(scope, cfg.includeSystemdStates)))
  ]);
  return [...s6, ...systemdGroups.flat()].sort((a, b) => `${a.kind}:${a.scope}:${a.name}`.localeCompare(`${b.kind}:${b.scope}:${b.name}`));
}

async function discoverS6(serviceDirs) {
  const services = [];
  for (const root of serviceDirs) {
    let entries = [];
    try {
      entries = await fs.readdir(root, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const entry of entries) {
      if (entry.name.startsWith('.')) continue;
      const servicePath = path.join(root, entry.name);
      const stat = await run('s6-svstat', [servicePath], { timeout: 3000 });
      const raw = (stat.stdout || stat.stderr).trim();
      const running = raw.startsWith('up ');
      services.push({
        kind: 's6',
        id: servicePath,
        name: entry.name,
        status: running ? 'running' : 'stopped',
        rawStatus: raw,
        path: servicePath
      });
    }
  }
  return services;
}

async function discoverSystemd(scope, includeStates) {
  const baseArgs = scope === 'user' ? ['--user'] : [];
  const listed = await run('systemctl', [...baseArgs, 'list-unit-files', '--type=service', '--no-legend'], { timeout: 8000 });
  if (!listed.ok && !listed.stdout) {
    OUTPUT.appendLine(`[systemd:${scope}] list failed: ${listed.stderr.trim()}`);
    return [];
  }

  const units = listed.stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const [unit, state = 'unknown'] = line.split(/\s+/);
      return { unit, state };
    })
    .filter(({ unit, state }) => unit.endsWith('.service') && includeStates.has(state));

  const services = [];
  for (const { unit, state } of units) {
    const active = await run('systemctl', [...baseArgs, 'is-active', unit], { timeout: 3000 });
    const activeText = (active.stdout || active.stderr).trim();
    services.push({
      kind: 'systemd',
      scope,
      id: unit,
      name: unit,
      status: activeText === 'active' ? 'running' : activeText === 'failed' ? 'failed' : 'stopped',
      rawStatus: `${activeText || 'unknown'}; ${state}`,
      unit
    });
  }
  return services;
}

async function manage(item, action) {
  const service = item && item.service;
  if (!service) return;

  const command = service.kind === 's6' ? 's6-svc' : 'systemctl';
  let args;
  if (service.kind === 's6') {
    const flag = action === 'start' ? '-u' : action === 'stop' ? '-d' : '-r';
    args = [flag, service.path];
  } else {
    const baseArgs = service.scope === 'user' ? ['--user'] : [];
    args = [...baseArgs, action, service.unit];
  }

  OUTPUT.appendLine(`$ ${command} ${args.join(' ')}`);
  const result = await run(command, args, { timeout: 15000 });
  if (result.stdout.trim()) OUTPUT.appendLine(result.stdout.trim());
  if (result.stderr.trim()) OUTPUT.appendLine(result.stderr.trim());
  if (!result.ok) {
    vscode.window.showErrorMessage(`${action} failed for ${service.name}`);
  }
}

async function showDetails(item) {
  const service = item && item.service;
  if (!service) return;

  OUTPUT.show(true);
  OUTPUT.appendLine('');
  OUTPUT.appendLine(`== ${service.kind}:${service.name} ==`);
  OUTPUT.appendLine(`generated: ${new Date().toISOString()}`);

  if (service.kind === 's6') {
    const result = await run('s6-svstat', [service.path], { timeout: 3000 });
    const rawStatus = (result.stdout || result.stderr).trim();
    const pid = parseS6Pid(rawStatus);
    const pgid = parseS6Pgid(rawStatus);
    const runScript = await readText(path.join(service.path, 'run'));
    const pids = pgid ? (await processGroup(pgid)).split(/\r?\n/).slice(1).map((line) => Number(line.trim().split(/\s+/)[0])).filter(Boolean) : [pid].filter(Boolean);
    const ports = await portsForPids(pids);
    const logs = await s6Logs(service);

    OUTPUT.appendLine(formatSection('Description', s6Description(service, runScript)));
    OUTPUT.appendLine(formatSection('Status', rawStatus));
    OUTPUT.appendLine(formatSection('PID', pid ? `main pid: ${pid}\nprocess group: ${pgid || '(unknown)'}` : '(not running)'));
    OUTPUT.appendLine(formatSection('Ports', ports || '(no listening TCP ports found)'));
    OUTPUT.appendLine(formatSection('Processes', pgid ? await processGroup(pgid) : await processTreeForPid(pid)));
    OUTPUT.appendLine(formatSection('Logs', logs));
    return;
  }

  const baseArgs = service.scope === 'user' ? ['--user'] : [];
  const show = await run('systemctl', [...baseArgs, 'show', service.unit, '--property=Description,MainPID,ActiveState,SubState,FragmentPath,ExecMainStartTimestamp'], { timeout: 5000 });
  const props = parseKeyValues(show.stdout || show.stderr);
  const pid = Number(props.MainPID || 0) || undefined;
  const pids = await childPidsForMain(pid);
  const status = await run('systemctl', [...baseArgs, 'status', service.unit], { timeout: 5000 });
  const logs = await systemdLogs(service, baseArgs);

  OUTPUT.appendLine(formatSection('Description', props.Description || '(no description)'));
  OUTPUT.appendLine(formatSection('Status', [
    `active: ${props.ActiveState || service.status}`,
    `substate: ${props.SubState || '(unknown)'}`,
    `started: ${props.ExecMainStartTimestamp || '(unknown)'}`,
    `unit file: ${props.FragmentPath || '(unknown)'}`
  ].join('\n')));
  OUTPUT.appendLine(formatSection('PID', pid ? `main pid: ${pid}` : '(not running or unavailable)'));
  OUTPUT.appendLine(formatSection('Ports', await portsForPids(pids) || '(no listening TCP ports found)'));
  OUTPUT.appendLine(formatSection('Processes', await processTreeForPid(pid)));
  OUTPUT.appendLine(formatSection('Logs', logs || (status.stdout || status.stderr)));
}

function s6Description(service, runScript) {
  const firstComment = runScript
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find((line) => line.startsWith('#') && !line.startsWith('#!'));
  return [
    firstComment ? firstComment.replace(/^#\s*/, '') : service.name,
    `service dir: ${service.path}`
  ].join('\n');
}

async function s6Logs(service) {
  const logDir = path.join(service.path, 'log');
  if (await fileExists(logDir)) {
    const stat = await run('s6-svstat', [logDir], { timeout: 3000 });
    const current = await tailFile(path.join(logDir, 'main', 'current'));
    return [`log service: ${(stat.stdout || stat.stderr).trim()}`, current].filter(Boolean).join('\n');
  }

  const candidates = [
    `/config/logs/${service.name}.log`,
    `/config/logs/${service.name}/out.log`,
    `/config/logs/${service.name}/err.log`,
    `/config/.local/log/user-systemd/${service.name}.log`,
    `/config/.local/log/user-systemd/${service.name}.start.log`
  ];
  const chunks = [];
  for (const file of candidates) {
    if (await fileExists(file)) {
      chunks.push(`--- ${file} ---\n${await tailFile(file)}`);
    }
  }
  return chunks.join('\n') || 'No dedicated s6 log file found. If this service writes to stdout/stderr, it may only be visible in the container logs.';
}

async function systemdLogs(service, baseArgs) {
  const journal = await run('journalctl', [...baseArgs, '-u', service.unit, '-n', '120', '--no-pager'], { timeout: 8000 });
  const journalText = (journal.stdout || journal.stderr).trim();
  if (journal.ok && journalText) return journalText;

  const baseName = service.unit.replace(/\.service$/, '');
  const candidates = [
    `/config/.local/log/user-systemd/${baseName}.log`,
    `/config/.local/log/user-systemd/${baseName}.start.log`,
    `/config/logs/${baseName}.log`,
    `/config/logs/${baseName}/out.log`,
    `/config/logs/${baseName}/err.log`
  ];
  const chunks = [];
  for (const file of candidates) {
    if (await fileExists(file)) {
      chunks.push(`--- ${file} ---\n${await tailFile(file)}`);
    }
  }
  if (chunks.length) return chunks.join('\n');
  return journalText;
}

function activate(context) {
  const provider = new ServiceProvider();
  vscode.window.registerTreeDataProvider('unifiedServiceManager.services', provider);

  context.subscriptions.push(
    OUTPUT,
    vscode.commands.registerCommand('unifiedServiceManager.refresh', () => provider.refresh()),
    vscode.commands.registerCommand('unifiedServiceManager.start', async (item) => { await manage(item, 'start'); provider.refresh(); }),
    vscode.commands.registerCommand('unifiedServiceManager.stop', async (item) => { await manage(item, 'stop'); provider.refresh(); }),
    vscode.commands.registerCommand('unifiedServiceManager.restart', async (item) => { await manage(item, 'restart'); provider.refresh(); }),
    vscode.commands.registerCommand('unifiedServiceManager.showDetails', showDetails)
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
