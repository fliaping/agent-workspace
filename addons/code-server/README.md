# code-server

This package installs the official standalone code-server distribution under
`/config/opt/code-server` and registers a persistent user service.

The secure default is:

```text
0.0.0.0:8443, password authentication, self-signed TLS
```

The installer reuses Webtop's `PASSWORD` when available, or accepts a separate
`CODE_SERVER_PASSWORD`. A browser warning is expected for the default
self-signed certificate.

```bash
CODE_SERVER_PASSWORD='replace-me' ./install.sh
```

An existing `/config/.config/code-server/config.yaml` is preserved. Set
`CODE_SERVER_RECONFIGURE=true` to replace it.

The browser interface defaults to English. Choose English or Simplified Chinese
from Control Center, or set it from a terminal. The setting is durable and the
`--restart` form reconnects code-server after applying it:

```bash
workspacectl locale zh-cn --restart
workspacectl locale en --restart
```

Passwordless mode is only for an authenticating gateway and requires an
explicit acknowledgement:

```bash
CODE_SERVER_AUTH=none \
CODE_SERVER_ALLOW_NO_AUTH=true \
CODE_SERVER_BIND=127.0.0.1:8443 \
CODE_SERVER_CERT=false \
./install.sh
```
