#!/bin/sh
# install-beszel-agent-opnsense.sh
# Usage: sh install-beszel-agent-opnsense.sh v0.12.3 "ssh-ed25519 AAAA... your@host"
# Works on OPNsense live or installed. Live boots won't persist across reboot.

set -e

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
agent_bin="/usr/local/sbin/${name}"
logfile="/var/log/${name}.log"

# Track the daemon(8) wrapper; quote KEY to preserve spaces in the public key
command="/usr/sbin/daemon"
procname="/usr/sbin/daemon"
command_args="-p ${pidfile} -o ${logfile} -- /usr/bin/env KEY=\"${beszel_agent_key}\" ${agent_bin} ${beszel_agent_flags}"

start_precmd="${name}_precmd"

beszel_agent_precmd() {
  if [ -z "${beszel_agent_key}" ]; then
    echo "Error: beszel_agent_key not set in rc.conf"
    return 1
  fi
}

run_rc_command "$1"
EOF

chmod 755 "$RC_DIR/$SERVICE_NAME"

echo "Enabling ${SERVICE_NAME} service..."
sysrc -f /etc/rc.conf "${SERVICE_NAME}_enable=YES" >/dev/null

if [ -n "$KEY" ]; then
  # Quote whole var=value so spaces are preserved in rc.conf
  sysrc -f /etc/rc.conf "${SERVICE_NAME}_key=${KEY}" >/dev/null
else
  echo "Warning: No public key provided. Set it later with:"
  echo "  sysrc ${SERVICE_NAME}_key=\"ssh-ed25519 AAAA...\""
fi

echo "Starting ${SERVICE_NAME}..."
service "${SERVICE_NAME}" start || true

# Verify running state (daemon writes pidfile we track)
if service "${SERVICE_NAME}" status >/dev/null 2>&1; then
  echo "Beszel Agent ${VERSION} installed and started successfully!"
  echo "Manage it with: service ${SERVICE_NAME} {start|stop|restart|status}"
else
  echo "Service did not report as running. Showing recent log (if any):"
  tail -n 200 "$LOG_FILE" 2>/dev/null || echo "No log at $LOG_FILE yet."
  echo "Manual start for diagnostics:"
  echo "  env KEY=\"<your-key>\" ${INSTALL_DIR}/${SERVICE_NAME} >${LOG_FILE} 2>&1 &"
  exit 1
fi
