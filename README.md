# ha-pool-controller

A Home Assistant add-on repository that packages
[nodejs-poolController](https://github.com/tagyoureit/nodejs-poolController)
and the [dashPanel UI](https://github.com/rstrouse/nodejs-poolController-dashPanel)
into a single, self-contained add-on for controlling Pentair pool equipment via RS-485 serial.

## What it does

- Controls Pentair pool equipment (IntelliCenter, IntelliTouch, EasyTouch, and more)
- Embeds the dashPanel web UI directly in the Home Assistant sidebar
- Exposes the njspc REST API and Socket.IO on port 4200 for external integrations
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

Save, then start the add-on. The **Pool** panel will appear in the HA sidebar.

## Building locally

Requirements: Docker with BuildKit enabled.

```bash
# From the pool-controller/ directory
docker build \
  --build-arg BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm \
  --build-arg NJSPC_VERSION=8.3.0 \
  -t pool-controller:local \
  pool-controller/
```

To test a specific njspc version, change `NJSPC_VERSION` to the desired tag.

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
