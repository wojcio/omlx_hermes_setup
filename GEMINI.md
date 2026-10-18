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
