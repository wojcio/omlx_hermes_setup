#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_DIR="$HOME/.hermes"
OMLX_DIR="$HOME/.omlx"

# ---------------------------------------------------------------------------
# SYNC KOMPRESORA Z MODELEM W RAM
# ---------------------------------------------------------------------------
# Po włączeniu wariantu kompresor (auxiliary.compression.model) wskazuje na
# model hardcodowany przez config.variant*.yaml. Skrypt omlx-compression-sync.py
# ustawia go na model AKTYWNY w RAM (źródło prawdy z /api/status), dzięki czemu
# kompresja nie wymusza cold-reload drugiego modelu (zero-swap).
#
# OMLX nie jest dotykany — skrypt tylko koryguje config Hermesa
# (auxiliary.compression.model) przez `hermes config set`.
#
# Idempotentny: jeśli kompresor = model w RAM, nic nie pisze.
# Watchdog launchd (com.hermes.omlx-compression-sync.plist) powtarza to co 60s.
# ---------------------------------------------------------------------------
sync_compression() {
    SYNC_SCRIPT="$DIR/scripts/omlx-compression-sync.py"
    if [ -f "$SYNC_SCRIPT" ]; then
        echo "------------------------------------------------------------"
        echo "  Synchronizacja kompresora z modelem w RAM ..."
        python3 "$SYNC_SCRIPT" && \
            echo "  ✅ Kompresor = model aktywny w RAM" || \
            echo "  ⚠️ Kompresor niezsynchronizowany (omlx nieaktywny?)"
        echo "------------------------------------------------------------"
    else
        echo "  ⚠️ Brak $SYNC_SCRIPT — pomijam synchronizację kompresora"
    fi
}

if [ "$1" == "1" ]; then
    echo "============================================================"
    echo "  Przelaczanie na WARIANT 1 (Pojednczy model / Zero-Swap)  "
    echo "  - Glowny model: Qwen3.5-122B-A10B-MLX-9bit (256k)       "
    echo "  - Kompresor:    Qwen3.5-122B-A10B-MLX-9bit (256k)       "
    echo "  - Watchdog:     Aktywny (1 model w RAM)                 "
    echo "============================================================"
    cp "$DIR/config.variant1-single-model.yaml" "$DIR/config.yaml"
    cp "$DIR/model_settings.variant1-single-model.json" "$DIR/model_settings.json"

    # Kopiowanie do sciezek roboczych aplikacji
    mkdir -p "$HERMES_DIR" "$OMLX_DIR"
    cp "$DIR/config.yaml" "$HERMES_DIR/config.yaml"
    cp "$DIR/model_settings.json" "$OMLX_DIR/model_settings.json"
    cp "$DIR/model_profiles.json" "$OMLX_DIR/model_profiles.json"
    cp "$DIR/settings.json" "$OMLX_DIR/settings.json"

    sync_compression

    echo "✅ Wariant 1 zostal aktywowany i zsynchronizowany!"

elif [ "$1" == "2" ]; then
    echo "============================================================"
    echo "  Przelaczanie na WARIANT 2 (Dual-Model / Szybki Kompresor) "
    echo "  - Glowny model: Qwen3.5-122B-A10B-MLX-9bit (256k)       "
    echo "  - Kompresor:    Qwen3.8-27B-Uncensored-MLX (256k, 15GB) "
    echo "  - Watchdog:     Qwen 27B przypiety (is_pinned: true)    "
    echo "============================================================"
    cp "$DIR/config.variant2-dual-model.yaml" "$DIR/config.yaml"
    cp "$DIR/model_settings.variant2-dual-model.json" "$DIR/model_settings.json"

    # Kopiowanie do sciezek roboczych aplikacji
    mkdir -p "$HERMES_DIR" "$OMLX_DIR"
    cp "$DIR/config.yaml" "$HERMES_DIR/config.yaml"
    cp "$DIR/model_settings.json" "$OMLX_DIR/model_settings.json"
    cp "$DIR/model_profiles.json" "$OMLX_DIR/model_profiles.json"
    cp "$DIR/settings.json" "$OMLX_DIR/settings.json"

    sync_compression

    echo "✅ Wariant 2 zostal aktywowany i zsynchronizowany!"

else
    echo "Uzycie: ./switch-variant.sh [1|2]"
    echo "  1 - Wariant 1: Qwen3.5-122B jako glowny i kompresor (rekomendowany, zero-swap)"
    echo "  2 - Wariant 2: Qwen3.5-122B jako glowny + Qwen3.8-27B (przypiety) jako kompresor"
    echo ""
    echo "Po switchu skrypt automatycznie zsynchronizuje kompresora z modelem w RAM"
    echo "(./scripts/omlx-compression-sync.py)."
    exit 1
fi
