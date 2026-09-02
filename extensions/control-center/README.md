# Agent Workspace Control Center

The single code-server entry point for Agent Workspace onboarding and daily
operations. It presents Agents, global MCP servers and Skills, workspace access,
services, ports, proxy routes, capabilities, and diagnostics while using
`workspacectl --json` as its backend.

Selkies Desktop has its own first-class page for runtime state, editor
integration, access, session operations, and consent-based Agent control of the
user's current Chromium window. The separate Network page keeps
SSH, custom-domain Caddy routing, and optional Tailscale userspace access in one
place. Tailscale authentication is deliberately handed to an interactive
terminal instead of being collected by the webview.

Global Skills use `npx skills` with `/config/.agents/skills` as the shared
source. MCP management can use the optional MCPM runtime for install-once
profiles, while native Codex, Claude Code, Hermes, and Agent Workspace-managed
DeepSeek Harness configuration remains visible and operable through the same
page. DeepSeek Harness opens on the same authenticated code-server origin at
`/proxy/3080/`.

The top-bar language switch changes Control Center and the complete code-server
interface between English and Simplified Chinese, then restarts the editor so
the selection applies consistently.

The extension intentionally keeps the CLI as the source of truth so the same
operations remain available to interactive Agents and SSH-only users.
