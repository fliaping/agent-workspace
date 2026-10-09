#!/bin/bash
# ============================================================
# tailscale-authkey-init.sh — stage a Tailscale auth key at boot
#
# Runs from /custom-cont-init.d as root before services start.
# TAILSCALE_AUTHKEY (or the official alias TS_AUTHKEY) is removed from the
# s6 container environment, whose files are world-readable, so no service,
# desktop session, or terminal inherits it. The key (or the contents of
# TAILSCALE_AUTHKEY_FILE) is written to a 0600 file on /run that
# workspace-bootstrap hands to `tailscale up --auth-key=file:...` and deletes.
# The key itself is never printed.
# ============================================================
set -u

env_dir="${AGENT_WORKSPACE_CONTAINER_ENV_DIR:-/run/s6/container_environment}"
key_file="${AGENT_WORKSPACE_TAILSCALE_KEY_FILE:-/run/agent-workspace/tailscale-authkey}"

key=""
for name in TAILSCALE_AUTHKEY TS_AUTHKEY; do
  if [[ -z "$key" && -n "${!name:-}" ]]; then
    key="${!name}"
  fi
  rm -f -- "$env_dir/$name"
done

source_file="${TAILSCALE_AUTHKEY_FILE:-}"
if [[ -z "$key" && -n "$source_file" ]]; then
  if [[ -r "$source_file" ]]; then
    key="$(tr -d '[:space:]' <"$source_file")"
  else
    echo "[tailscale-authkey] TAILSCALE_AUTHKEY_FILE is not readable: $source_file" >&2
  fi
fi

rm -f -- "$key_file"
if [[ -z "$key" ]]; then
  exit 0
fi

key_dir="$(dirname "$key_file")"
mkdir -p "$key_dir"
chmod 700 "$key_dir"
(
  umask 077
  printf '%s\n' "$key" >"$key_file"
)
chmod 600 "$key_file"
if [[ "$(id -u)" == "0" ]] && id abc >/dev/null 2>&1; then
  chown abc:abc "$key_dir" "$key_file"
fi
echo "[tailscale-authkey] auth key staged for automatic tailnet login"
