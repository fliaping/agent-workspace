#!/usr/bin/env node

import http from "node:http";
import net from "node:net";
import process from "node:process";
import { spawn } from "node:child_process";

const rawArgs = process.argv.slice(2);
let listenHost = "127.0.0.1";
let listenPort = 3080;
const dshArgs = [];

for (let index = 0; index < rawArgs.length; index += 1) {
  const arg = rawArgs[index];
  if (arg === "--host" && rawArgs[index + 1]) {
    listenHost = rawArgs[index + 1];
    index += 1;
  } else if (arg.startsWith("--host=")) {
    listenHost = arg.slice("--host=".length);
  } else if (arg === "--port" && rawArgs[index + 1]) {
    listenPort = Number.parseInt(rawArgs[index + 1], 10);
    index += 1;
  } else if (arg.startsWith("--port=")) {
    listenPort = Number.parseInt(arg.slice("--port=".length), 10);
  } else {
    dshArgs.push(arg);
  }
}

if (!Number.isInteger(listenPort) || listenPort < 1 || listenPort > 65534) {
  throw new Error(`invalid DeepSeek Harness Web port: ${String(listenPort)}`);
}

const upstreamHost = "127.0.0.1";
const upstreamPort = Number.parseInt(
  process.env.DSH_WEB_UPSTREAM_PORT || String(listenPort + 1),
  10,
);
if (
  !Number.isInteger(upstreamPort) ||
  upstreamPort < 1 ||
  upstreamPort > 65535 ||
  upstreamPort === listenPort
) {
  throw new Error(`invalid DeepSeek Harness upstream port: ${String(upstreamPort)}`);
}
const publicPrefix = (
  process.env.DSH_WEB_PROXY_PREFIX || `/proxy/${String(listenPort)}`
).replace(/\/$/u, "");
const dshBin = process.env.DSH_BIN || "/config/.npm-global/bin/dsh";

function upstreamPath(requestUrl = "/") {
  const parsed = new URL(requestUrl, "http://agent-workspace.local");
  if (parsed.pathname === publicPrefix) {
    parsed.pathname = "/";
  } else if (parsed.pathname.startsWith(`${publicPrefix}/`)) {
    parsed.pathname = parsed.pathname.slice(publicPrefix.length);
  }
  return `${parsed.pathname}${parsed.search}`;
}

function rewriteBrowserPaths(value) {
  const roots = "(?:(?:assets|plugins|api)(?:/|(?=[^A-Za-z0-9_.-]))|manifest\\.webmanifest|favicon\\.svg)";
  const quotedRoot = new RegExp(
    "([\"'\\u0060])/(?=" + roots + ")",
    "gu",
  );
  const attributeRoot = new RegExp(
    `(\\b(?:src|href|action)=)/(?=${roots})`,
    "giu",
  );
  return value
    .replace(quotedRoot, `$1${publicPrefix}/`)
    .replace(attributeRoot, `$1${publicPrefix}/`);
}

function isTextResponse(headers) {
  const type = String(headers["content-type"] || "").toLowerCase();
  return /(?:text\/|javascript|json|manifest|xml|svg)/u.test(type);
}

const child = spawn(
  dshBin,
  [
    "web",
    ...dshArgs,
    "--host",
    upstreamHost,
    "--port",
    String(upstreamPort),
  ],
  {
    cwd: process.env.DSH_WORKSPACE || "/config/Workspace",
    env: process.env,
    stdio: "inherit",
  },
);

child.once("error", (error) => {
  console.error(`[deepseek-harness-proxy] failed to start dsh: ${error.message}`);
  process.exitCode = 1;
});
child.once("exit", (code, signal) => {
  console.error(
    `[deepseek-harness-proxy] dsh exited (${signal || String(code ?? 1)})`,
  );
  process.exit(code ?? 1);
});
process.once("exit", () => {
  if (!child.killed) child.kill("SIGTERM");
});

const server = http.createServer((request, response) => {
  const headers = { ...request.headers };
  headers.host = `${upstreamHost}:${String(upstreamPort)}`;
  headers["accept-encoding"] = "identity";

  const proxyRequest = http.request(
    {
      host: upstreamHost,
      port: upstreamPort,
      method: request.method,
      path: upstreamPath(request.url),
      headers,
    },
    (proxyResponse) => {
      const responseHeaders = { ...proxyResponse.headers };
      if (
        typeof responseHeaders.location === "string" &&
        responseHeaders.location.startsWith("/")
      ) {
        responseHeaders.location = `${publicPrefix}${responseHeaders.location}`;
      }

      if (!isTextResponse(responseHeaders)) {
        response.writeHead(proxyResponse.statusCode || 502, responseHeaders);
        proxyResponse.pipe(response);
        return;
      }

      const chunks = [];
      proxyResponse.on("data", (chunk) => chunks.push(chunk));
      proxyResponse.on("end", () => {
        const body = rewriteBrowserPaths(Buffer.concat(chunks).toString("utf8"));
        delete responseHeaders["content-length"];
        delete responseHeaders["content-encoding"];
        delete responseHeaders["transfer-encoding"];
        delete responseHeaders.etag;
        responseHeaders["content-length"] = Buffer.byteLength(body);
        response.writeHead(proxyResponse.statusCode || 502, responseHeaders);
        response.end(body);
      });
    },
  );

  proxyRequest.once("error", (error) => {
    if (!response.headersSent) {
      response.writeHead(502, { "content-type": "text/plain; charset=utf-8" });
    }
    response.end(`DeepSeek Harness is starting: ${error.message}\n`);
  });
  request.pipe(proxyRequest);
});

server.on("upgrade", (request, socket, head) => {
  const upstream = net.connect(upstreamPort, upstreamHost);
  upstream.once("connect", () => {
    const lines = [
      `${request.method || "GET"} ${upstreamPath(request.url)} HTTP/${request.httpVersion}`,
    ];
    for (const [name, rawValue] of Object.entries(request.headers)) {
      if (name.toLowerCase() === "host" || rawValue === undefined) continue;
      const values = Array.isArray(rawValue) ? rawValue : [rawValue];
      for (const value of values) lines.push(`${name}: ${value}`);
    }
    lines.push(`host: ${upstreamHost}:${String(upstreamPort)}`, "", "");
    upstream.write(lines.join("\r\n"));
    if (head.length > 0) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
  upstream.once("error", () => socket.destroy());
});

server.listen(listenPort, listenHost, () => {
  console.log(
    `[deepseek-harness-proxy] http://${listenHost}:${String(listenPort)} -> ${upstreamHost}:${String(upstreamPort)} (${publicPrefix}/)`,
  );
});

function shutdown(signal) {
  server.close();
  if (!child.killed) child.kill(signal);
  setTimeout(() => process.exit(0), 1500).unref();
}

process.once("SIGINT", () => shutdown("SIGINT"));
process.once("SIGTERM", () => shutdown("SIGTERM"));
