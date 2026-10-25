# oMLX & Hermes Setup

Zestaw zoptymalizowanych konfiguracji dla **oMLX 0.7.3.dev2** oraz **Hermes Agent** z precyzyjnie dobranymi oknami kontekstu (`max_context`), limitami wyjściowymi (`max_tokens`), akceleracją sprzętową (**Splash M1 1.3.2-m1.2**, **Lightning MTP**, **DFlash2**, **Fused MoE & GDN**, **Affine `hc_fused`**) oraz parametrami próbkowania (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty`) dla lokalnych modeli językowych na Apple Silicon (M2 Ultra / MLX).

---

## 📖 Pełna dokumentacja i Przewodnik Użytkownika

Szczegółowy opis wszystkich 17 modeli (w tym zaawansowanych modeli MoE `DeepSeek-V4-Flash-0731-MXFP4-MLX` z oknem 256k/1M, `Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2` (VLM, natywna głowica Lightning MTP `mtp-bf16`), ultraszybkiego `Qwen3.8-27B-Uncensored-MLX-SPLASH` (silnik Splash 1.3.2-m1.2 z podziałem Metal/ANE `share 0.26` i DFlash2 draft), akcelerowanych modeli `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` (`qwen4_gdn_decode_wide_proj`, 128 shardów N-gram, ~73.5 tok/s) i `Qwen3.8-Flash-Next-oQ5e-mtp` (VLM, 100 skompilowanych ścieżek Affine `hc_fused`, Lightning MTP 72.5% akceptacji), oraz wyspecjalizowanych modeli Vision / OCR: `olmOCR-2-7B-1025-8bit`, `Unlimited-OCR-8bit`, `UI-Venus-1.5-30B`, `MiniMax-M3-ConfigI-MLX`), bezpośrednie linki do repozytoriów Hugging Face, tabelę parametrów oraz praktyczne scenariusze użycia znajdziesz w plikach:

👉 **[Przewodnik Użytkownika & Use Cases dla 7 Ról (HowTo_JakUzywac.md)](HowTo_JakUzywac.md)**  
👉 **[Konfiguracja Techniczna Modeli & Hugging Face (konfiguracja-modeli.md)](konfiguracja-modeli.md)**

---

## 🚀 Nowości i optymalizacje w oMLX 0.7.3.dev2

Konfiguracja jest w 100% zgodna z **oMLX `0.7.3.dev2`** (`mlx-vlm 0.7.10`) i automatycznie wykorzystuje wprowadzone usprawnienia silnikowe:
- **Szybszy DFlash2 (`+16%` do `+33%` tok/s) dla modeli 27B:** Drafter `Qwen3.8-27B-DFlash2` (`bf16`) współpracujący z wariantami `Qwen3.8-27B-Uncensored-MLX` oraz `Qwen3.8-27B-FP16_huzar_v1` działa teraz w `fp16` z akumulacją rezydualną `fp32` (zamiast pełnego przebiegu w `fp32`).
- **Zespolone kernele dekodowania dla MiniMax M3 (`+14%` do `+23%` decode):** Przyspieszone dekodowanie dla `MiniMax-M3-ConfigI-MLX` w przedziale 5k–64k tokenów z zachowaniem bitowej identyczności wyników oraz nieskwantyzowanego *patch mergera* w ścieżce wizyjnej.
- **Ulepszenia Lightning MTP:** Przenoszenie stanu *batch park backoff* między zapytaniami dla modeli `Qwen3.8-Flash-Next-oQ5e-mtp` oraz `Qwen3.8-27B-Coder390-...-MTP-DFlash2`.
- **Stabilność dla Hermesa, VLM i MCP:** Poprawne wydzielanie bloków `<think>` otwartych w prompcie na wszystkich endpointach (`/v1/chat/completions`, `/v1/messages`, `/v1/responses`), pełna obsługa `tool_choice: none`, kompaktowa reprezentacja obrazów zwracanych przez narzędzia MCP (zamiast surowego base64 w kontekście) oraz natychmiastowe zwalnianie RAM po anulowaniu ładowania modelu.
- **Charakterystyka prędkości `DeepSeek-V4-Flash-0731-MXFP4-MLX` względem długości kontekstu:** Analiza logów `server.log` potwierdziła brak regresji w `0.7.3.dev2` (a nawet lekki wzrost z `28.3` do `30.0 tok/s` przy ~66k kontekstu). Model osiąga **31.0–34.6 tok/s** na krótkim/średnim kontekście (`9k–45k`), **~30.0 tok/s** przy `~67k`, natomiast powyżej **`210k–232k` tokenów** prędkość naturalnie spada do **21.0–23.7 tok/s** (z uwagi na wyłączenie TurboQuant KV przez *attention sinks* i utrzymywanie `fp16` KV cache przy `158.8 GB` wag modelu, dłuższy czas kroku `backbone` `95 ms` $\rightarrow$ `128 ms` oraz spadek akceptacji draftera DSpark MTP przy długich wywołaniach `tool_calls`).

---

## ⚡ Warianty Architektury

Repozytorium udostępnia dwa gotowe warianty konfiguracji:

1. **Wariant 1 (Domyślny & Rekomendowany): `Zero-Swap Dynamic` (Kompresor = Model Sesji)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (lub dowolny inny wybrany model, np. `DeepSeek-V4-Flash-0731-MXFP4-MLX`, `Coder390-27B` czy `Qwen3.8-Flash-Next-Speed`)
   - Kompresor: **Dynamiczny** (`auxiliary.compression.provider: auto`, `model: ''`) — zawsze kompresuje ten model, z którym aktualnie prowadzona jest rozmowa.
   - *Brak opóźnień związanych z przełączaniem modeli w pamięci RAM (0s swap latency) dla wszystkich 17 modeli.*

2. **Wariant 2: `Dual-Model Resident` (Dedykowany Szybki Kompresor 27B)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (256k)
   - Kompresor: `Qwen3.8-27B-Uncensored-MLX-SPLASH` (256k, ~15 GB w RAM, `is_pinned: true`, silnik Splash 1.3.2-m1.2)
   - *Ultraszybki (~43–70+ tok/s), dedykowany model Splash z podziałem GPU/ANE (share 0.26) i akceleracją DFlash2 do podsumowań kontekstu współistniejący z modelem głównym.*

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
- **[`konfiguracja-modeli.md`](konfiguracja-modeli.md)** – Kompletna dokumentacja techniczna 17 modeli i linki Hugging Face.
- **[`config.yaml`](config.yaml)** – Aktywna konfiguracja agenta Hermes (domyślnie Wariant 1).
- **[`config.variant1-single-model.yaml`](config.variant1-single-model.yaml)** – Konfiguracja Hermesa dla Wariantu 1 (kompresor dynamiczny).
- **[`config.variant2-dual-model.yaml`](config.variant2-dual-model.yaml)** – Konfiguracja Hermesa dla Wariantu 2 (kompresor 27B).
- **[`model_settings.json`](model_settings.json)** – Aktywny rejestr modeli w oMLX.
- **[`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json)** – Ustawienia modeli dla Wariantu 1.
- **[`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json)** – Ustawienia modeli dla Wariantu 2 (`Qwen 27B` przypięty w RAM).
- **[`model_profiles.json`](model_profiles.json)** – Dedykowane profile wykonawcze (`work`, `turbo`, `setup`).
- **[`settings.json`](settings.json)** – Globalne parametry serwera oMLX oraz domyślny sampling.
- **[`switch-variant.sh`](switch-variant.sh)** – Skrypt bash do automatycznego przełączania wariantów.
