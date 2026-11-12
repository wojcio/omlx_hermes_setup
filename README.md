# oMLX & Hermes Setup

Zestaw zoptymalizowanych konfiguracji dla **oMLX 0.7.4.dev1** (Apple **MLX 0.32.4**, `mlx-lm 0.32.3.dev8`, `mlx-vlm 0.7.11`, sufit pamięci **186 GB RAM**) oraz **Hermes Agent** z precyzyjnie dobranymi oknami kontekstu (`max_context` do **512k/1M**), limitami wyjściowymi (`max_tokens`), akceleracją sprzętową (**Splash M1 1.6.0-m1**, **Lightning MTP**, **DFlash2**, **Fused MoE & GDN/KDA**, **Affine `hc_fused`**, **FP16 Activation Recast**) oraz parametrami próbkowania (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty`) dla **25 modeli w Hermesie (27 w oMLX)** na Apple Silicon (M2 Ultra / MLX).

---

## 📖 Pełna dokumentacja i Przewodnik Użytkownika

Szczegółowy opis wszystkich **25 modeli w Hermesie (27 w oMLX)** — w tym nowych rodzin:
- **`Qwen3.8-Flash-Next-oQ5e-mtp`** (~119.9 GB, **67.5–97 tok/s**) oraz **`Qwen3.8-Flash-Next-oQ6e-mtp`** (6-bit, ~141.1 GB, **60.6–63.9 tok/s**) i **`Qwen3.8-Flash-Next-MTPLX-Optimized-Speed`** (**~73.5 tok/s**),
- **`GLM-5.3-Flash-oQ4e-mtp`** (320B MoE / 18B akt., 173.9 GB w 100% w RAM, TTFT **0.17s**, **25.9–29.9 tok/s**) oraz **`GLM-5.3-Flash-oQ2e-mtp`** (320B MoE w hybrydowym 2-bit/4-bit, tylko **102.9 GB RAM**, **32.1–37.6 tok/s**),
- **`gemma-4-12B-it-oQ8e-mtp`** (Any-to-Any VLM/Audio, 13.0 GB, **51.4–68.4 tok/s**) oraz **`gemma-4-31B-it-oQ6e-mtp`** (Dense 31B VLM, 26.3 GB, `gemma4_verify_kernel`, **32.4–34.0 tok/s**),
- **`Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed`** (2-bit Hadamard 27B VLM, tylko **8.23 GB RAM**, **31.4 tok/s**) oraz **`Nanbeige4.3-33B-MLX-6bit`** (Dense 33B, okno **512k tokenów**, **19.6 tok/s**),
- autonomicznego agenta kodującego **`flint-oQ8e`** (MoE 39.8B, 2.5B akt./tok, do **74.1 tok/s**), **`DeepSeek-V4-Flash-0731-MXFP4-MLX`**, **`Qwen3.8-27B-Coder390-...-MTP-DFlash2`**, **`Qwen3.8-27B-Uncensored-MLX-SPLASH`** (Splash 1.6.0-m1, do **64.0 tok/s**) oraz modeli zarchiwizowanych na zewnętrznym dysku USB-C z oznaczeniem **`[HDD]`** (`Qwen3.5-122B`, `Qwen3-Coder-Next`, `Qwen3-235B`) — znajdziesz w plikach:

👉 **[Przewodnik Użytkownika & Use Cases dla 7 Ról (HowTo_JakUzywac.md)](HowTo_JakUzywac.md)**  
👉 **[Konfiguracja Techniczna Modeli & Hugging Face (konfiguracja-modeli.md)](konfiguracja-modeli.md)**

---

## 🚀 Nowości i optymalizacje w oMLX 0.7.4.dev1 & Splash 1.5.0-m1

Konfiguracja jest w 100% zgodna z **oMLX `0.7.4.dev1`** (build `3628`, silnik **Apple MLX `0.32.4`**, `mlx-lm 0.32.3.dev8`, `mlx-vlm 0.7.11`) oraz silnikiem **Splash M1 `1.5.0-m1`** i automatycznie wykorzystuje najnowsze usprawnienia:
- **Nowy silnik Splash M1 1.5.0-m1 (`paperniuk/splash`):** Zawiera upstreamowe wydania `1.4.1` i `1.5.0` oraz ulepszenia kerneli M1/M2: optymalizację `Prefill Tail` i ANE (#32, o 30–70 ms niższy TTFT), szybszą atencję długiego kontekstu (#33, skalowanie z 60 rdzeniami GPU M2 Ultra: +3.5% przy 64k i +7.4% przy 128k), poprawki `Host Steps` (#38) i `Column Tile for MoE` (#29), skwantyzowane routery MoE (#599) oraz podział ANE/GPU (`share 0.26`, 53.1 ms vs 70.1 ms na samym GPU).
- **Akceleracja `activation_fp16_enabled: true` i `attn_fused` w Qwen3.8-Flash-Next (PR #4901, #4988, #5028):** Na procesorze M2 Ultra przełączenie liści `bfloat16 -> float16` (2 471 tensorów) odblokowuje natywne ścieżki FP16 i naprawia limit wątków grupy (`Thread group size 1024 > 896`) w nowym dwuprzebiegowym kernelu `omlx_qwen4_attn_sdpa2_gate`, podnosząc prędkość generowania `Qwen3.8-Flash-Next-oQ5e-mtp` w fazie czystego rozumowania z 39.6 do **62.56 tok/s** (+58%, TTFT 0.48s) i do **~97 tok/s** na kodzie.
- **Kernele M1/M2 Verify MMA dla warstw 6-bit i 8-bit (PR #4898, #4990, `b5c7793e`):** Wielowierszowe kernele dekodowania i weryfikacji MTP/DFlash2 obsługują teraz warstwy 2-, 3-, 6- i 8-bitowe (w tym 6-row 8-bit batched decode), przyspieszając `flint-oQ8e`, `Qwen3.5-122B-9bit` i `Qwen3.8-Flash-Next-oQ5e-mtp`.
- **Współdzielenie cache'u promptu systemowego na modelach hybrydowych (PR #4994) oraz stabilność banków KV (PR #4916, #4936, #4971):** Zachowanie prompt cache pomiędzy sesjami i turami narzędziowymi Hermesa oraz eliminacja narostu pamięci RAM przez banki KV na długim kontekście.
- **Natywna obsługa Attention Sinks w TurboQuant KV (PR #4856) & Zabezpieczenie `incomplete_tool_call` (PR #4869):** Zespolone kernele przyjmują bufor attention sinks, a pętla agenta Hermes jest chroniona przed uciętymi wywołaniami narzędzi.

---

## ⚡ Warianty Architektury

Repozytorium udostępnia dwa gotowe warianty konfiguracji:

1. **Wariant 1 (Domyślny & Rekomendowany): `Zero-Swap Dynamic` (Kompresor = Model Sesji)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (lub dowolny inny wybrany model, np. `DeepSeek-V4-Flash-0731-MXFP4-MLX`, `Coder390-27B` czy `Qwen3.8-Flash-Next-Speed`)
   - Kompresor: **Dynamiczny** (`auxiliary.compression.provider: auto`, `model: ''`) — zawsze kompresuje ten model, z którym aktualnie prowadzona jest rozmowa.
   - *Brak opóźnień związanych z przełączaniem modeli w pamięci RAM (0s swap latency) dla wszystkich 18 modeli.*

2. **Wariant 2: `Dual-Model Resident` (Dedykowany Szybki Kompresor 27B)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (256k)
   - Kompresor: `Qwen3.8-27B-Uncensored-MLX-SPLASH` (256k, ~15 GB w RAM, `is_pinned: true`, silnik Splash 1.5.0-m1)
   - *Ultraszybki (60.5–64.0 tok/s), dedykowany model Splash z podziałem GPU/ANE (share 0.26), optymalizacją Prefill Tail/Attention i akceleracją DFlash2 (3.5–3.92 tok/cykl) do podsumowań kontekstu współistniejący z modelem głównym.*

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
- **[`konfiguracja-modeli.md`](konfiguracja-modeli.md)** – Kompletna dokumentacja techniczna 18 modeli i linki Hugging Face.
- **[`config.yaml`](config.yaml)** – Aktywna konfiguracja agenta Hermes (domyślnie Wariant 1).
- **[`config.variant1-single-model.yaml`](config.variant1-single-model.yaml)** – Konfiguracja Hermesa dla Wariantu 1 (kompresor dynamiczny).
- **[`config.variant2-dual-model.yaml`](config.variant2-dual-model.yaml)** – Konfiguracja Hermesa dla Wariantu 2 (kompresor 27B).
- **[`model_settings.json`](model_settings.json)** – Aktywny rejestr modeli w oMLX.
- **[`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json)** – Ustawienia modeli dla Wariantu 1.
- **[`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json)** – Ustawienia modeli dla Wariantu 2 (`Qwen 27B` przypięty w RAM).
- **[`model_profiles.json`](model_profiles.json)** – Dedykowane profile wykonawcze (`work`, `turbo`, `setup`).
- **[`settings.json`](settings.json)** – Globalne parametry serwera oMLX oraz domyślny sampling.
- **[`switch-variant.sh`](switch-variant.sh)** – Skrypt bash do automatycznego przełączania wariantów.
