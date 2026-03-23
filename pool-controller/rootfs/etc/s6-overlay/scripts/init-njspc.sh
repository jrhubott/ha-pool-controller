#!/command/with-contenv bashio
# =============================================================================
# init-njspc.sh
# Runs once at container startup (s6 oneshot service).
# Reads HA add-on options, initialises config files in /data/, and patches
# the user-configured values (serial port, log level) into njspc's config.json.
# =============================================================================

bashio::log.info "Initialising nodejs-poolController..."

# ---------------------------------------------------------------------------
# Ensure directories exist
# /addon_config is mounted from /addon_configs/<slug>/ on the host — accessible
# via the HA file editor. Used for config.json files users may want to edit.
# /data is private add-on storage — used for logs, backups, runtime data.
# ---------------------------------------------------------------------------
mkdir -p /addon_config/njspc /addon_config/dashpanel
mkdir -p /data/njspc/logs /data/njspc/backups
mkdir -p /data/dashpanel/logs /data/dashpanel/backups /data/dashpanel/outQueues

# ---------------------------------------------------------------------------
# Read add-on options
# ---------------------------------------------------------------------------
SERIAL_PORT=$(bashio::config 'serial_port')
LOG_LEVEL=$(bashio::config 'log_level')
MQTT_ENABLED=$(bashio::config 'mqtt_enabled')
MQTT_HOST=$(bashio::config 'mqtt_host')
MQTT_PORT=$(bashio::config 'mqtt_port')
MQTT_USERNAME=$(bashio::config 'mqtt_username')
MQTT_PASSWORD=$(bashio::config 'mqtt_password')

bashio::log.info "Serial port:  ${SERIAL_PORT}"
bashio::log.info "Log level:    ${LOG_LEVEL}"
bashio::log.info "MQTT enabled: ${MQTT_ENABLED}"

# ---------------------------------------------------------------------------
# njspc: config stored in /addon_config/njspc/ (visible in HA file editor)
# ---------------------------------------------------------------------------
if [ ! -f /addon_config/njspc/config.json ]; then
    bashio::log.info "Creating default njspc config in /addon_config/njspc/config.json"
    cp /app/njspc/defaultConfig.json /addon_config/njspc/config.json
fi

# Patch serial port into config (always, to catch UI config changes)
if [ -n "${SERIAL_PORT}" ]; then
    tmp=$(mktemp)
    jq --arg port "${SERIAL_PORT}" \
        '.controller.comms.rs485Port = $port' \
        /addon_config/njspc/config.json > "${tmp}" && mv "${tmp}" /addon_config/njspc/config.json
    bashio::log.info "Set njspc serial port to ${SERIAL_PORT}"
fi

# Patch log level into config
if [ -n "${LOG_LEVEL}" ]; then
    tmp=$(mktemp)
    jq --arg level "${LOG_LEVEL}" \
        '.log.app = $level' \
        /addon_config/njspc/config.json > "${tmp}" && mv "${tmp}" /addon_config/njspc/config.json
    bashio::log.info "Set njspc log level to ${LOG_LEVEL}"
fi

# Ensure the web server binds on all interfaces at port 4200
tmp=$(mktemp)
jq '.web.servers.http.ip = "0.0.0.0" | .web.servers.http.port = 4200' \
    /addon_config/njspc/config.json > "${tmp}" && mv "${tmp}" /addon_config/njspc/config.json

# ---------------------------------------------------------------------------
# MQTT configuration
# ---------------------------------------------------------------------------
tmp=$(mktemp)
jq --argjson enabled "${MQTT_ENABLED}" \
    --arg host "${MQTT_HOST}" \
    --argjson port "${MQTT_PORT}" \
    --arg username "${MQTT_USERNAME}" \
    --arg password "${MQTT_PASSWORD}" \
    '.mqtt.enabled = $enabled
   | .mqtt.options.host = $host
   | .mqtt.options.port = $port
   | .mqtt.options.username = $username
   | .mqtt.options.password = $password' \
    /addon_config/njspc/config.json > "${tmp}" && mv "${tmp}" /addon_config/njspc/config.json
bashio::log.info "MQTT config applied"

# Symlink config and runtime dirs into the app directory
ln -sf /addon_config/njspc/config.json /app/njspc/config.json
rm -rf /app/njspc/logs && ln -sf /data/njspc/logs /app/njspc/logs
rm -rf /app/njspc/backups && ln -sf /data/njspc/backups /app/njspc/backups

# ---------------------------------------------------------------------------
# dashPanel: config stored in /addon_config/dashpanel/ (visible in HA file editor)
# ---------------------------------------------------------------------------
if [ -f /app/dashpanel/defaultConfig.json ] && [ ! -f /addon_config/dashpanel/config.json ]; then
    bashio::log.info "Creating default dashPanel config in /addon_config/dashpanel/config.json"
    cp /app/dashpanel/defaultConfig.json /addon_config/dashpanel/config.json
fi

if [ -f /addon_config/dashpanel/config.json ]; then
    # Enforce correct controller connection settings on every start.
    # The controller hostname is the add-on's Docker hostname (e.g. 71a43e53-pool-controller),
    # which is unique per HA installation — read dynamically via $(hostname).
    # useProxy=true routes the connection through the dashPanel server rather than
    # the browser, which is required behind HA ingress.
    ADDON_HOSTNAME=$(hostname)
    bashio::log.info "Setting dashPanel controller host to ${ADDON_HOSTNAME}:4200"
    tmp=$(mktemp)
    jq --arg host "${ADDON_HOSTNAME}" \
        '.web.services.useProxy = true
       | .web.services.protocol = "http://"
       | .web.services.ip = $host
       | .web.services.port = 4200' \
        /addon_config/dashpanel/config.json > "${tmp}" && mv "${tmp}" /addon_config/dashpanel/config.json
    ln -sf /addon_config/dashpanel/config.json /app/dashpanel/config.json
fi

rm -rf /app/dashpanel/logs && ln -sf /data/dashpanel/logs /app/dashpanel/logs

# dashPanel looks for outQueues under its data/ subdirectory
mkdir -p /app/dashpanel/data
ln -sf /data/dashpanel/outQueues /app/dashpanel/data/outQueues

bashio::log.info "Initialisation complete."
