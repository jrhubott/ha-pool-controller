# ha-pool-controller

A Home Assistant add-on repository that packages
[nodejs-poolController](https://github.com/tagyoureit/nodejs-poolController)
and the [dashPanel UI](https://github.com/rstrouse/nodejs-poolController-dashPanel)
into a single, self-contained add-on for controlling Pentair pool equipment via RS-485 serial.

## What it does

- Controls Pentair pool equipment (IntelliCenter, IntelliTouch, EasyTouch, and more)
- Embeds the dashPanel web UI directly in the Home Assistant sidebar
- Optionally exposes the njspc REST API and Socket.IO on port 4200 for external integrations (disabled by default — enable in the add-on's Network configuration)
- Configures the RS-485 serial port via the standard HA add-on UI

## Prerequisites

- Home Assistant with the Supervisor (Home Assistant OS or Supervised install)
- An RS-485 serial adapter connected to your Pentair pool controller

## Adding this repository to Home Assistant

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮ menu** in the top-right and select **Repositories**
3. Enter the repository URL:
   ```
   https://github.com/jrhubott/ha-pool-controller
   ```
4. Click **Add**, then close the dialog
5. Find **Pool Controller** in the add-on store and click **Install**

## Configuring the add-on

After installation, open the add-on's **Configuration** tab:

| Option | Description |
|--------|-------------|
| Serial Port | Select the RS-485 adapter device (e.g. `/dev/ttyUSB0`) |
| Log Level | Verbosity: `error` / `warn` / `info` / `debug` / `silly` |
| MQTT | Enable/disable MQTT integration and configure broker connection |
| Always Report Solar Temp | Publish solar temperature via MQTT even when pumps are off (default: on) |

### Network configuration

The njspc REST API (port 4200) is **disabled by default**. To expose it on your local network for external integrations:

1. Open the add-on's **Configuration** tab
2. Under **Network**, set the host port for `4200/tcp` to `4200` (or any port you prefer)
3. Clear the field to disable it again

Save, then start the add-on. The **Pool** panel will appear in the HA sidebar.

### Persistent files

User-editable config files are stored in `/share/pool-controller/` (accessible via the HA file editor):

| File | Purpose |
|------|---------|
| `njspc/config.json` | njspc main configuration (serial, MQTT, web server) |
| `njspc/data/poolConfig.json` | Pool equipment config (circuits, pumps, schedules) |
| `dashpanel/config.json` | dashPanel UI configuration |

## Building locally

### Docker

Requirements: Docker with BuildKit enabled.

```bash
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local \
  pool-controller/
```

### Podman

Match the `BUILD_FROM` image to your host architecture:

**x86-64 host:**
```bash
podman build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local \
  pool-controller/
```

**ARM64 host (Apple Silicon, Raspberry Pi 4/5):**
```bash
podman build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local \
  pool-controller/
```

**Cross-architecture build** (e.g. building amd64 on an ARM host — requires QEMU/binfmt):
```bash
podman build \
  --platform linux/amd64 \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  --build-arg NJSPC_REF=v8.4.0 \
  --build-arg DASHPANEL_TAG=latest \
  -t pool-controller:local \
  pool-controller/
```

Podman runs rootless by default. If the build fails pulling from `ghcr.io`, log in first:

```bash
podman login ghcr.io
```

To pin a specific njspc version or branch, pass `--build-arg NJSPC_REF=v8.3.0` or `--build-arg NJSPC_REF=main`.
To pin a dashPanel image tag, pass `--build-arg DASHPANEL_TAG=master` (available: `latest`, `master`, `sha-*`).

## Releasing a new version

When upstream components release new versions, update the following files:

### nodejs-poolController update

1. **`pool-controller/Dockerfile`** — update the `NJSPC_REF` default:
   ```dockerfile
   ARG NJSPC_REF=v8.5.0
   ```
2. Verify any existing patches in `pool-controller/patches/` still apply cleanly against the new version.

### dashPanel update

If a specific `sha-*` tag is preferred over `latest`:

1. **`pool-controller/Dockerfile`** — update the `DASHPANEL_TAG` default:
   ```dockerfile
   ARG DASHPANEL_TAG=sha-abc1234
   ```

### Add-on version bump

After any upstream update, bump the add-on version in **`pool-controller/config.yaml`**:
```yaml
version: "1.0.11"
```

Add an entry to **`pool-controller/CHANGELOG.md`** describing what changed.

## Applying patches to nodejs-poolController

Patches allow you to modify the njspc source code without forking the upstream repository.
They are applied at Docker build time via `git apply`.

### Creating a patch

```bash
# 1. Clone the upstream controller repo
git clone https://github.com/tagyoureit/nodejs-poolController.git
cd nodejs-poolController

# 2. Make your changes

# 3. Generate a patch file
git diff > ../ha-pool-controller/pool-controller/patches/001-my-fix.patch
```

Patches are named numerically (`001-`, `002-`, etc.) to control application order.
Any `.patch` files in `pool-controller/patches/` are automatically applied during the build.

### Included patches

No patches are currently shipped. The solar temperature MQTT behavior is now controlled at
runtime via the **Always Report Solar Temperature** add-on option instead.

## Repository structure

```
ha-pool-controller/
├── repository.yaml          # HA add-on repository metadata
├── pool-controller/
│   ├── config.yaml          # Add-on configuration and options schema
│   ├── build.yaml           # Per-architecture base image mappings
│   ├── Dockerfile           # 3-stage build: compile njspc, copy dashPanel, assemble
│   ├── DOCS.md              # User documentation shown in HA add-on UI
│   ├── CHANGELOG.md
│   ├── translations/
│   │   └── en.yaml          # Friendly labels for config options
│   ├── patches/             # Optional .patch files applied to njspc at build time
│   └── rootfs/              # Files copied into the container filesystem
│       └── etc/s6-overlay/
│           ├── scripts/
│           │   └── init-njspc.sh    # Init: bridges HA config → njspc config.json
│           └── s6-rc.d/
│               ├── init-njspc/      # Oneshot: runs init-njspc.sh at startup
│               ├── njspc-controller/  # Longrun: the pool controller process
│               └── njspc-dashpanel/   # Longrun: the dashPanel web UI
```

## Upstream projects

- [nodejs-poolController](https://github.com/tagyoureit/nodejs-poolController) — the pool equipment controller
- [nodejs-poolController-dashPanel](https://github.com/rstrouse/nodejs-poolController-dashPanel) — the dashboard UI
