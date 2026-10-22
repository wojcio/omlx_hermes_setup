# Antigravity Project Instructions: oMLX & Hermes Setup

Gdy uruchamiasz sesję `agy` w tym katalogu, zapoznaj się z poniższym kontekstem i plikami projektu.

---

## 🎯 Główne Założenia Projektu

Ten katalog (`/Users/wojcio/Desktop/omlx_hermes_config`) zawiera centralną, wersjonowaną konfigurację modeli dla **Hermes Agenta** oraz serwera **oMLX** na komputerze **Mac Studio (192 GB Unified Memory)**.

1. **Pełna historia i decyzje sesji:**
   - Szczegółowy opis decyzji architektonicznych i ustaleń znajduje się w pliku [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md).
   - Tabela parametrów dla 17 modeli (okna do 1M, sampling, parsery, VLM/OCR) oraz bezpośrednie linki do Hugging Face znajdują się w [`konfiguracja-modeli.md`](konfiguracja-modeli.md).
   - Praktyczny przewodnik obsługi CLI oraz dobór modeli pod kątem 7 ról zawodowych i użytkowych (Use Cases) znajduje się w [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md).

2. **Dwa Dostępne Warianty Konfiguracji:**
   - **Wariant 1 (Domyślny / Zero-Swap Dynamic):** Kompresor = aktualny model sesji (`provider: auto`, `model: ''`), brak opóźnień przełączania i pełna dynamika dla wszystkich 17 modeli.
   - **Wariant 2 (Dual-Model Resident):** `Qwen3.5-122B` jako model główny + `Qwen3.8-27B-Uncensored-MLX` (~15 GB w RAM, `is_pinned: true`) jako dedykowany szybki kompresor.
   - Do przełączania wariantów służy skrypt: `./switch-variant.sh [1|2] [--local|--remote]`.
   - **Automatyczna detekcja oMLX:** Skrypt sam wykrywa, czy oMLX jest zainstalowany lokalnie. Jeśli nie, automatycznie konfiguruje Hermesa na zdalny serwer oMLX pobierając IP z pliku `.env` (domyślnie `100.123.37.101` via Tailscale VPN).

3. **Watchdog oMLX (Single-Model Guard):**
   - W systemie działa usługa `launchd` (`com.hermes.omlx-single-model-guard.plist`) wywołująca skrypt `~/.hermes/scripts/omlx-single-model-guard.py` co 180s.
   - Watchdog dba o to, by w RAM nie zalegały nieużywane modele. W Wariancie 2 model 27B posiada `is_pinned: true`, co chroni go przed wyładowaniem obok modelu 122B.

4. **Kalibracja Parametrów i Bezpieczeństwo:**
   - Sampling: `presence_penalty: 0.0` (ochrona formatów JSON/XML przed ucieczką tokenów), `repetition_penalty: 1.05` (dla modeli DeepSeek: `1.00`).
   - Rozumowanie: Odblokowany budżet myślenia (`thinking_budget_tokens: 32768`, `thinking_budget_enabled: false`).
   - Bezpieczeństwo i trwałość: `hard_stop_enabled: true`, `checkpoints.enabled: true`, `command_allowlist: []`, `lifetime_seconds: 1800`, `allow_lazy_installs: false`.

5. **Synchronizacja i Git:**
   - Wszelkie modyfikacje plików konfiguracyjnych wykonuj w tym katalogu, a następnie synchronizuj do `~/.hermes/config.yaml` oraz `~/.omlx/` za pomocą `./switch-variant.sh`.
   - Zmiany zatwierdzaj i wypychaj do repozytorium GitHub: `https://github.com/wojcio/omlx_hermes_setup.git`.

