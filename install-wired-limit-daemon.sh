#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHD_SRC="$DIR/launchd"

DAEMON_LABEL="com.wojcio.iogpu-wired-limit"
AGENT_LABEL="com.wojcio.iogpu-wired-limit-notify"

DAEMON_DST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

AGENT_DST="${TARGET_HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"
NOTIFY_SCRIPT_DST="${TARGET_HOME}/.omlx/bin/iogpu-wired-limit-notify.sh"

echo "============================================================"
echo "  Instalacja demona iogpu.wired_limit_mb=186777 + powiadomien"
echo "  Użytkownik GUI: ${TARGET_USER} (UID=${TARGET_UID})"
echo "============================================================"

# 1. Instalacja LaunchAgent (skrypt powiadomień + agent GUI)
mkdir -p "${TARGET_HOME}/.omlx/bin" "${TARGET_HOME}/.omlx/logs" "${TARGET_HOME}/Library/LaunchAgents"
cp "${LAUNCHD_SRC}/iogpu-wired-limit-notify.sh" "${NOTIFY_SCRIPT_DST}"
chmod 755 "${NOTIFY_SCRIPT_DST}"

sed "s|__TARGET_HOME__|${TARGET_HOME}|g" "${LAUNCHD_SRC}/${AGENT_LABEL}.plist" > "${AGENT_DST}"
chmod 644 "${AGENT_DST}"

if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    chown -R "${TARGET_USER}:staff" "${TARGET_HOME}/.omlx/bin" "${TARGET_HOME}/.omlx/logs" "${AGENT_DST}"
fi

echo "✅ Zainstalowano LaunchAgent: ${AGENT_DST}"

# 2. Instalacja LaunchDaemon (wymaga sudo/root)
if [ "$(id -u)" -ne 0 ]; then
    echo ""
    echo "ℹ️  Aby zainstalować systemowy LaunchDaemon w ${DAEMON_DST}, uruchom:"
    echo "    sudo \"$0\""
    echo ""
    exit 0
fi

cp "${LAUNCHD_SRC}/${DAEMON_LABEL}.plist" "${DAEMON_DST}"
chown root:wheel "${DAEMON_DST}"
chmod 644 "${DAEMON_DST}"

# Przeładowanie LaunchDaemon w domenie systemowej
launchctl bootout "system/${DAEMON_LABEL}" 2>/dev/null || true
launchctl bootstrap system "${DAEMON_DST}"
launchctl kickstart -k "system/${DAEMON_LABEL}" 2>/dev/null || true
echo "✅ Zainstalowano i uruchomiono LaunchDaemon: ${DAEMON_DST}"

# Przeładowanie LaunchAgent w sesji Aqua zalogowanego użytkownika (jeśli zalogowany)
if launchctl print "gui/${TARGET_UID}" >/dev/null 2>&1; then
    launchctl bootout "gui/${TARGET_UID}/${AGENT_LABEL}" 2>/dev/null || true
    launchctl bootstrap "gui/${TARGET_UID}" "${AGENT_DST}"
    launchctl kickstart -k "gui/${TARGET_UID}/${AGENT_LABEL}" 2>/dev/null || true
    echo "✅ Przeładowano LaunchAgent i wyświetlono powiadomienie dla ${TARGET_USER}."
else
    echo "ℹ️  Sesja GUI dla ${TARGET_USER} nieaktywna — powiadomienie pojawi się po zalogowaniu."
fi

echo ""
echo "Aktualna wartość w kernelu: $(/usr/sbin/sysctl -n iogpu.wired_limit_mb) MB"
