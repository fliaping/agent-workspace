# Persistent Custom s6 Services

The image supports user-defined s6 services that persist under `/config` and are
automatically registered after a container rebuild.

## Image Implementation

The base image includes:

```text
scripts/register-config-services.sh
services/custom-services/run
services/custom-services/dependencies/init
```

`services/custom-services` is a built-in s6 service copied to
`/etc/services.d/custom-services`. It depends on the existing `init` service, so
registration runs after the image has completed its base initialization.

At startup it runs:

```bash
/usr/local/bin/register-config-services.sh
```

The script scans:

```text
/config/custom-services.d
```

and creates runtime links:

```text
/run/service/<service-name> -> /config/custom-services.d/<service-name>
```

Then it asks `s6-svscan` to rescan `/run/service`.

## Runtime Layout

Users define services only under `/config`:

```text
/config/custom-services.d/<service-name>/run
```

The `run` file must be executable.

## Compose Volumes

No `/custom-cont-init.d` or `/custom-services.d` bind mount is required.

```yaml
volumes:
  - ./home:/config
  - ./linuxbrew:/home/linuxbrew/.linuxbrew
  - ./docker-compose.yml:/docker-compose.yml:ro
```

## Example Service

```text
/config/custom-services.d/futu-opend/run
```

```bash
#!/usr/bin/with-contenv bash
set -euo pipefail
cd /config/futu-opend
exec s6-setuidgid abc ./FutuOpenD -cfg_file=/config/futu-opend/FutuOpenD.xml -no_monitor=1 -console=1
```

Make it executable:

```bash
chmod +x /config/custom-services.d/futu-opend/run
```

After a container rebuild, `/config` is mounted back, the built-in
`custom-services` registrar runs, and the service is registered and started
automatically.

To rescan manually after adding a service at runtime:

```bash
s6-svc -r /run/service/custom-services
```
