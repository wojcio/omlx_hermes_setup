# Architektura Kompresji Kontekstu: Dynamiczny Zero-Swap & Dual-Model Resident

**Stan na:** Listopad 2026  
**Platforma:** Mac Studio M2 Ultra (192 GB RAM, Metal limit **186 GB**, oMLX **0.8.3**, Splash **1.7.0-m1.1**)  
**Repozytorium:** `omlx_hermes_setup`

---

## 🎯 Cel i Założenia Architektury

Hermes Agent do podsumowywania wcześniejszej rozmowy (Context Compression / Auto-Compaction) korzysta z modułu `auxiliary.compression`.

W środowisku z restrykcyjnym zarządzaniem pamięcią RAM (reguła pojedynczego modelu w RAM kontrolowana przez demona `com.hermes.omlx-single-model-guard` co 180s) oraz sufitami alokacji Metal (**186 GB RAM**) kluczowe jest wyeliminowanie **Cold Swapu** – sytuacji, w której kompresja kontekstu wymusza załadowanie innego ciężkiego modelu z dysku SSD, wyładowując model aktywny i marnując czas na prefill.

Repozytorium udostępnia dwa warianty kompresji zarządzane przez `./switch-variant.sh [1|2]`:

---

## 🏆 Wariant 1: Dynamiczny Model Sesji (`Zero-Swap Dynamic`, Domyślny)

Wbudowany łańcuch rozwiązywania modeli pomocniczych (`agent.auxiliary_client`) w Hermesie realizuje pełną dynamikę sesji:

1. Gdy `auxiliary.compression.provider: auto` oraz `model: ""`, Hermes automatycznie pobiera **aktualny model oraz providera aktywnej sesji** (`main_runtime`).
2. **Przykłady działania w locie:**
   - Rozmowa z `Qwen3.8-Flash-Next-oQ5e-mtp` ➔ kompresję wykonuje `Qwen3.8-Flash-Next-oQ5e-mtp`.
   - Rozmowa z `GLM-5.3-Flash-oQ4e-mtp` (320B MoE, 173.9 GB) ➔ kompresję wykonuje ten sam model bez wyładowywania go z RAM!
   - Rozmowa z `Inkling-Small-mxfp4` (130.6 GB) ➔ kompresję wykonuje `Inkling-Small-mxfp4`.
   - Rozmowa z `Inkling-2-Mini-oQ4e-mtp` (15.7 GB) ➔ kompresję wykonuje `Inkling-2-Mini-oQ4e-mtp`.
   - Rozmowa z `Hy4-flash-oQ4h-mtp` (123.4 GB) ➔ kompresję wykonuje `Hy4-flash-oQ4h-mtp`.
   - Rozmowa z `flint-oQ8e` ➔ kompresję wykonuje `flint-oQ8e`.
3. **Zalety:**
   - **0s opóźnienia przełączania modeli (Zero-Swap)** dla wszystkich 27 modeli w Hermesie.
   - Prefill kompresji korzysta z istniejącej w RAM pamięci podręcznej KV aktywnej sesji.
   - 100% zgodność z demonem `com.hermes.omlx-single-model-guard` i sufitem 186 GB Metal.

### Aktywna Konfiguracja Wariantu 1 (`config.variant1-single-model.yaml`):

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

## ⚡ Wariant 2: Dedykowany Szybki Kompresor 27B (`Dual-Model Resident`)

W Wariancie 2 model sesji współpracuje z małym, ultrabłyskawicznym modelem dedykowanym wyłącznie do kompresji:

* **Model główny:** `Qwen3.8-Flash-Next-oQ5e-mtp` (lub inny model o rozmiarze do ~130 GB).
* **Kompresor:** `Qwen3.8-27B-Uncensored-MLX-SPLASH` (~15.2 GB w RAM, `is_pinned: true`, silnik **Splash 1.7.0-m1.1**).
* **Akceleracja Splash:** Podział GPU/ANE (`share 0.26`), zarządca `One memory ledger`, `Idle KV` oraz spekulatywny draft DFlash2 (**72.9 tok/s** decode, TTFT 0.31s).
* **Ochrona Watchdoga:** Flaga `"is_pinned": true` w `model_settings.json` chroni model Splash przed wyładowaniem obok modelu głównego.

### Konfiguracja Wariantu 2 (`config.variant2-dual-model.yaml`):

```yaml
auxiliary:
  compression:
    provider: omlx
    model: 'Qwen3.8-27B-Uncensored-MLX-SPLASH'
    base_url: 'http://127.0.0.1:8000/v1'
    timeout: 300
```

---

## 🔄 Przełączanie wariantów

```bash
# Wariant 1 (Domyślny, Zero-Swap dla wszystkich modeli):
./switch-variant.sh 1

# Wariant 2 (Dedykowany szybki kompresor 27B Splash):
./switch-variant.sh 2
```
