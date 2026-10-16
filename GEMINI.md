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
- Utworzono praktyczny przewodnik użytkownika [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md) opisujący komendy CLI Hermesa (`hermes -m`, `/model`, `--reasoning`, `--worktree`, `./switch-variant.sh`) oraz macierz doboru wszystkich 17 modeli pod kątem 7 ról: Programista, UI Designer, Web Developer, DevOps, Security Manager, Zwykły Użytkownik oraz Sekretarka Biura.
- Rozszerzono bazę modeli do **17 pozycji** (włączono 2 nowe wyspecjalizowane modele pobrane do `~/.lmstudio/models`):
  * `Cyber-Tiel-Coder-35B-A3B-MLX-oQ6e-MTP` (`peculiar-ragdoll/Cyber-Tiel-Coder-35B-A3B-MLX-oQ6e-MTP`): lekki model programistyczny MoE (40 warstw, 256 ekspertów, top-8 routed, zaledwie ~3B aktywnych parametrów na token), kwantyzacja `oQ6e` iMatrix pod kod wielojęzyczny, okno **262 144 tokenów (256k)**, VLM (`supports_vision: true`), sampling: `temperature: 0.6`, `top_p: 0.95`, `top_k: 40`, `repetition_penalty: 1.05`, MTP, wagi ~31.7 GB w RAM.
  * `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` (`Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed`): ultra-szybki model ogólny MoE (48 warstw, 512 ekspertów, top-10 routed), wdrożony runtime MTPLX z 32 GB tablicą ngramów i spekulatywnym MTP depth 3 dający aż **~73.5 tok/s** (1.68x przyspieszenie), okno **262 144 tokenów (256k)**, VLM (`supports_vision: true`), sampling: `temperature: 0.7`, `top_p: 0.95`, `top_k: 20`, wagi ~120.8 GB w RAM.
- Poprzednie zmiany:
  * Dodano `MiniMax-M3-ConfigI-MLX` (60 warstw, 128 ekspertów top-4, 128k okno, ~156 GB). Naprawiono ładowanie w oMLX (`vision_config` + 114 wpisów `gate_up_proj` w lokalnym pliku `config.json`).
- Zaktualizowano konfiguracje Hermesa (`config.*.yaml`, `config.yaml`, `~/.hermes/config.yaml`) i oMLX (`model_settings.*.json`, `~/.omlx/model_settings.json`).
- Zaktualizowano dokumentację techniczną (`konfiguracja-modeli.md`, `README.md`, `SESJA_KONTEKST.md`, `HowTo_JakUzywac.md`) i zsynchronizowano środowisko przez `./switch-variant.sh 1`.
