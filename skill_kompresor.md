# Architektura Kompresji Kontekstu: Dynamiczny Model Sesji (Zero-Swap)

**Data:** 31 sierpnia 2026  
**Repozytorium:** `omlx_hermes_setup` (branch: `skill_kompresor`)

---

## 🎯 Cel i Założenia

Hermes Agent do podsumowywania wcześniejszej rozmowy (Context Compression / Auto-Compaction) korzysta z modułu `auxiliary.compression`.

W środowisku z restrykcyjnym zarządzaniem pamięcią RAM (1 model w RAM) kluczowe jest wyeliminowanie **Cold Swapu** – sytuacji, w której kompresja kontekstu wymusza załadowanie innego modelu z dysku SSD, wyładowując model aktywny.

---

## 🧠 Rozwiązanie: Natywna Dynamika Hermesa (`provider: auto`, `model: ""`)

Zamiast zewnętrznych skryptów cyklicznie forsujących nazwy modeli, Hermes posiada wbudowany łańcuch rozwiązywania modeli pomocniczych (`agent.auxiliary_client`):

1. Gdy `auxiliary.compression.provider: auto` oraz `model: ""`, Hermes automatycznie pobiera **aktualny model oraz providera aktywnej sesji** (`main_runtime`).
2. **Rezultat:**
   - Rozmowa z `Ornith-1.5-35B` ➔ kompresję wykonuje `Ornith-1.5-35B`.
   - Rozmowa z `Qwen3.5-122B` ➔ kompresję wykonuje `Qwen3.5-122B`.
   - Rozmowa z `Qwen3-Coder` ➔ kompresję wykonuje `Qwen3-Coder`.
3. **Zalety:**
   - **0s opóźnienia przełączania modeli (Zero-Swap).**
   - Prefill kompresji korzysta z istniejącej w RAM pamięci podręcznej KV.
   - Brak ryzyka kolizji z demonem `com.hermes.omlx-single-model-guard`.
   - Brak konieczności utrzymywania daemonów synchronizujących w tle.

---

## ⚙️ Aktywna Konfiguracja (`~/.hermes/config.yaml`)

```yaml
auxiliary:
  compression:
    provider: auto
    model: ''
    base_url: ''
    api_key: ''
    timeout: 360
```

---

## 🧪 Weryfikacja Działania

Test dynamicznego resolvera w środowisku Hermesa:
```bash
/Users/wojcio/.hermes/hermes-agent/venv/bin/python -c '
import sys
sys.path.insert(0, "/Users/wojcio/.hermes/hermes-agent")
from agent.auxiliary_client import get_text_auxiliary_client

c, m = get_text_auxiliary_client("compression", main_runtime={"provider": "omlx", "model": "Ornith-1.5-35B-A3B-Abliterated-MLX-BF16", "base_url": "http://127.0.0.1:8000/v1"})
print("Dynamic session compressor:", m, "->", c.base_url)
'
# Wynik: Dynamic session compressor: Ornith-1.5-35B-A3B-Abliterated-MLX-BF16 -> http://127.0.0.1:8000/v1/
```
