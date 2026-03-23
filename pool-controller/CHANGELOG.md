# Changelog

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