## 🔄 Ostatnie Zmiany i Stan Projektu (Październik 2026)
- **Diagnostyka i naprawa ładowania `Qwen3.8-Flash-Next-oQ5e-mtp` oraz audyt akceleracji Affine/MTP:**
  * **Naprawa silnika ładowania:**
    - Wykryto, że `Qwen3.8-Flash-Next-oQ5e-mtp` miał ustawiony `model_type_override: "llm"`, co powodowało próbę ładowania przez `mlx_lm` i błąd `ValueError: Model type qwen4_exp not supported`.
    - Zmieniono `model_type_override` na `"vlm"` (silnik `mlx_vlm`) w `model_settings.json` oraz wariantach 1 i 2, a także ustawiono `reasoning_parser: "qwen_3_5"` i `thinking_budget_tokens: 32768`.
  * **Weryfikacja akceleracji Affine i Lightning MTP:**
    - W odróżnieniu od wersji `Speed` (gdzie wagi miksera HC były w nieskwantyzowanym BF16), wersja `oQ5e` ma wszystkie 296 wag Hyper-Connection w formacie **Affine 6-bit / group 64**. Dzięki temu `hc_fused` skompilował 100 dedykowanych ścieżek dekodowania na GPU.
    - Wbudowane tensory `mtp.` aktywowały **Lightning MTP**, uzyskując znakomity współczynnik akceptacji draftów na poziomie **72.5%** (2.50 tok/cykl).
    - Zweryfikowano działanie zapytaniem przez Hermes CLI (`hermes -m Qwen3.8-Flash-Next-oQ5e-mtp -z "..."`).
- **Aktualizacja silnika do Splash 1.3.2-m1.2 z udoskonalonym podziałem Neural Engine / GPU:**
  * **Aktualizacja binariów:**
    - Zaktualizowano `splash-m1` z wersji `1.3.2-m1.1` do najnowszej wersji **`1.3.2-m1.2`** (`paperniuk/splash`) poprzez dedykowany instalator.
    - W `/opt/homebrew/bin/splash-m1` dostępna jest teraz wersja `Splash 1.3.2-m1.2`, w pełni kompatybilna z GPU family 8 (Apple M2 Ultra).
  * **Weryfikacja w oMLX i Hermes Agent:**
    - Moduł `omlx.engine.splash.find_splash_binary()` automatycznie wykrywa nową wersję (`version='1.3.2-m1.2'`).
    - Ponowna kalibracja Neural Engine FFN split zoptymalizowała udział ANE do **share 0.26** dla bloków $\ge$ 533 wierszy, redukując czas warstwy FFN z 70.5 ms (sam GPU) do **53.1 ms** (GPU + ANE).
    - Zweryfikowano działanie modelu `Qwen3.8-27B-Uncensored-MLX-SPLASH` z cache KV na SSD (256k kontekstu) oraz wykonano zapytanie weryfikacyjne w Hermes CLI (`hermes -m ... -z`), uzyskując prędkość generowania do **42.7 tok/s**.
- **Wdrożenie i pełna integracja silnika Splash 1.3.2-m1.1 z akceleracją DFlash2 na Apple M2 Ultra:**
  * **Diagnoza architektury GPU i aktualizacja `splash-m1`:**
    - Wykryto, że oficjalny pakiet `splash 1.3.2` z Homebrew wymaga układu Apple GPU family 9 (M3/M4) i odrzuca procesor M2 Ultra (GPU family 8).
    - Starsza zainstalowana wersja `splash-m1 1.0.2-m1` była odrzucana przez oMLX (`MIN_SPLASH_VERSION = (1, 3, 0)`).
    - Zaktualizowano `splash-m1` do najnowszej wersji **`1.3.2-m1.1`** (`paperniuk/splash`), która posiada pełne wsparcie dla GPU family 8 (M1/M2), spełnia wymogi oMLX $\ge$ 1.3.0 i jest automatycznie wybierana przez silnik oMLX jako pierwszy priorytet na maszynach M1/M2.
  * **Pobranie wag pomocniczych DFlash2 Draft:**
    - Utworzono katalog `~/.lmstudio/models/incoai/Qwen3.8-27B-DFlash2/` i pobrano wagi `config.json` oraz `model.safetensors` (~3.85 GB), co odblokowało w oMLX status `compatible: true` dla modeli Qwen 27B.
  * **Zerokosztowe symlinki `-SPLASH` w `~/.lmstudio/models`:**
    - Utworzono dowiązania:
      * `orcarouter/Qwen3.8-27B-Uncensored-MLX-SPLASH` -> `Qwen3.8-27B-Uncensored-MLX`
      * `huzar/Qwen3.8-27B-FP16_huzar_v1-SPLASH` -> `Qwen3.8-27B-FP16_huzar_v1`
    - W oMLX włączono dla nich `"external_engine": "splash"`.
  * **Aktualizacja konfiguracji Hermesa (17 modeli) i Wariantu 2:**
    - Do konfiguracji Hermesa wprowadzono model **`Qwen3.8-27B-Uncensored-MLX-SPLASH`** (w tym jako przypięty `is_pinned: true`, ultraszybki kompresor w Wariancie 2).
    - Zgodnie z wytyczną użytkownika, model Huzar (`Qwen3.8-27B-FP16_huzar_v1`) został całkowicie usunięty z konfiguracji Hermesa (pozostaje dostępny bezpośrednio w oMLX jako model lokalny).
    - Liczba modeli w konfiguracji Hermesa wynosi dokładnie **17**.
  * **Weryfikacja działania:**
    - Zweryfikowano poprawność kompilacji grafu Metal/ANE FFN split (share 0.24, 60 rdzeni GPU) oraz działanie cache KV na SSD.
    - Przetestowano zapytania strumieniowe i one-shot CLI Hermesa (`hermes -m Qwen3.8-27B-Uncensored-MLX-SPLASH -z "..."`), uzyskując natychmiastowe odpowiedzi (~4s całkowitego czasu procesu).
