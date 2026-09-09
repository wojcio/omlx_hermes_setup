# Antigravity Project Instructions: oMLX & Hermes Setup

Gdy uruchamiasz sesję `agy` w tym katalogu, zapoznaj się z poniższym kontekstem i plikami projektu.

---

## 🎯 Główne Założenia Projektu

Ten katalog (`/Users/wojcio/Desktop/omlx_hermes_config`) zawiera centralną, wersjonowaną konfigurację modeli dla **Hermes Agenta** oraz serwera **oMLX** na komputerze **Mac Studio (192 GB Unified Memory)**.

1. **Pełna historia i decyzje sesji:**
   - Szczegółowy opis decyzji architektonicznych i ustaleń znajduje się w pliku [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md).
   - Tabela parametrów dla 18 modeli (okna 256k, sampling, parsery) oraz bezpośrednie linki do Hugging Face znajdują się w [`konfiguracja-modeli.md`](konfiguracja-modeli.md).

2. **Dwa Dostępne Warianty Konfiguracji:**
   - **Wariant 1 (Domyślny / Zero-Swap Dynamic):** Kompresor = aktualny model sesji (`provider: auto`, `model: ''`), brak opóźnień przełączania i pełna dynamika dla wszystkich 18 modeli.
   - **Wariant 2 (Dual-Model Resident):** `Qwen3.5-122B` jako model główny + `Qwen3.8-27B-Uncensored-MLX` (~15 GB w RAM, `is_pinned: true`) jako dedykowany szybki kompresor.
   - Do przełączania wariantów służy skrypt: `./switch-variant.sh [1|2]`.

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
- Rozszerzono bazę obsługiwanych modeli z 15 do 18 pozycji.
- Dołączono do oMLX i Hermesa 3 nowe modele:
  1. `Qwen3.8-Flash-Next-oQ5e-mtp` (GBP-DE, 256k okno, format oQ5e z iMatrix i MTP, architektura Qwen 4 Exp).
  2. `Qwen3.8-27B-FP16_huzar_v1` (Lokalny fine-tune bazy wiedzy Huzar na wagach FP16, 256k okno, pełne myślenie).
  3. `Bielik-11B-v3.0-Huzar-MLX-8bit-v1` (Lokalny fine-tune bazy wiedzy Huzar na modelu Bielik 11B, 32k okno).
- Zaktualizowano konfiguracje wariantów 1 i 2 (`config.*.yaml`, `model_settings.*.json`), dokumentację techniczną oraz zsynchronizowano serwer oMLX i agenta Hermes.
