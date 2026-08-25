import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const scriptRoot = path.dirname(fileURLToPath(import.meta.url));
const extensionFile = path.resolve(scriptRoot, '../extensions/control-center/extension.js');

function loadRenderers(language) {
  const marker = 'module.exports = { activate, deactivate };';
  const replacement = 'module.exports = { controlCenterHtml, quickViewHtml };';
  const source = fs.readFileSync(extensionFile, 'utf8').replace(marker, replacement);
  const module = { exports: {} };
  const vscode = {
    env: { language },
    window: { createOutputChannel: () => ({}) },
    StatusBarAlignment: { Left: 1 },
    ThemeColor: class {}
  };
  vm.runInNewContext(source, {
    module,
    exports: module.exports,
    require: (name) => name === 'vscode' ? vscode : require(name),
    __dirname: path.dirname(extensionFile),
    __filename: extensionFile,
    Buffer,
    URL,
    process,
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval
  }, { filename: extensionFile });
  return module.exports;
}

function inlineScripts(html) {
  return [...html.matchAll(/<script nonce="[^"]+">([\s\S]*?)<\/script>/g)]
    .map((match) => match[1]);
}

for (const language of ['en', 'zh-cn']) {
  const renderers = loadRenderers(language);
  const webview = { cspSource: 'self' };
  for (const [name, html] of [
    ['control center', renderers.controlCenterHtml(webview, false)],
    ['quick view', renderers.quickViewHtml(webview)]
  ]) {
    const scripts = inlineScripts(html);
    assert.ok(scripts.length > 0, `${language} ${name} has no inline script`);
    for (const script of scripts) {
      assert.doesNotThrow(
        () => new Function(script),
        `${language} ${name} generated invalid JavaScript`
      );
    }
  }
}

console.log('Control Center generated webview scripts: ok');
