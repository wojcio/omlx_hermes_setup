#!/usr/bin/env bash
# ==============================================================================
# move_from_SSD_to_HDD.sh
#
# Narzędzie audytu użycia modeli LLM (oMLX / Hermes / statystyki dyskowe) oraz
# bezpiecznej migracji nieużywanych modeli z szybkiego SSD do zewnętrznego HDD
# (/Volumes/Seagate_Expansion_Drive/LLM) z automatycznym tworzeniem dowiązań
# symbolicznych, dodawaniem znacznika [HDD] i odświeżaniem konfiguracji oMLX.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_EXEC="python3"

if ! command -v "$PYTHON_EXEC" >/dev/null 2>&1; then
    echo "BŁĄD: Nie znaleziono interpretera python3 w PATH." >&2
    exit 1
fi

exec "$PYTHON_EXEC" "$SCRIPT_DIR/move_from_SSD_to_HDD.py" "$@"
