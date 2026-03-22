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

## Accessing the UI

Once running, the dashPanel interface is accessible directly from the **Pool** entry in the
Home Assistant sidebar.

The controller REST API and Socket.IO endpoint are available at `http://<ha-host>:4200` for
external integrations (MQTT, other HA integrations, SmartThings, etc.).

## First-time Setup

1. Start the add-on
2. Open the Pool panel from the HA sidebar
3. Follow the njspc first-run wizard to configure your pool equipment type and settings
4. All configuration is saved persistently and survives add-on restarts

## Persisted Data

All njspc and dashPanel configuration and logs are stored in `/data/` inside the add-on container,
which Home Assistant persists automatically across restarts and updates.