- **Audyt nowych modeli oMLX i eliminacja duplikatów (Optymalizacja katalogu 17 modeli):**
  * Zbadano 4 nowe modele obecne w `~/.lmstudio/models` i oMLX:
    - Pominięto `Bielik-11B-v3.0-Huzar-MLX-8bit-v1` zgodnie z wytyczną użytkownika.
    - Zastąpiono `Bielik-11B-v3.0-Instruct-MLX-8bit` (wąskie okno 32k) flagowym modelem **`Qwen3.8-27B-FP16_huzar_v1`** (`huzar/Qwen3.8-27B-FP16_huzar_v1`): wagi 8-bit (~28 GB RAM), pełne okno **262 144 tokenów (256k)**, akceleracja DFlash, wytrenowany na bazie wiedzy Huzar (`bielik3.0-dataset.jsonl`).
    - Zastąpiono wolniejszy model `Cyber-Tiel-Coder-35B-A3B-MLX-oQ6e-MTP` (~9.1 tok/s) modelem **`Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2`** (`nerkyor/`): pełna precyzja BF16 (~30.6 GB RAM), multimodalna wieża wizyjna VLM (`supports_vision: true`), MTP depth 3, DFlash2, generowanie aż **~34.6 tok/s (niemal 4x szybciej)**, zaawansowane destylacje (Opus 5.5, GPT-6 Astra, Grok 4.7, DeepSeek V4 Pro).
    - Pominięto `Qwen3.8-27B-Coder390-...-oQ4e` (`hermitdave/`) jako redundantny, 4-krotnie wolniejszy (~9 tok/s) dubel wersji BF16 pozbawiony wizji.
    - Zachowano `Qwen3.8-27B-Uncensored-MLX` jako optymalny i ultra-szybki (33.1 tok/s) przypięty kompresor Wariantu 2.
  * Zaktualizowano konfiguracje Hermesa (`config.variant1-single-model.yaml`, `config.variant2-dual-model.yaml`, `config.yaml`, `~/.hermes/config.yaml`) oraz oMLX (`model_settings.*.json`, `model_settings.json`, `~/.omlx/model_settings.json`).
  * Zaktualizowano przewodnik ról [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md), specyfikację techniczną [`konfiguracja-modeli.md`](konfiguracja-modeli.md) oraz [`README.md`](README.md).
  * Zsynchronizowano środowisko skryptem `./switch-variant.sh 1` i zweryfikowano poprawne działanie obu modeli bezpośrednio przez `hermes -m ... -z`.
  * **Oczyszczenie dysku i rejestru oMLX:** Usunięto z `~/.lmstudio/models/` fizyczne wagi 4 zdublowanych/zastąpionych modeli (`Bielik-11B-Instruct`, `Bielik-11B-Huzar`, `Cyber-Tiel-Coder-35B`, `Coder390-oQ4e`), zwalniając **65.48 GB** miejsca na dysku. Po przeładowaniu oMLX (`POST /admin/api/reload`) osiągnięto pełną, stuprocentową zgodność 1:1 między oMLX (`/v1/models`) a Hermesem (dokładnie **17 modeli**).
- Wcześniejsze zmiany:
  * Utworzono praktyczny przewodnik użytkownika `HowTo_JakUzywac.md` opisujący komendy CLI Hermesa oraz macierz doboru modeli dla 7 ról.
  * Wdrożono i naprawiono ładowanie `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` (73.5 tok/s) oraz `MiniMax-M3-ConfigI-MLX` (156 GB).
