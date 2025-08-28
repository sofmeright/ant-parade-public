#!/bin/sh
# install-beszel-agent-pfsense.sh
# Usage (compat):
#   sh install-beszel-agent-pfsense.sh v0.12.3 "ssh-ed25519 AAAA... user@host"
#
# Optional rc.conf vars (set later with sysrc if desired):
#   beszel_agent_hub_url="https://hub.example.com"
#   beszel_agent_token="00000000-0000-0000-0000-000000000000"
#   beszel_agent_port="45876"     # default is 45876
#   beszel_agent_flags="..."      # extra agent flags
#
set -e
umask 022

echo ""
echo "Beszel Agent Installer/Updater (Provided by SoFMeRight of PrecisionPlanIT)"
echo "You can find my other promoted projects:"
echo "  GitHub: https://github.com/sofmeright"
echo "  Docker Hub: https://hub.docker.com/u/prplanit"
echo ""

SERVICE_NAME="beszel_agent"
INSTALL_DIR="/usr/local/sbin"
RC_DIR="/usr/local/etc/rc.d"
LOG_FILE="/var/log/${SERVICE_NAME}.log"
PID_FILE="/var/run/${SERVICE_NAME}.pid"
TMP_DIR="$(mktemp -d -t beszel-agent-install-XXXXXXXX)"

KEY="${2:-}"
VERSION="${1:-}"

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [public_key]"
  exit 1
fi

# Arch detect (amd64/arm64)
mach="$(uname -m)"
case "$mach" in
  amd64|x86_64) ARCH="freebsd_amd64" ;;
  aarch64|arm64) ARCH="freebsd_arm64" ;;
  *) echo "Unsupported architecture: $mach"; exit 1 ;;
esac

echo "Installing Beszel Agent version: $VERSION ($ARCH)"

TARBALL="beszel-agent_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/henrygd/beszel/releases/download/$VERSION/$TARBALL"

echo "Downloading $DOWNLOAD_URL..."
fetch -o "$TMP_DIR/$TARBALL" "$DOWNLOAD_URL"

echo "Extracting..."
tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"

EXTRACTED_BIN="$TMP_DIR/beszel-agent"
if [ ! -f "$EXTRACTED_BIN" ]; then
  echo "Expected executable not found after extraction. Aborting."
  exit 1
fi
chmod +x "$EXTRACTED_BIN"

echo "Installing binary to $INSTALL_DIR/$SERVICE_NAME"
install -m 755 "$EXTRACTED_BIN" "$INSTALL_DIR/$SERVICE_NAME"

# rc.d script (detached with nohup, logs to $LOG_FILE, handles spaces in KEY)
mkdir -p "$RC_DIR"
echo "Creating rc.d script at $RC_DIR/$SERVICE_NAME"
cat > "$RC_DIR/$SERVICE_NAME" <<'EOF'
#!/bin/sh
#
# PROVIDE: beszel_agent
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="beszel_agent"
rcvar="${name}_enable"

load_rc_config "$name"

: ${beszel_agent_enable:="NO"}
: ${beszel_agent_key:=""}
: ${beszel_agent_flags:=""}
: ${beszel_agent_hub_url:=""}
: ${beszel_agent_token:=""}
: ${beszel_agent_port:=""}

pidfile="/var/run/${name}.pid"
command="/usr/local/sbin/${name}"
procname="${command}"
logfile="/var/log/${name}.log"

start_cmd="${name}_start"
stop_cmd="${name}_stop"
status_cmd="${name}_status"

beszel_agent_start() {
  if [ -z "${beszel_agent_key}" ]; then
    echo "Error: beszel_agent_key not set in /etc/rc.conf"
    return 1
  fi
  : > "${logfile}" 2>/dev/null || true
  chmod 644 "${logfile}" 2>/dev/null || true
  echo "Starting ${name}..."
  /usr/bin/nohup /usr/bin/env \
    KEY="${beszel_agent_key}" \
    ${beszel_agent_hub_url:+HUB_URL="${beszel_agent_hub_url}"} \
    ${beszel_agent_token:+TOKEN="${beszel_agent_token}"} \
    ${beszel_agent_port:+PORT="${beszel_agent_port}"} \
    "${command}" ${beszel_agent_flags} >> "${logfile}" 2>&1 &
  echo $! > "${pidfile}"
}

beszel_agent_stop() {
  echo "Stopping ${name}..."
  if [ -f "${pidfile}" ]; then
    kill "$(cat "${pidfile}")" && rm -f "${pidfile}"
  else
    echo "No PID file found."
  fi
}

beszel_agent_status() {
  if [ -f "${pidfile}" ] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    echo "${name} is running as pid $(cat "${pidfile}")"
    return 0
  fi
  echo "${name} is not running."
  return 1
}

run_rc_command "$1"
EOF

chmod 755 "$RC_DIR/$SERVICE_NAME"

# Enable + set key (use sysrc so spaces in KEY are preserved)
if ! sysrc -f /etc/rc.conf -n beszel_agent_enable >/dev/null 2>&1; then
  echo "Enabling beszel_agent service in /etc/rc.conf"
fi
sysrc -f /etc/rc.conf beszel_agent_enable=YES >/dev/null

if [ -n "$KEY" ]; then
  sysrc -f /etc/rc.conf beszel_agent_key="$KEY" >/dev/null
else
  echo "Warning: No public key provided. Set it with:"
  echo "  sysrc beszel_agent_key=\"ssh-ed25519 AAAA... your@host\""
fi

echo "Starting $SERVICE_NAME service..."
service "$SERVICE_NAME" restart || service "$SERVICE_NAME" start || true

# Verify + show logs if not running
if service "$SERVICE_NAME" status >/dev/null 2>&1; then
  echo "Beszel Agent $VERSION installed and started successfully!"
  echo "Manage it with: service $SERVICE_NAME {start|stop|restart|status}"
  echo "Logs: $LOG_FILE"
else
  echo "Service did not report as running. Recent log:"
  tail -n 200 "$LOG_FILE" 2>/dev/null || echo "No log at $LOG_FILE yet."
  exit 1
fi
