# Antigravity Project Instructions: oMLX & Hermes Setup

Gdy uruchamiasz sesję `agy` w tym katalogu, zapoznaj się z poniższym kontekstem i plikami projektu.

---

## 🎯 Główne Założenia Projektu

Ten katalog (`/Users/wojcio/Desktop/omlx_hermes_config`) zawiera centralną, wersjonowaną konfigurację modeli dla **Hermes Agenta** oraz serwera **oMLX** na komputerze **Mac Studio (192 GB Unified Memory)**.

1. **Pełna historia i decyzje sesji:**
   - Szczegółowy opis decyzji architektonicznych i ustaleń znajduje się w pliku [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md).
   - Tabela parametrów dla 20 modeli (okna do 256k, sampling, parsery, VLM/OCR) oraz bezpośrednie linki do Hugging Face znajdują się w [`konfiguracja-modeli.md`](konfiguracja-modeli.md).

2. **Dwa Dostępne Warianty Konfiguracji:**
   - **Wariant 1 (Domyślny / Zero-Swap Dynamic):** Kompresor = aktualny model sesji (`provider: auto`, `model: ''`), brak opóźnień przełączania i pełna dynamika dla wszystkich 20 modeli.
   - **Wariant 2 (Dual-Model Resident):** `Qwen3.5-122B` jako model główny + `Qwen3.8-27B-Uncensored-MLX` (~15 GB w RAM, `is_pinned: true`) jako dedykowany szybki kompresor.
   - Do przełączania wariantów służy skrypt: `./switch-variant.sh [1|2] [--local|--remote]`.
   - **Automatyczna detekcja oMLX:** Skrypt sam wykrywa, czy oMLX jest zainstalowany lokalnie. Jeśli nie, automatycznie konfiguruje Hermesa na zdalny serwer oMLX pobierając IP z pliku `.env` (domyślnie `100.123.37.101` via Tailscale VPN).

3. **Watchdog oMLX (Single-Model Guard):**
   - W systemie działa usługa `launchd` (`com.hermes.omlx-single-model-guard.plist`) wywołująca skrypt `~/.hermes/scripts/omlx-single-model-guard.py` co 180s.
   - Watchdog dba o to, by w RAM nie zalegały nieużywane modele. W Wariancie 2 model 27B posiada `is_pinned: true`, co chroni go przed wyładowaniem obok modelu 122B.

4. **Kalibracja Parametrów i Bezpieczeństwo:**
   - Sampling: `presence_penalty: 0.0` (ochrona formatów JSON/XML przed ucieczką tokenów), `repetition_penalty: 1.05`.
   - Rozumowanie: Odblokowany budżet myślenia (`thinking_budget_tokens: 32768`, `thinking_budget_enabled: false`).
   - Bezpieczeństwo i trwałość: `hard_stop_enabled: true`, `checkpoints.enabled: true`, `command_allowlist: []`, `lifetime_seconds: 1800`, `allow_lazy_installs: false`.

5. **Synchronizacja i Git:**
   - Wszelkie modyfikacje plików konfiguracyjnych wykonuj w tym katalogu, a następnie synchronizuj do `~/.hermes/config.yaml` oraz `~/.omlx/` za pomocą `./switch-variant.sh`.
   - Zmiany zatwierdzaj i wypychaj do repozytorium GitHub: `https://github.com/wojcio/omlx_hermes_setup.git`.

## 🔄 Ostatnie Zmiany i Stan Projektu (Wrzesień 2026)
- Rozszerzono bazę modeli z 18 do **20 pozycji** o wyspecjalizowane modele wizyjne OCR:
  * `olmOCR-2-7B-1025-8bit` (Qwen 2.5 VL, okno 128k, precyzyjny OCR PDF/tabel/kolumn do Markdowna),
  * `Unlimited-OCR-8bit` (DeepSeek-V2 MoE VLM z DeepEncoderem 2D, okno 32k, odczyt dokumentów bez limitu rozdzielczości).
- Pobrano natywne wagi MLX 8-bit do `~/.lmstudio/models/mlx-community/` (zastępując niekompatybilne z oMLX pliki GGUF).
- Dodano konfiguracje VLM w `model_settings.*.json` z odpowiednim samplingiem OCR (`temperature: 0.2`, `top_p: 0.90`).
- Skonfigurowano obsługę wizji (`supports_vision: true`) w Hermesie (`config.*.yaml` oraz `config.yaml`) dla modeli `olmOCR-2-7B-1025-8bit`, `Unlimited-OCR-8bit` oraz `UI-Venus-1.5-30B-A3B-qx86-hi-mlx`.
- Zsynchronizowano pliki konfiguracyjne z systemem za pomocą `switch-variant.sh`.
