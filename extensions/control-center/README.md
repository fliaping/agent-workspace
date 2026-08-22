# Agent Workspace Control Center

The single code-server entry point for Agent Workspace onboarding and daily
operations. It presents Agents, workspace access, services, ports, proxy routes,
capabilities, and diagnostics while using `workspacectl --json` as its backend.

The extension intentionally keeps the CLI as the source of truth so the same
operations remain available to interactive Agents and SSH-only users.
