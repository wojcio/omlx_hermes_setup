#!/usr/bin/env bash
set -euo pipefail

# Oczekiwany limit iogpu.wired_limit_mb (domyślnie 186777 MB = 95% ze 192 GiB RAM)
TARGET_MB="${1:-186777}"
LOG_DIR="${HOME}/.omlx/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/wired-limit-notify.log"

CURRENT_MB="0"
for _ in $(seq 1 10); do
    CURRENT_MB="$(/usr/sbin/sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo 0)"
    if [ "${CURRENT_MB}" -ge "${TARGET_MB}" ] 2>/dev/null; then
        break
    fi
    sleep 1
done

CURRENT_GIB="$(awk "BEGIN {printf \"%.1f\", ${CURRENT_MB} / 1024}")"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

if [ "${CURRENT_MB}" -ge "${TARGET_MB}" ] 2>/dev/null; then
    MSG="Limit iogpu.wired_limit_mb podniesiony do ${CURRENT_MB} MB (${CURRENT_GIB} GiB)"
    SUBTITLE="Limit pamięci Metal GPU aktywny"
    echo "${TIMESTAMP} [OK] ${MSG}" >> "${LOG_FILE}"
else
    MSG="Aktualny limit: ${CURRENT_MB} MB (oczekiwano ${TARGET_MB} MB). Sprawdź LaunchDaemon."
    SUBTITLE="Uwaga: limit Metal GPU niepodniesiony"
    echo "${TIMESTAMP} [WARN] ${MSG}" >> "${LOG_FILE}"
fi

/usr/bin/osascript -e "display notification \"${MSG}\" with title \"oMLX • Metal GPU RAM\" subtitle \"${SUBTITLE}\""
