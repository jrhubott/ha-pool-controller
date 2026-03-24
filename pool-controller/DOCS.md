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

### Network (port 4200)

The njspc REST API and Socket.IO endpoint are **not exposed** on the local network by default.
To enable access for external integrations (MQTT clients, SmartThings, direct REST calls):

1. Open the add-on's **Configuration** tab
2. Under **Network**, set the host port for `4200/tcp` to `4200` (or any preferred port)
3. Save and restart the add-on

The API will then be available at `http://<ha-host>:4200`. Clear the field to disable it again.

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
