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
# /share/pool-controller/ is mounted from the HA /share directory — accessible
# via the HA file editor. Used for config.json files users may want to edit.
# /data is private add-on storage — used for logs, backups, runtime data.
# ---------------------------------------------------------------------------
mkdir -p /share/pool-controller/njspc/data /share/pool-controller/dashpanel
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
# njspc: config stored in /share/pool-controller/njspc/ (visible in HA file editor)
# ---------------------------------------------------------------------------
# Migrate poolConfig.json from private /data/ to /share/ (one-time, v1.0.14 -> v1.0.15)
if [ -f /data/njspc/data/poolConfig.json ] && [ ! -f /share/pool-controller/njspc/data/poolConfig.json ]; then
    bashio::log.info "Migrating poolConfig.json to /share/pool-controller/njspc/data/"
    mv /data/njspc/data/poolConfig.json /share/pool-controller/njspc/data/poolConfig.json
fi

if [ ! -f /share/pool-controller/njspc/config.json ]; then
    bashio::log.info "Creating default njspc config in /share/pool-controller/njspc/config.json"
    cp /app/njspc/defaultConfig.json /share/pool-controller/njspc/config.json
fi

# Patch serial port into config (always, to catch UI config changes)
if [ -n "${SERIAL_PORT}" ]; then
    tmp=$(mktemp)
    jq --arg port "${SERIAL_PORT}" \
        '.controller.comms.rs485Port = $port' \
        /share/pool-controller/njspc/config.json > "${tmp}" && mv "${tmp}" /share/pool-controller/njspc/config.json
    bashio::log.info "Set njspc serial port to ${SERIAL_PORT}"
fi

# Patch log level into config
if [ -n "${LOG_LEVEL}" ]; then
    tmp=$(mktemp)
    jq --arg level "${LOG_LEVEL}" \
        'if (.log.app | type) == "string" then .log.app = {enabled: true, level: $level, captureForReplay: false, logToFile: false} else .log.app.level = $level end' \
        /share/pool-controller/njspc/config.json > "${tmp}" && mv "${tmp}" /share/pool-controller/njspc/config.json
    bashio::log.info "Set njspc log level to ${LOG_LEVEL}"
fi

# Ensure the web server binds on all interfaces at port 4200
tmp=$(mktemp)
jq '.web.servers.http.ip = "0.0.0.0" | .web.servers.http.port = 4200' \
    /share/pool-controller/njspc/config.json > "${tmp}" && mv "${tmp}" /share/pool-controller/njspc/config.json

# ---------------------------------------------------------------------------
# MQTT configuration
# njspc reads interfaces from web.interfaces.<key> where the entry has
# type="mqtt", a fileName pointing to the bindings file, and options for
# the broker connection.  A top-level "mqtt" key is never read by njspc.
# ---------------------------------------------------------------------------
tmp=$(mktemp)
jq --argjson enabled "${MQTT_ENABLED}" \
    --arg host "${MQTT_HOST}" \
    --argjson port "${MQTT_PORT}" \
    --arg username "${MQTT_USERNAME}" \
    --arg password "${MQTT_PASSWORD}" \
    '.web.interfaces.mqtt.enabled = $enabled
   | .web.interfaces.mqtt.type = "mqtt"
   | .web.interfaces.mqtt.name = "MQTT"
   | .web.interfaces.mqtt.fileName = "mqtt.json"
   | .web.interfaces.mqtt.options.host = $host
   | .web.interfaces.mqtt.options.port = $port
   | .web.interfaces.mqtt.options.username = $username
   | .web.interfaces.mqtt.options.password = $password' \
    /share/pool-controller/njspc/config.json > "${tmp}" && mv "${tmp}" /share/pool-controller/njspc/config.json
bashio::log.info "MQTT config applied (web.interfaces.mqtt)"

# Symlink config and runtime dirs into the app directory
ln -sf /share/pool-controller/njspc/config.json /app/njspc/config.json
rm -rf /app/njspc/data && ln -sf /share/pool-controller/njspc/data /app/njspc/data
rm -rf /app/njspc/logs && ln -sf /data/njspc/logs /app/njspc/logs
rm -rf /app/njspc/backups && ln -sf /data/njspc/backups /app/njspc/backups

# ---------------------------------------------------------------------------
# dashPanel: config stored in /share/pool-controller/dashpanel/ (visible in HA file editor)
# ---------------------------------------------------------------------------
if [ -f /app/dashpanel/defaultConfig.json ] && [ ! -f /share/pool-controller/dashpanel/config.json ]; then
    bashio::log.info "Creating default dashPanel config in /share/pool-controller/dashpanel/config.json"
    cp /app/dashpanel/defaultConfig.json /share/pool-controller/dashpanel/config.json
fi

if [ -f /share/pool-controller/dashpanel/config.json ]; then
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
        /share/pool-controller/dashpanel/config.json > "${tmp}" && mv "${tmp}" /share/pool-controller/dashpanel/config.json
    ln -sf /share/pool-controller/dashpanel/config.json /app/dashpanel/config.json
fi

rm -rf /app/dashpanel/logs && ln -sf /data/dashpanel/logs /app/dashpanel/logs

# dashPanel looks for outQueues under its data/ subdirectory
mkdir -p /app/dashpanel/data
ln -sf /data/dashpanel/outQueues /app/dashpanel/data/outQueues

bashio::log.info "Initialisation complete."
