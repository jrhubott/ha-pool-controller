# Pool Controller Add-on

This add-on packages [nodejs-poolController](https://github.com/tagyoureit/nodejs-poolController)
and the [dashPanel UI](https://github.com/rstrouse/nodejs-poolController-dashPanel) into a single
Home Assistant add-on for controlling Pentair pool equipment (IntelliCenter, IntelliTouch,
EasyTouch, and others) over RS-485 serial.

## Prerequisites

- An RS-485 serial adapter connected to your Pentair pool controller (e.g., USB RS-485 dongle)
- The adapter must be visible to your Home Assistant host as a `/dev/tty*` device

## Configuration

### Serial Port

Select the RS-485 serial device connected to your pool equipment from the dropdown.
Common values:
- `/dev/ttyUSB0` — USB RS-485 adapter
- `/dev/ttyAMA0` — onboard UART (Raspberry Pi)

### Log Level

Controls the verbosity of the nodejs-poolController log output visible in the add-on logs tab:
- `error` — only errors
- `warn` — errors and warnings
- `info` — normal operation (default)
- `debug` — detailed debugging output
- `silly` — maximum verbosity (very verbose)

### MQTT

To publish pool state to an MQTT broker, enable MQTT and provide the broker connection details:

| Option | Description |
|--------|-------------|
| `mqtt_enabled` | Enable or disable MQTT publishing |
| `mqtt_host` | Broker hostname or IP address |
| `mqtt_port` | Broker port (default: 1883) |
| `mqtt_username` | Broker username (optional) |
| `mqtt_password` | Broker password (optional) |

### Network

Both the dashPanel UI and the njspc REST API are **not exposed** on the local network by default.
They are accessible through HA's ingress proxy (sidebar) without any port configuration.

To enable direct local network access, open the add-on's **Configuration** tab, go to **Network**,
and set the desired host port(s):

| Port | Purpose | Suggested host port |
|------|---------|-------------------|
| `4200/tcp` | njspc REST API / Socket.IO — for external integrations (MQTT, SmartThings, REST) | 4200 |
| `5150/tcp` | dashPanel UI — for direct browser access without HA ingress | 5150 |

Save and restart the add-on. Clear a field to disable that port again.

- API: `http://<ha-host>:4200`
- dashPanel: `http://<ha-host>:5150`

## Accessing the UI

Once running, the dashPanel interface is accessible directly from the **Pool** entry in the
Home Assistant sidebar. The UI is served through HA's ingress proxy and does not require
any port configuration.

## First-time Setup

1. Start the add-on
2. Open the Pool panel from the HA sidebar
3. Follow the njspc first-run wizard to configure your pool equipment type and settings
4. All configuration is saved persistently and survives add-on restarts

## Persisted Data

Configuration files are stored in `/share/pool-controller/` and are accessible via the
Home Assistant file editor:

| File | Purpose |
|------|---------|
| `njspc/config.json` | njspc main configuration (serial port, MQTT, web server settings) |
| `njspc/data/poolConfig.json` | Pool equipment config (circuits, pumps, schedules, names) |
| `dashpanel/config.json` | dashPanel UI configuration |

Logs and backups are stored in private add-on storage (`/data/`) and persist across restarts.


