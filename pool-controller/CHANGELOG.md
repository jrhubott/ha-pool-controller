# Changelog

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
