#!/bin/sh
# install-beszel-agent-opnsense.sh
# Usage: sh install-beszel-agent-opnsense.sh v0.12.3 "ssh-ed25519 AAAA..."

set -e

echo ""
echo "Beszel Agent Installer/Updater (Provided by SoFMeRight of PrecisionPlanIT)"
echo "You can find my other promoted projects:"
echo "  GitHub: https://github.com/sofmeright"
echo "  Docker Hub: https://hub.docker.com/u/prplanit"
echo ""

SERVICE_NAME="beszel_agent"
BIN_NAME="$SERVICE_NAME"
INSTALL_DIR="/usr/local/sbin"
RC_DIR="/usr/local/etc/rc.d"
TMP_DIR="$(mktemp -d -t beszel-agent-install-XXXXXXXX)"
KEY="$2"
VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [public_key]"
  exit 1
fi

echo "Installing Beszel Agent version: $VERSION"

ARCHIVE="beszel-agent_freebsd_amd64.tar.gz"
URL="https://github.com/henrygd/beszel/releases/download/$VERSION/$ARCHIVE"

echo "Downloading $URL ..."
fetch -o "$TMP_DIR/$ARCHIVE" "$URL"

echo "Extracting..."
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$TMP_DIR"

EXTRACTED_BIN="$TMP_DIR/beszel-agent"
if [ ! -f "$EXTRACTED_BIN" ]; then
  echo "Expected executable not found after extraction. Aborting."
  exit 1
fi

chmod +x "$EXTRACTED_BIN"

echo "Installing binary to $INSTALL_DIR/$BIN_NAME"
install -m 755 "$EXTRACTED_BIN" "$INSTALL_DIR/$BIN_NAME"

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
procname="/usr/local/sbin/${name}"

# Use daemon(8) to manage backgrounding and pidfile cleanly
command="/usr/sbin/daemon"
command_args="-p ${pidfile} -f /usr/bin/env KEY=${beszel_agent_key} ${procname} ${beszel_agent_flags}"

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

# Persist service enable + key using sysrc (safe editor for rc.conf)
echo "Enabling ${SERVICE_NAME} service..."
sysrc -f /etc/rc.conf "${SERVICE_NAME}_enable=YES" >/dev/null

if [ -n "$KEY" ]; then
  sysrc -f /etc/rc.conf "${SERVICE_NAME}_key=${KEY}" >/dev/null
else
  echo "Warning: No public key provided. Set it later with:"
  echo "  sysrc ${SERVICE_NAME}_key=\"ssh-ed25519 AAAA...\""
fi

echo "Starting ${SERVICE_NAME}..."
service "${SERVICE_NAME}" start || {
  echo "Failed to start ${SERVICE_NAME}. Check messages with:"
  echo "  service ${SERVICE_NAME} onestart"
  echo "  tail -n 200 /var/log/system.log"
  exit 1
}

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Beszel Agent ${VERSION} installed and started successfully!"
echo "Manage it with: service ${SERVICE_NAME} {start|stop|restart|status}"
