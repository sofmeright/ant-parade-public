!/bin/sh
# install-beszel-agent-opnsense.sh
# Usage examples:
#   sh install-beszel-agent-opnsense.sh -v v0.12.3 -k "ssh-ed25519 AAA... user@host"
#   sh install-beszel-agent-opnsense.sh -v v0.12.3 -k "ssh-ed25519 ..." -u "https://hub.example.com" -t "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# Notes: Works on live or installed OPNsense. Live boot won't persist after reboot unless you re-run.

set -e
umask 022

SERVICE_NAME="beszel_agent"
INSTALL_DIR="/usr/local/sbin"
RC_DIR="/usr/local/etc/rc.d"
LOG_FILE="/var/log/${SERVICE_NAME}.log"
PID_FILE="/var/run/${SERVICE_NAME}.pid"
ENV_FILE="/usr/local/etc/${SERVICE_NAME}.env"
TMP_DIR="$(mktemp -d -t beszel-agent-install-XXXXXXXX)"

cleanup() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

echo ""
echo "Beszel Agent Installer/Updater (Provided by SoFMeRight of PrecisionPlanIT)"
echo "You can find my other promoted projects:"
echo "  GitHub: https://github.com/sofmeright"
echo "  Docker Hub: https://hub.docker.com/u/prplanit"
echo ""

# -------- arg parse --------
VERSION=""
KEY=""
HUB_URL=""
TOKEN=""
AGENT_FLAGS=""
START_AFTER=1
ENABLE_SERVICE=1

usage() {
  cat <<USAGE
Usage: $0 -v <version> [-k "ssh-ed25519 AAAA..."] [-u HUB_URL] [-t TOKEN] [--flags "<agent flags>"] [--no-start] [--no-enable]
Examples:
  $0 -v v0.12.3 -k "ssh-ed25519 AAAA... user@host"
  $0 -v v0.12.3 -k "ssh-ed25519 ..." -u "https://hub.example.com" -t "uuid-token"
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -v|--version) VERSION="$2"; shift 2 ;;
    -k|--key) KEY="$2"; shift 2 ;;
    -u|--hub-url) HUB_URL="$2"; shift 2 ;;
    -t|--token) TOKEN="$2"; shift 2 ;;
    --flags) AGENT_FLAGS="$2"; shift 2 ;;
    --no-start) START_AFTER=0; shift ;;
    --no-enable) ENABLE_SERVICE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$VERSION" ]; then
  echo "Error: -v/--version is required."
  usage
  exit 1
fi

# If KEY wasn't passed, try reading any prior value (helps on upgrades)
if [ -z "$KEY" ]; then
  KEY="$(sysrc -n ${SERVICE_NAME}_key 2>/dev/null || true)"
fi

# -------- arch + download --------
mach="$(uname -m)"
case "$mach" in
  amd64|x86_64) ARCH="freebsd_amd64" ;;
  aarch64|arm64) ARCH="freebsd_arm64" ;;
  *) echo "Unsupported architecture: $mach"; exit 1 ;;
esac

TARBALL="beszel-agent_${ARCH}.tar.gz"
URL="https://github.com/henrygd/beszel/releases/download/${VERSION}/${TARBALL}"

echo "Installing Beszel Agent version: ${VERSION} (${ARCH})"
echo "Downloading ${URL} ..."
fetch -o "${TMP_DIR}/${TARBALL}" "${URL}"

echo "Extracting..."
tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"

EXTRACTED_BIN="${TMP_DIR}/beszel-agent"
if [ ! -f "${EXTRACTED_BIN}" ]; then
  echo "Expected executable not found after extraction. Aborting."
  exit 1
fi
chmod +x "${EXTRACTED_BIN}"

echo "Installing binary to ${INSTALL_DIR}/${SERVICE_NAME}"
install -m 755 "${EXTRACTED_BIN}" "${INSTALL_DIR}/${SERVICE_NAME}"

