#!/bin/sh
# install-beszel-agent-pfsense.sh
# Usage: sh install-beszel-agent-pfsense.sh v0.12.3 "ssh-ed25519 AAAA..."

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
TMP_DIR=$(mktemp -d -t beszel-agent-install-XXXXXXXX)
KEY="$2"
VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [public_key]"
  exit 1
fi

echo "Installing Beszel Agent version: $VERSION"

TARBALL="beszel-agent_freebsd_amd64.tar.gz"
DOWNLOAD_URL="https://github.com/henrygd/beszel/releases/download/$VERSION/$TARBALL"

echo "Downloading $DOWNLOAD_URL..."
fetch -o "$TMP_DIR/$TARBALL" "$DOWNLOAD_URL"

echo "Extracting..."
tar -xzf "$TMP_DIR/$TARBALL" -C "$TMP_DIR"

# The extracted binary is named 'beszel-agent'
EXTRACTED_BIN="$TMP_DIR/beszel-agent"

if [ ! -f "$EXTRACTED_BIN" ]; then
  echo "Expected executable not found after extraction. Aborting."
  exit 1
fi

chmod +x "$EXTRACTED_BIN"

echo "Installing binary to $INSTALL_DIR/$SERVICE_NAME"
install -m 755 "$EXTRACTED_BIN" "$INSTALL_DIR/$SERVICE_NAME"

echo "Creating rc.d script at $RC_DIR/$SERVICE_NAME"
cat > "$RC_DIR/$SERVICE_NAME" <<EOF
#!/bin/sh
#
# PROVIDE: beszel_agent
# REQUIRE: NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="$SERVICE_NAME"
rcvar=beszel_agent_enable

command="$INSTALL_DIR/$SERVICE_NAME"
pidfile="/var/run/\${name}.pid"

load_rc_config \$name

: \${beszel_agent_enable:=no}
: \${beszel_agent_key:=}

start_cmd="beszel_agent_start"
stop_cmd="beszel_agent_stop"

beszel_agent_start() {
  echo "Starting \$name..."
  if [ -z "\$beszel_agent_key" ]; then
    echo "Error: beszel_agent_key not set in /etc/rc.conf"
    return 1
  fi
  env KEY="\$beszel_agent_key" "\$command" &
  echo \$! > "\$pidfile"
  return 0
}

beszel_agent_stop() {
  echo "Stopping \$name..."
  if [ -f "\$pidfile" ]; then
    kill \$(cat "\$pidfile") && rm -f "\$pidfile"
  else
    echo "No PID file found."
  fi
  return 0
}

run_rc_command "\$1"
EOF

chmod 755 "$RC_DIR/$SERVICE_NAME"

# Backup rc.conf if needed
if ! grep -q "^beszel_agent_enable=" /etc/rc.conf; then
  echo "Enabling beszel_agent service in /etc/rc.conf"
  echo "beszel_agent_enable=\"YES\"" >> /etc/rc.conf
fi

if [ -n "$KEY" ]; then
  if grep -q "^beszel_agent_key=" /etc/rc.conf; then
    sed -i '' "s|^beszel_agent_key=.*|beszel_agent_key=\"$KEY\"|" /etc/rc.conf
  else
    echo "Setting beszel_agent_key in /etc/rc.conf"
    echo "beszel_agent_key=\"$KEY\"" >> /etc/rc.conf
  fi
else
  echo "Warning: No public key provided. Please set 'beszel_agent_key' in /etc/rc.conf manually."
fi

echo "Starting $SERVICE_NAME service..."
service "$SERVICE_NAME" start

echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "Beszel Agent $VERSION installed and started successfully!"
