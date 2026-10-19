#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_DIR="$HOME/.hermes"
OMLX_DIR="$HOME/.omlx"

# ==============================================================================
# 1. Wczytanie zmiennych środowiskowych z pliku .env
# ==============================================================================
ENV_FILE="$DIR/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
elif [ -f "$HERMES_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$HERMES_DIR/.env"
    set +a
fi

OMLX_IP="${OMLX_IP:-100.123.37.101}"
OMLX_PORT="${OMLX_PORT:-8000}"
OMLX_API_KEY="${OMLX_API_KEY:-sk-omlx-0Thr9X0jHr1U2T2ReS17j6Vi}"

# ==============================================================================
# 2. Parsowanie argumentów wywołania
# ==============================================================================
VARIANT=""
MODE_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        1) VARIANT="1" ;;
        2) VARIANT="2" ;;
        --remote) MODE_OVERRIDE="remote" ;;
        --local) MODE_OVERRIDE="local" ;;
        -h|--help)
            echo "Uzycie: ./switch-variant.sh [1|2] [--local|--remote]"
            echo ""
            echo "Warianty:"
            echo "  1 - Wariant 1: Dynamiczny kompresor sesji (zero-swap, kompresor = model sesji)"
            echo "  2 - Wariant 2: Dedykowany kompresor Qwen 27B (przypiety obok modelu glownego)"
            echo ""
            echo "Opcje hosta oMLX:"
            echo "  --local   Wymuszenie polaczenia lokalnego (127.0.0.1:8000)"
            echo "  --remote  Wymuszenie polaczenia zdalnego z adresem z pliku .env (domyslnie 100.123.37.101)"
            echo "            (Gdy oMLX nie jest zainstalowany lokalnie, tryb --remote wlacza sie automatycznie)"
            exit 0
            ;;
        *)
            echo "❌ Nieznany parametr: $arg"
            echo "Uzycie: ./switch-variant.sh [1|2] [--local|--remote]"
            exit 1
            ;;
    esac
done

if [ -z "$VARIANT" ]; then
    echo "❌ Blad: Nie wybrano wariantu (1 lub 2)."
    echo "Uzycie: ./switch-variant.sh [1|2] [--local|--remote]"
    exit 1
fi

# ==============================================================================
# 3. Wykrywanie lokalnej instalacji oMLX
# ==============================================================================
is_omlx_installed() {
    if command -v omlx >/dev/null 2>&1; then
        return 0
    fi
    if [ -d "/Applications/oMLX.app" ]; then
        return 0
    fi
    if [ -x "$HOME/.omlx/bin/omlx" ]; then
        return 0
    fi
    return 1
}

if [ "$MODE_OVERRIDE" == "remote" ] || [ "${OMLX_MODE}" == "remote" ] || [ "${FORCE_OMLX_REMOTE:-0}" == "1" ]; then
    IS_LOCAL=0
elif [ "$MODE_OVERRIDE" == "local" ] || [ "${OMLX_MODE}" == "local" ]; then
    IS_LOCAL=1
elif is_omlx_installed; then
    IS_LOCAL=1
else
    IS_LOCAL=0
fi

# ==============================================================================
# 4. Aplikacja konfiguracji wybranego wariantu
# ==============================================================================
if [ "$VARIANT" == "1" ]; then
    echo "============================================================"
    echo "  Przelaczanie na WARIANT 1 (Dynamiczny Kompresor Sesji)  "
    echo "  - Glowny model: Qwen3.5-122B-A10B-MLX-9bit (256k)       "
    echo "  - Kompresor:    Dynamiczny (zawsze model aktywny w sesji)"
    echo "  - Watchdog:     Aktywny (1 model w RAM)                 "
    echo "============================================================"
    SRC_CONFIG="$DIR/config.variant1-single-model.yaml"
    SRC_SETTINGS="$DIR/model_settings.variant1-single-model.json"
elif [ "$VARIANT" == "2" ]; then
    echo "============================================================"
    echo "  Przelaczanie na WARIANT 2 (Dual-Model / Dedykowany 27B)  "
    echo "  - Glowny model: Qwen3.5-122B-A10B-MLX-9bit (256k)       "
    echo "  - Kompresor:    Qwen3.8-27B-Uncensored-MLX-SPLASH (256k, 15GB, Splash)"
    echo "  - Watchdog:     Qwen 27B Splash przypiety (is_pinned: true)"
    echo "============================================================"
    SRC_CONFIG="$DIR/config.variant2-dual-model.yaml"
    SRC_SETTINGS="$DIR/model_settings.variant2-dual-model.json"
fi

cp "$SRC_SETTINGS" "$DIR/model_settings.json"

mkdir -p "$HERMES_DIR"

if [ "$IS_LOCAL" -eq 1 ]; then
    echo "🖥️  Host oMLX: LOKALNY (127.0.0.1:8000)"
    cp "$SRC_CONFIG" "$DIR/config.yaml"
    cp "$DIR/config.yaml" "$HERMES_DIR/config.yaml"

    mkdir -p "$OMLX_DIR"
    cp "$DIR/model_settings.json" "$OMLX_DIR/model_settings.json"
    cp "$DIR/model_profiles.json" "$OMLX_DIR/model_profiles.json"
    cp "$DIR/settings.json" "$OMLX_DIR/settings.json"

    echo "✅ Wariant $VARIANT zostal aktywowany w trybie LOKALNYM (127.0.0.1:8000)!"
else
    TARGET_BASE_URL="http://${OMLX_IP}:${OMLX_PORT}/v1"
    echo "🌐  Host oMLX: ZDALNY (${TARGET_BASE_URL})"
    echo "    (zrodlo IP: plik .env; prywatny serwer wlasciciela repozytorium lub wlasny host)"

    # Podmiana adresu 127.0.0.1 na zdalny IP z pliku .env
    sed "s|http://127.0.0.1:8000/v1|${TARGET_BASE_URL}|g" "$SRC_CONFIG" > "$DIR/config.yaml"
    cp "$DIR/config.yaml" "$HERMES_DIR/config.yaml"

    # Zapewnienie klucza OMLX_API_KEY w ~/.hermes/.env
    if [ -n "$OMLX_API_KEY" ]; then
        if [ ! -f "$HERMES_DIR/.env" ]; then
            echo "OMLX_API_KEY=${OMLX_API_KEY}" > "$HERMES_DIR/.env"
        elif ! grep -q "^OMLX_API_KEY=" "$HERMES_DIR/.env"; then
            echo "OMLX_API_KEY=${OMLX_API_KEY}" >> "$HERMES_DIR/.env"
        fi
    fi

    echo "ℹ️  Pominieto konfiguracje lokalnego ~/.omlx/ (serwer oMLX dziala zdalnie pod ${OMLX_IP})."
    echo "✅ Wariant $VARIANT zostal aktywowany w trybie ZDALNYM dla Hermesa (${TARGET_BASE_URL})!"
fi
