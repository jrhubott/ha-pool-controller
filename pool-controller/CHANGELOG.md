# Changelog

## 1.0.24

- Remove always_report_solar_temp option: investigation confirmed data.solar is
  never undefined on systems with a solar heater configured, so the upstream MQTT
  filter does not suppress solar temp reporting in normal use

## 1.0.23

- Fix mqtt.json solar temp patch: add select(type == "object") to skip string
  elements in context array, resolving jq "Cannot index string with string" error

## 1.0.22

- Add "Always Report Solar Temperature" config option (default: on) — replaces
  the build-time patch with a runtime toggle; solar temp is now published via MQTT
  even when pumps are off, controllable from the add-on configuration screen
- Remove 001-always-report-solar-mqtt.patch (behavior now handled in init-njspc.sh)

## 1.0.21

- Document patch system and included patches in DOCS.md and README.md

## 1.0.20

- Fix Dockerfile build failure: re-declare NJSPC_REF inside controller-build stage
  (global ARGs before FROM are not available inside stages without re-declaration)

## 1.0.19

- Suppress spurious "Connection refused" log output during dashPanel startup wait
- Move NJSPC_REF and DASHPANEL_TAG ARGs to global Dockerfile section

## 1.0.18

- Fix dashPanel WebSocket error on startup: dashPanel now waits for the controller
  to be listening on port 4200 before starting, eliminating the race condition

## 1.0.17

- Add optional host network exposure for dashPanel UI on port 5150 (disabled by default;
  enable in the add-on Network configuration)

## 1.0.16

- Update DOCS.md: add MQTT configuration section, document port 4200 as opt-in,
  update persisted data section to show /share/ layout with poolConfig.json

## 1.0.15

- Expose poolConfig.json (circuits, pumps, schedules, equipment) in /share/pool-controller/njspc/data/
- Previously persisted in private /data/njspc/data/ (not visible in HA file editor); now
  symlinked from /share/ so it is accessible and editable via the HA file editor
- One-time migration moves existing poolConfig.json from /data/ to /share/ on upgrade

## 1.0.14

- Default port 4200 (njspc REST API) to disabled; enable in the add-on Network configuration
  by setting the host port to 4200 (clear the field to disable again)

## 1.0.13

- Fix pool configuration (alias, owner, location, circuits, pumps, schedules) lost on restart
- njspc stores pool/equipment config in data/poolConfig.json, not config.json; symlink
  /app/njspc/data/ to /data/njspc/data/ so all pool config survives restarts and updates

## 1.0.12

- Fix njspc config settings (alias, owner, location, etc.) being lost on restart
- njspc saves config via atomic write (temp+rename), which replaced the symlink at
  /app/njspc/config.json with a real file; init script now detects this and syncs
  the file back to /share before patching, preserving all user-saved settings

## 1.0.11

- Add NJSPC_REF and DASHPANEL_TAG build args to control upstream versions
- NJSPC_REF accepts any git tag (e.g. v8.4.0) or branch (e.g. main); defaults to v8.4.0
- DASHPANEL_TAG accepts any ghcr.io/rstrouse/njspc-dash image tag; defaults to latest

## 1.0.8

- Switch from addon_config map (not bind-mounted by this HA Supervisor version) to
  share:rw map — configs now visible in file editor under /share/pool-controller/

## 1.0.7

- Move config.json files to /addon_config/ (mapped to /addon_configs/pool-controller/
  on the host) so they are accessible via the HA file editor
- Logs and backups remain in /data/ (private add-on storage)

## 1.0.6

- Add MQTT options to add-on config: mqtt_enabled, mqtt_host, mqtt_port,
  mqtt_username, mqtt_password (password type, masked in UI)
- Init script patches all MQTT settings into njspc config.json on every start

## 1.0.5

- Fix dashPanel "httplocalhost:" error on restart: set protocol="http://", ip=$(hostname),
  port=4200, useProxy=true in config on every start. The add-on hostname (e.g.
  71a43e53-pool-controller) is read dynamically so it works on any HA installation.

## 1.0.4

- Remove POOL_WEB_SERVICES_* env vars from dashPanel service; connection is
  configured via config.json — env vars were causing "httplocalhost:" protocol error

## 1.0.3

- Enable dashPanel proxy mode by default (web.services.useProxy = true) so the
  browser connects to njsPC via the dashPanel server when running behind HA ingress

## 1.0.2

- Create dashPanel outQueues directory and symlink to /app/dashpanel/data/outQueues/

## 1.0.1

- Keep curl in final image so bashio can communicate with the HA Supervisor API
- Create /data/ subdirectories in init script (HA volume mount hides Dockerfile-created dirs)

## 1.0.0

- Initial release
- nodejs-poolController v8.3.0 built from source
- dashPanel pulled from ghcr.io/rstrouse/njspc-dash
- Serial port device selector in add-on configuration
- Log level selector in add-on configuration
- Patch file support via patches/ directory
