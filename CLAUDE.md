# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Home Assistant add-on repository that packages [nodejs-poolController](https://github.com/tagyoureit/nodejs-poolController) (Pentair pool equipment controller) and its [dashPanel UI](https://github.com/rstrouse/nodejs-poolController-dashPanel) into a single containerized add-on. The controller is built from source; the dashPanel is pulled from `ghcr.io/rstrouse/njspc-dash`.

## Build commands

```bash
# Build for amd64 (local dev/testing)
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local \
  pool-controller/

# Build for aarch64
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local-arm \
  pool-controller/
```

There are no automated tests in this repository. Validation is done by building the Docker image and testing against a live HA instance.

## Architecture

### Single-container design

Both services run inside one Docker container managed by **s6-overlay** (the init system used by all HA base images):

- **njspc-controller** (longrun): nodejs-poolController process, listens on port 4200, communicates with Pentair equipment via RS-485 serial
- **njspc-dashpanel** (longrun): dashPanel web UI, listens on port 5150, connects to the controller on `localhost:4200`
- **init-njspc** (oneshot): runs first, bridges HA add-on options → njspc `config.json`

The dashPanel is the ingress entry point (HA sidebar, port 5150) — it is **not** exposed on the host network, only accessible through HA's ingress proxy. The controller API (port 4200) defaults to disabled; users opt-in via the add-on's Network configuration in the HA UI.

### Dockerfile: 3-stage build

1. **controller-build** (`node:20-bookworm-slim`): clones njspc at `NJSPC_REF` (git tag or branch), applies any `.patch` files from `patches/`, runs `npm ci && npm run build && npm prune --production`
2. **dashpanel** (`ghcr.io/rstrouse/njspc-dash:${DASHPANEL_TAG}`): referenced only as a `COPY --from` source
3. **Final** (`$BUILD_FROM` = HA Debian base): installs Node.js 20 + jq, copies built artifacts from both prior stages, copies `rootfs/` into the container filesystem

### Configuration flow

HA add-on options (set in the HA UI) → `/data/options.json` → read by `bashio::config` in `init-njspc.sh` → patched into `/data/njspc/config.json` via `jq` on every container start.

Persistent data is split across two HA-managed volumes:

- `/share/pool-controller/` — user-editable via the HA file editor: `njspc/config.json`, `dashpanel/config.json`, and `njspc/data/` (contains `poolConfig.json` with equipment config)
- `/data/` — private add-on storage: `njspc/logs/`, `njspc/backups/`, `dashpanel/logs/`, `dashpanel/outQueues/`

The init script symlinks these into `/app/njspc/` and `/app/dashpanel/` so each process finds its config/data at the expected paths.

### Patch support

Drop `.patch` files into `pool-controller/patches/`. They are applied with `git apply` after cloning the njspc source in Stage 1. Name them numerically (`001-fix.patch`, `002-feature.patch`) to control application order.

To create a patch:
```bash
git clone https://github.com/tagyoureit/nodejs-poolController.git
cd nodejs-poolController
# make changes
git diff > ../pool-controller/patches/001-my-fix.patch
```

### Key files

| File | Purpose |
|------|---------|
| `pool-controller/config.yaml` | Add-on metadata, ingress config, port mappings, options schema |
| `pool-controller/build.yaml` | Maps amd64/aarch64 to HA Debian base images |
| `pool-controller/Dockerfile` | 3-stage build |
| `pool-controller/DOCS.md` | User-facing documentation shown in the HA add-on UI |
| `rootfs/etc/s6-overlay/scripts/init-njspc.sh` | Reads HA options, patches njspc config.json |
| `rootfs/etc/s6-overlay/s6-rc.d/*/run` | s6 service entrypoints |
| `pool-controller/patches/` | Optional njspc source patches |

When changing add-on configuration (options in `config.yaml`, port mappings, persistent data layout, or init script behaviour), always update `pool-controller/DOCS.md` to reflect the change.

### HA add-on specifics

- `init: false` in `config.yaml` — s6-overlay is managed via `s6-rc.d/` (v3 style), not the legacy `services.d/` style
- `ingress_stream: true` — required for Socket.IO (WebSocket) to pass through the HA ingress proxy
- `device(subsystem=tty)` schema type — renders a serial device dropdown in the HA config UI
- `uart: true` — grants container access to serial/UART devices
- `bashio` — bash helper library pre-installed in all HA base images; use `bashio::config 'key'` to read options, `bashio::log.info` for logging
- `ports` in `config.yaml` are static Docker mappings applied by the Supervisor before the container starts — they **cannot** be toggled dynamically via `options`. Setting a port default to `null` makes it opt-in; users enable/disable in the add-on's Network configuration UI
- njspc's InfluxDB integration uses binding templates in `web/bindings/influxDB.json` (inside the container at `/app/njspc/web/bindings/`). Bindings use `@bind=data.<field>;` syntax resolved via `eval()`. If equipment doesn't report a field, the binding fails and that measurement is skipped. Fix via a patch file or custom bindings file (`web/bindings/custom/`)