# -------- write env file (quotes preserved) --------
echo "Writing environment file at ${ENV_FILE}"
{
  echo "# ${SERVICE_NAME} environment (managed by installer)"
  [ -n "$KEY" ] && printf 'KEY=%s\n' "$(printf '%s' "$KEY" | sed 's/"/\\"/g; s/^/"/; s/$/"/')"
  [ -n "$HUB_URL" ] && printf 'HUB_URL=%s\n' "$(printf '%s' "$HUB_URL" | sed 's/"/\\"/g; s/^/"/; s/$/"/')"
  [ -n "$TOKEN" ] && printf 'TOKEN=%s\n' "$(printf '%s' "$TOKEN" | sed 's/"/\\"/g; s/^/"/; s/$/"/')"
  [ -n "$AGENT_FLAGS" ] && printf 'AGENT_FLAGS=%s\n' "$(printf '%s' "$AGENT_FLAGS" | sed 's/"/\\"/g; s/^/"/; s/$/"/')"
} > "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

# Touch log file so it exists with sane perms
: > "${LOG_FILE}" || true
chmod 644 "${LOG_FILE}" 2>/dev/null || true

# -------- rc.d script --------
mkdir -p "${RC_DIR}"
echo "Creating rc.d script at ${RC_DIR}/${SERVICE_NAME}"
cat > "${RC_DIR}/${SERVICE_NAME}" <<'EOF'
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
: ${beszel_agent_flags:=""}

pidfile="/var/run/${name}.pid"
command="/usr/local/sbin/${name}"
procname="${command}"
logfile="/var/log/${name}.log"
envfile="/usr/local/etc/${name}.env"

start_cmd="${name}_start"
stop_cmd="${name}_stop"
status_cmd="${name}_status"

beszel_agent_start() {
  # Load environment (KEY, HUB_URL, TOKEN, AGENT_FLAGS)
  if [ -f "${envfile}" ]; then
    # shellcheck disable=SC1090
    . "${envfile}"
  fi
  if [ -z "${KEY}" ] && [ -z "${beszel_agent_key}" ]; then
    echo "Error: KEY not set (env file) and beszel_agent_key not set in rc.conf"
    return 1
  fi
  # Prefer env file vars; fall back to rc.conf if present
  _KEY="${KEY:-${beszel_agent_key}}"
  _FLAGS="${AGENT_FLAGS:-${beszel_agent_flags}}"

  echo "Starting ${name}..."
  /usr/bin/nohup /usr/bin/env \
    KEY="${_KEY}" \
    ${HUB_URL:+HUB_URL="${HUB_URL}"} \
    ${TOKEN:+TOKEN="${TOKEN}"} \
    "${command}" ${_FLAGS} >> "${logfile}" 2>&1 &
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

chmod 755 "${RC_DIR}/${SERVICE_NAME}"

# Enable service if requested
if [ "${ENABLE_SERVICE}" -eq 1 ]; then
  echo "Enabling ${SERVICE_NAME} service..."
  sysrc -f /etc/rc.conf ${SERVICE_NAME}_enable=YES >/dev/null
fi

# Start if requested
if [ "${START_AFTER}" -eq 1 ]; then
  echo "Starting ${SERVICE_NAME}..."
  service "${SERVICE_NAME}" restart || service "${SERVICE_NAME}" start || true
fi

# Verify
if service "${SERVICE_NAME}" status >/dev/null 2>&1; then
  echo "Beszel Agent ${VERSION} installed and started successfully!"
  echo "Manage it with: service ${SERVICE_NAME} {start|stop|restart|status}"
  echo "Env file: ${ENV_FILE}"
else
  echo "Service did not report as running. Log tail:"
  tail -n 200 "${LOG_FILE}" 2>/dev/null || echo "No log at ${LOG_FILE} yet."
  echo "Manual start for diagnostics:"
  echo "  . ${ENV_FILE} && env KEY=\"${KEY}\" ${INSTALL_DIR}/${SERVICE_NAME} >>${LOG_FILE} 2>&1 &"
  exit 1
fi
