#!/command/with-contenv bashio
# =============================================================================
# init-njspc.sh
# Runs once at container startup (s6 oneshot service).
# Reads HA add-on options, initialises config files in /data/, and patches
# the user-configured values (serial port, log level) into njspc's config.json.
# =============================================================================

bashio::log.info "Initialising nodejs-poolController..."

# ---------------------------------------------------------------------------
# Ensure persistent data directories exist
# HA mounts /data as a volume at runtime so these won't exist from the image
# ---------------------------------------------------------------------------
mkdir -p /data/njspc/logs /data/njspc/backups
mkdir -p /data/dashpanel/logs /data/dashpanel/backups

# ---------------------------------------------------------------------------
# Read add-on options
# ---------------------------------------------------------------------------
SERIAL_PORT=$(bashio::config 'serial_port')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.info "Serial port: ${SERIAL_PORT}"
bashio::log.info "Log level:   ${LOG_LEVEL}"

# ---------------------------------------------------------------------------
# njspc: initialise persistent config in /data/njspc/
# ---------------------------------------------------------------------------
if [ ! -f /data/njspc/config.json ]; then
    bashio::log.info "Creating default njspc config in /data/njspc/config.json"
    cp /app/njspc/defaultConfig.json /data/njspc/config.json
fi

# Patch serial port into config (always, to catch UI config changes)
if [ -n "${SERIAL_PORT}" ]; then
    tmp=$(mktemp)
    jq --arg port "${SERIAL_PORT}" \
        '.controller.comms.rs485Port = $port' \
        /data/njspc/config.json > "${tmp}" && mv "${tmp}" /data/njspc/config.json
    bashio::log.info "Set njspc serial port to ${SERIAL_PORT}"
fi

# Patch log level into config
if [ -n "${LOG_LEVEL}" ]; then
    tmp=$(mktemp)
    jq --arg level "${LOG_LEVEL}" \
        '.log.app = $level' \
        /data/njspc/config.json > "${tmp}" && mv "${tmp}" /data/njspc/config.json
    bashio::log.info "Set njspc log level to ${LOG_LEVEL}"
fi

# Ensure the web server binds on all interfaces at port 4200
tmp=$(mktemp)
jq '.web.servers.http.ip = "0.0.0.0" | .web.servers.http.port = 4200' \
    /data/njspc/config.json > "${tmp}" && mv "${tmp}" /data/njspc/config.json

# Symlink persistent config into the app directory
ln -sf /data/njspc/config.json /app/njspc/config.json

# Symlink log and backup directories
rm -rf /app/njspc/logs && ln -sf /data/njspc/logs /app/njspc/logs
rm -rf /app/njspc/backups && ln -sf /data/njspc/backups /app/njspc/backups

# ---------------------------------------------------------------------------
# dashPanel: initialise persistent config in /data/dashpanel/
# ---------------------------------------------------------------------------
if [ -f /app/dashpanel/defaultConfig.json ] && [ ! -f /data/dashpanel/config.json ]; then
    bashio::log.info "Creating default dashPanel config in /data/dashpanel/config.json"
    cp /app/dashpanel/defaultConfig.json /data/dashpanel/config.json
fi

if [ -f /data/dashpanel/config.json ]; then
    ln -sf /data/dashpanel/config.json /app/dashpanel/config.json
fi

if [ -d /app/dashpanel/logs ] || [ ! -L /app/dashpanel/logs ]; then
    rm -rf /app/dashpanel/logs && ln -sf /data/dashpanel/logs /app/dashpanel/logs
fi

bashio::log.info "Initialisation complete."
