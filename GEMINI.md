# Antigravity Project Instructions: oMLX & Hermes Setup

Gdy uruchamiasz sesję `agy` w tym katalogu, zapoznaj się z poniższym kontekstem i plikami projektu.

---

## 🎯 Główne Założenia Projektu

Ten katalog (`/Users/wojcio/Desktop/omlx_hermes_config`) zawiera centralną, wersjonowaną konfigurację modeli dla **Hermes Agenta** oraz serwera **oMLX** na komputerze **Mac Studio (192 GB Unified Memory)**.

1. **Pełna historia i decyzje sesji:**
   - Szczegółowy opis decyzji architektonicznych i ustaleń znajduje się w pliku [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md).
   - Tabela parametrów dla 20 modeli (okna do 1M, sampling, parsery, VLM/OCR) oraz bezpośrednie linki do Hugging Face znajdują się w [`konfiguracja-modeli.md`](konfiguracja-modeli.md).

2. **Dwa Dostępne Warianty Konfiguracji:**
   - **Wariant 1 (Domyślny / Zero-Swap Dynamic):** Kompresor = aktualny model sesji (`provider: auto`, `model: ''`), brak opóźnień przełączania i pełna dynamika dla wszystkich 20 modeli.
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
- Rozszerzono bazę modeli do **20 pozycji** (dodano `MiniMax-M3-ConfigI-MLX`, usunięto lokalne modele testowe Huzar: `Bielik-11B-v3.0-Huzar-MLX-8bit-v1` oraz `Qwen3.8-27B-FP16_huzar_v1`):
  * `MiniMax-M3-ConfigI-MLX` (`thetom-ai/MiniMax-M3-ConfigI-MLX`): 60 warstw, 128 ekspertów (top-4), multimodalny (VL), kwantyzacja ConfigI (wagi ~156 GB), okno kontekstu **131 072 tokenów (128k; natywnie 1M, ograniczone ze względu na 192 GB RAM)**, parser rozumowania `minimax_m3` (`<mm:think>`), sampling: `temperature: 1.0`, `top_p: 0.95`, `top_k: 40`, `repetition_penalty: 1.00`, włączona obsługa wizji w Hermesie (`supports_vision: true`).
- Zaktualizowano konfiguracje Hermesa (`config.*.yaml`, `config.yaml`, `~/.hermes/config.yaml`) i oMLX (`model_settings.*.json`, `~/.omlx/model_settings.json`).
- Zaktualizowano dokumentację techniczną (`konfiguracja-modeli.md`, `README.md`, `SESJA_KONTEKST.md`) i zsynchronizowano środowisko przez `./switch-variant.sh 1`.
- Naprawa ładowania `MiniMax-M3-ConfigI-MLX` w oMLX (poprawki w `~/.lmstudio/models/thetom-ai/MiniMax-M3-ConfigI-MLX/config.json`, poza repo; kopia: `config.json.bak-no-vision_config`): (1) dodano brakujący `vision_config` z `MiniMaxAI/MiniMax-M3` (oMLX wykrywał model jako text-only LLM, a wagi zawierają wieżę wizyjną), (2) dodano 114 wpisów kwantyzacji `switch_mlp.gate_up_proj` (te same bity co `gate_proj`; bez nich loader przyjmował 4 bity zamiast 2). Po zmianach model wykrywany jest jako `vlm` i ładuje się poprawnie (~23 tok/s). Ponowne pobranie modelu nadpisze config i wymaga powtórzenia poprawek.
