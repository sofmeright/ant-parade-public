#!/bin/sh
# install-beszel-agent-opnsense.sh
# Usage: sh install-beszel-agent-opnsense.sh v0.12.3 "ssh-ed25519 AAAA... your@host"
# Works on OPNsense live or installed. Live boots won't persist across reboot.

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

TARBALL="beszel-agent_freebsd_amd64.tar.gz"
URL="https://github.com/henrygd/beszel/releases/download/$VERSION/$TARBALL"

echo "Installing Beszel Agent version: $VERSION"
echo "Downloading $URL ..."
fetch -o "$TMP_DIR/$TARBALL" "$URL"

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

# Ensure rc.d dir exists
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

pidfile="/var/run/${name}.pid"
command="/usr/local/sbin/${name}"
procname="${command}"
logfile="/var/log/${name}.log"

start_cmd="${name}_start"
stop_cmd="${name}_stop"
status_cmd="${name}_status"

beszel_agent_start() {
  if [ -z "${beszel_agent_key}" ]; then
    echo "Error: beszel_agent_key not set in rc.conf"
    return 1
  fi
  echo "Starting ${name}..."
  # Run in background, persist PID, and log stdout/stderr
  /usr/bin/nohup /usr/bin/env KEY="${beszel_agent_key}" "${command}" ${beszel_agent_flags} \
    >> "${logfile}" 2>&1 &
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

echo "Enabling ${SERVICE_NAME} service..."
sysrc -f /etc/rc.conf ${SERVICE_NAME}_enable=YES >/dev/null

if [ -n "$KEY" ]; then
  # CRITICAL: quote the value so spaces in the key are preserved in rc.conf
  sysrc -f /etc/rc.conf ${SERVICE_NAME}_key="$KEY" >/dev/null
else
  echo "Warning: No public key provided. Set it later with:"
  echo "  sysrc ${SERVICE_NAME}_key=\"ssh-ed25519 AAAA... your@host\""
fi

# Touch log file so it exists with sane perms
: > "$LOG_FILE" || true
chmod 644 "$LOG_FILE" 2>/dev/null || true

echo "Starting ${SERVICE_NAME}..."
service "${SERVICE_NAME}" start || true

# Verify running state via our pidfile-based status
if service "${SERVICE_NAME}" status >/dev/null 2>&1; then
  echo "Beszel Agent ${VERSION} installed and started successfully!"
  echo "Manage it with: service ${SERVICE_NAME} {start|stop|restart|status}"
else
  echo "Service did not report as running. Recent log (if any):"
  tail -n 200 "$LOG_FILE" 2>/dev/null || echo "No log at $LOG_FILE yet."
  echo "Manual start for diagnostics:"
  echo "  env KEY=\"<your-key>\" ${INSTALL_DIR}/${SERVICE_NAME} >${LOG_FILE} 2>&1 &"
  exit 1
fi
