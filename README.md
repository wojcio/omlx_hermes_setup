# oMLX & Hermes Setup

Zestaw zoptymalizowanych konfiguracji dla **oMLX 0.8.3** (Apple **MLX 0.32.4**, `mlx-lm 0.32.3.dev8`, `mlx-vlm 0.7.11`, sufit pamięci **186 GB RAM**) oraz **Hermes Agent** z precyzyjnie dobranymi oknami kontekstu (`max_context` do **512k/1M**), limitami wyjściowymi (`max_tokens`), akceleracją sprzętową (**Splash M1 1.7.0-m1.1**, **Lightning MTP**, **DSpark**, **DFlash2**, **oQh Rotated Codes**, **Fused MoE & GDN/KDA**, **Affine `hc_fused`**, **FP16 Activation Recast**) oraz parametrami próbkowania (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty`) dla **27 modeli w Hermesie (29 w oMLX)** na Apple Silicon (M2 Ultra / MLX).

---

## 📖 Pełna dokumentacja i Przewodnik Użytkownika

Szczegółowy opis wszystkich **27 modeli w Hermesie (29 w oMLX)** — w tym nowych rodzin:
- **`Inkling-Small-mxfp4`** (Thinking Machines Inkling 1 Small MoE VLM, 130.6 GB, 256 eksp. top-6, **40.2 tok/s**, PASS `124.4s`),
- **`Inkling-2-Mini-oQ4e-mtp`** (Inkling 2 Loop MoE VLM, 128 eksp. top-8, pętla `3×`, **15.7 GB RAM**, bundled DSpark, **41.2 tok/s** w `0.8.3`, PASS `112.4s`),
- **`Hy4-flash-oQ4h-mtp`** (Tencent Hy4-flash MoE VLM, 512 eksp. top-16, format `oQh`, 123.4 GB, Lightning MTP **84.9%**, **35.7 tok/s**, PASS `181.7s`, jakość 10/10 po fixach `#5534`/`#5476`),
- **`Qwen3.8-Flash-Next-oQ5e-mtp`** (~119.9 GB, **67.5–97 tok/s**) oraz **`Qwen3.8-Flash-Next-oQ6e-mtp`** (6-bit, ~141.1 GB, **60.6–66.8 tok/s**) i **`Qwen3.8-Flash-Next-MTPLX-Optimized-Speed`** (**~73.5 tok/s**),
- **`GLM-5.3-Flash-oQ4e-mtp`** (320B MoE / 18B akt., 173.9 GB w 100% w RAM, TTFT **0.17s**, **25.5–32.8 tok/s**),
- **`gemma-4-12B-it-oQ8e-mtp`** (Any-to-Any VLM/Audio, 13.0 GB, **51.4–68.4 tok/s**) oraz **`gemma-4-31B-it-oQ6e-mtp`** (Dense 31B VLM, 26.3 GB, `gemma4_verify_kernel`, **32.4–34.0 tok/s**),
- **`Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed`** (2-bit Hadamard 27B VLM, tylko **8.23 GB RAM**, **31.4 tok/s**) oraz **`Nanbeige4.3-33B-MLX-6bit`** (Dense 33B, okno **512k tokenów**, **19.6 tok/s**),
- autonomicznego agenta kodującego **`flint-oQ8e`** (MoE 39.8B, 2.5B akt./tok, do **74.1 tok/s**), **`DeepSeek-V4-Flash-0731-MXFP4-MLX`**, **`Qwen3.8-27B-Coder390-...-MTP-DFlash2`**, **`Qwen3.8-27B-Uncensored-MLX-SPLASH`** (**Splash 1.7.0-m1.1**, **72.9 tok/s** na M1/M2) oraz modeli zarchiwizowanych na zewnętrznym dysku USB-C z oznaczeniem **`[HDD]`** (`MiniMax-M3-ConfigI-MLX`, `Qwen3.5-122B`, `Qwen3-Coder-Next`, `Qwen3-235B`, `Step-3.5-Flash`, `Qwen3.8-27B-FP16_huzar_v1` / `-SPLASH`) — znajdziesz w plikach:

👉 **[Przewodnik Użytkownika & Use Cases dla 7 Ról (HowTo_JakUzywac.md)](HowTo_JakUzywac.md)**  
👉 **[Konfiguracja Techniczna Modeli & Hugging Face (konfiguracja-modeli.md)](konfiguracja-modeli.md)**

---

## 🚀 Nowości i optymalizacje w oMLX 0.8.3 & Splash 1.7.0-m1.1

Konfiguracja jest w 100% zgodna z **oMLX `0.8.3`** (build `3879`, silnik **Apple MLX `0.32.4`**, `mlx-lm 0.32.3.dev8`, `mlx-vlm 0.7.11`, schemat `SETTINGS_VERSION = 3`) oraz silnikiem **Splash M1 `1.7.0-m1.1`** i automatycznie wykorzystuje najnowsze usprawnienia:
- **Nowy silnik Splash M1 1.7.0-m1.1 (`paperniuk/splash`):** Zawiera krytyczny hotfix `#75` w `/opt/homebrew/bin/splash-m1` (naprawa odpowiedzi na krótkich promptach 33–64 tokenów i po odtworzeniu prefix-cache), automatyczną kalibrację dwuchunkowego prefillu GPU+ANE (`#64`/`#66`), szybszy 4-bit MLX decode (`#69`/`#70`), podział ANE/GPU (`share 0.26`) oraz stabilne wsparcie MoE.
- **oMLX 0.8.3 & migracja schematu v3:** 88 pól per model, obsługa LoRA (`#5449`), fixy `#5534` (utrzymanie historii tur po cache hit) oraz `#5476` (brak wycieku tagów `<think>` do właściwej odpowiedzi), co podniosło jakość agentową `Hy4-flash-oQ4h-mtp` do oceny 10/10.
- **Akceleracja `activation_fp16_enabled: true` i `attn_fused` w Qwen3.8-Flash-Next (PR #4901, #4988, #5028):** Na procesorze M2 Ultra przełączenie liści `bfloat16 -> float16` (2 471 tensorów) odblokowuje natywne ścieżki FP16 i naprawia limit wątków grupy (`Thread group size 1024 > 896`) w nowym dwuprzebiegowym kernelu `omlx_qwen4_attn_sdpa2_gate`, podnosząc prędkość generowania `Qwen3.8-Flash-Next-oQ5e-mtp` w fazie czystego rozumowania z 39.6 do **62.56 tok/s** (+58%, TTFT 0.48s) i do **~97 tok/s** na kodzie.
- **Kernele M1/M2 Verify MMA dla warstw 6-bit i 8-bit (PR #4898, #4990, `b5c7793e`):** Wielowierszowe kernele dekodowania i weryfikacji MTP/DFlash2 obsługują teraz warstwy 2-, 3-, 6- i 8-bitowe (w tym 6-row 8-bit batched decode), przyspieszając `flint-oQ8e`, `Qwen3.5-122B-9bit` i `Qwen3.8-Flash-Next-oQ5e-mtp`.
- **Współdzielenie cache'u promptu systemowego na modelach hybrydowych (PR #4994) oraz stabilność banków KV (PR #4916, #4936, #4971):** Zachowanie prompt cache pomiędzy sesjami i turami narzędziowymi Hermesa oraz eliminacja narostu pamięci RAM przez banki KV na długim kontekście.
- **Natywna obsługa Attention Sinks w TurboQuant KV (PR #4856) & Zabezpieczenie `incomplete_tool_call` (PR #4869):** Zespolone kernele przyjmują bufor attention sinks, a pętla agenta Hermes jest chroniona przed uciętymi wywołaniami narzędzi.

---

## ⚡ Warianty Architektury

Repozytorium udostępnia dwa gotowe warianty konfiguracji:

1. **Wariant 1 (Domyślny & Rekomendowany): `Zero-Swap Dynamic` (Kompresor = Model Sesji)**
   - Model główny: `Qwen3.8-Flash-Next-oQ5e-mtp` (lub dowolny inny wybrany model z 27 modeli w Hermesie, np. `DeepSeek-V4-Flash-0731-MXFP4-MLX`, `Inkling-Small-mxfp4`, `Hy4-flash-oQ4h-mtp` czy `flint-oQ8e`)
   - Kompresor: **Dynamiczny** (`auxiliary.compression.provider: auto`, `model: ''`) — zawsze kompresuje ten model, z którym aktualnie prowadzona jest rozmowa.
   - *Brak opóźnień związanych z przełączaniem modeli w pamięci RAM (0s swap latency) dla wszystkich 27 modeli.*

2. **Wariant 2: `Dual-Model Resident` (Dedykowany Szybki Kompresor 27B)**
   - Model główny: `Qwen3.8-Flash-Next-oQ5e-mtp` (256k) lub `Qwen3.5-122B-A10B-MLX-9bit`
   - Kompresor: `Qwen3.8-27B-Uncensored-MLX-SPLASH` (256k, ~15 GB w RAM, `is_pinned: true`, silnik **Splash 1.7.0-m1.1**)
   - *Ultraszybki (**72.9 tok/s** decode na Splash 1.7.0-m1.1), dedykowany model Splash z podziałem GPU/ANE (share 0.26), off-loop kompilacją Metal i akceleracją DFlash2 (3.6–5.8 tok/cykl) do podsumowań kontekstu współistniejący z modelem głównym.*

### 🔄 Szybkie przełączanie wariantów:

```bash
# Przełączenie na Wariant 1 (rekomendowany, dynamiczny kompresor sesji):
./switch-variant.sh 1

# Przełączenie na Wariant 2 (dedykowany kompresor 27B):
./switch-variant.sh 2

# Wymuszenie trybu zdalnego (IP z pliku .env):
./switch-variant.sh 1 --remote

# Wymuszenie trybu lokalnego:
./switch-variant.sh 1 --local
```

### 📦 Zarządzanie Przestrzenią Dyskową: `move_from_SSD_to_HDD.sh`

Gdy szybki dysk SSD zapełnia się nowymi modelami, skrypt `./move_from_SSD_to_HDD.sh` pozwala na inteligentne wykrycie i przeniesienie nieużywanych modeli na zewnętrzny dysk USB-C (`/Volumes/Seagate_Expansion_Drive/LLM`):

```bash
# Podgląd modeli kwalifikujących się do przeniesienia (dry-run, próg 14 dni):
./move_from_SSD_to_HDD.sh --check

# Wyszukanie modeli nieużywanych od 30 dni:
./move_from_SSD_to_HDD.sh --days 30 --check

# Interaktywne przenoszenie wybranych modeli z automatycznym tworzeniem dowiązań i aktualizacją oMLX:
./move_from_SSD_to_HDD.sh
```

- **Agregacja aktywności:** Bada logi serwera `server.log*`, bazę sesji SQLite Hermesa `state.db` oraz metadane plików.
- **Ochrona krytycznych modeli:** Automatycznie blokuje przypadkowe przeniesienie modelu domyślnego (`is_default`) oraz przypiętego kompresora (`is_pinned`).
- **Zerokosztowe dowiązania:** Tworzy symlinki na SSD, dodaje oznaczenie `[HDD]` w konfiguracji modeli i przeładowuje rejestr oMLX przez API.

### 🌐 Automatyczna Detekcja oMLX (Lokalny vs Zdalny Serwer)

Skrypt `./switch-variant.sh` automatycznie sprawdza, czy oMLX jest zainstalowany na bieżącej maszynie:
1. **Lokalny oMLX wykryty:** Konfiguruje Hermesa na `http://127.0.0.1:8000/v1` oraz synchronizuje pliki konfiguracyjne do `~/.omlx/`.
2. **Brak lokalnego oMLX:** Automatycznie przełącza Hermesa na zdalny serwer oMLX, pobierając adres IP z pliku `.env` (domyślnie `100.123.37.101` – prywatny serwer właściciela repozytorium dostępny via **Tailscale VPN**). Pomija katalog `~/.omlx/`.

> [!TIP]
> **Posiadasz własny serwer oMLX?**  
> Zmodyfikuj plik `.env`, wpisując własne IP serwera (`OMLX_IP=...`) oraz klucz (`OMLX_API_KEY=...`).

---

## 📁 Zawartość repozytorium

- **[`HowTo_JakUzywac.md`](HowTo_JakUzywac.md)** – Praktyczny przewodnik jak uruchamiać Hermesa oraz dobór modeli pod kątem 7 ról zawodowych i użytkowych.
- **[`konfiguracja-modeli.md`](konfiguracja-modeli.md)** – Kompletna dokumentacja techniczna 27 modeli w Hermesie (29 w oMLX) i linki Hugging Face.
- **[`config.yaml`](config.yaml)** – Aktywna konfiguracja agenta Hermes (domyślnie Wariant 1).
- **[`config.variant1-single-model.yaml`](config.variant1-single-model.yaml)** – Konfiguracja Hermesa dla Wariantu 1 (kompresor dynamiczny).
- **[`config.variant2-dual-model.yaml`](config.variant2-dual-model.yaml)** – Konfiguracja Hermesa dla Wariantu 2 (kompresor 27B).
- **[`model_settings.json`](model_settings.json)** – Aktywny rejestr modeli w oMLX.
- **[`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json)** – Ustawienia modeli dla Wariantu 1.
- **[`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json)** – Ustawienia modeli dla Wariantu 2 (`Qwen 27B` przypięty w RAM).
- **[`model_profiles.json`](model_profiles.json)** – Dedykowane profile wykonawcze (`work`, `turbo`, `setup`).
- **[`settings.json`](settings.json)** – Globalne parametry serwera oMLX oraz domyślny sampling.
- **[`switch-variant.sh`](switch-variant.sh)** – Skrypt bash do automatycznego przełączania wariantów.
- **[`move_from_SSD_to_HDD.sh`](move_from_SSD_to_HDD.sh)** – Skrypt audytu użycia i bezpiecznej migracji nieużywanych modeli z SSD na zewnętrzny HDD Seagate.
- **[`move_from_SSD_to_HDD.py`](move_from_SSD_to_HDD.py)** – Silnik analityczno-migracyjny skryptu (agregacja logów oMLX, SQLite Hermesa, obsługa transferu i symlinków).
- **[`omlx_bench.sh`](omlx_bench.sh)** – Automatyczny benchmark wszystkich lokalnych modeli OpenCode/oMLX bez prefiksu `[HDD]` na wspólnym zadaniu repozytorium (zbiera czasy, tury, wywołania narzędzi, `tok/s`, MTP i zrzuca tabelę `SUMMARY.md`).
