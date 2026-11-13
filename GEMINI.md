# Antigravity Project Instructions: oMLX & Hermes Setup

Gdy uruchamiasz sesję `agy` w tym katalogu, zapoznaj się z poniższym kontekstem i plikami projektu.

---

## 🎯 Główne Założenia Projektu

Ten katalog (`/Users/wojcio/Desktop/omlx_hermes_config`) zawiera centralną, wersjonowaną konfigurację modeli dla **Hermes Agenta** oraz serwera **oMLX** na komputerze **Mac Studio (192 GB Unified Memory)**.

1. **Pełna historia i decyzje sesji:**
   - Szczegółowy opis decyzji architektonicznych i ustaleń znajduje się w pliku [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md).
   - Tabela parametrów dla **25 modeli w Hermesie (27 w oMLX)** (okna do 512k/1M, sampling, parsery, VLM/OCR/Audio) oraz bezpośrednie linki do Hugging Face znajdują się w [`konfiguracja-modeli.md`](konfiguracja-modeli.md).
   - Praktyczny przewodnik obsługi CLI oraz dobór modeli pod kątem 7 ról zawodowych i użytkowych (Use Cases) znajduje się w [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md).

2. **Dwa Dostępne Warianty Konfiguracji:**
   - **Wariant 1 (Domyślny / Zero-Swap Dynamic):** Kompresor = aktualny model sesji (`provider: auto`, `model: ''`), brak opóźnień przełączania i pełna dynamika dla wszystkich 25 modeli (domyślnie `Qwen3.8-Flash-Next-oQ5e-mtp`, limit pamięci Metal `186 GB`).
   - **Wariant 2 (Dual-Model Resident):** `Qwen3.8-Flash-Next-oQ5e-mtp` (lub `GLM-5.3-Flash-oQ2e-mtp`) jako model główny + `Qwen3.8-27B-Uncensored-MLX-SPLASH` (~15 GB w RAM, `is_pinned: true`, silnik Splash 1.6.0-m1) jako dedykowany szybki kompresor.
   - Do przełączania wariantów służy skrypt: `./switch-variant.sh [1|2] [--local|--remote]`.
   - **Automatyczna detekcja oMLX:** Skrypt sam wykrywa, czy oMLX jest zainstalowany lokalnie. Jeśli nie, automatycznie konfiguruje Hermesa na zdalny serwer oMLX pobierając IP z pliku `.env` (domyślnie `100.123.37.101` via Tailscale VPN).

3. **Watchdog oMLX (Single-Model Guard):**
   - W systemie działa usługa `launchd` (`com.hermes.omlx-single-model-guard.plist`) wywołująca skrypt `~/.hermes/scripts/omlx-single-model-guard.py` co 180s.
   - Watchdog dba o to, by w RAM nie zalegały nieużywane modele. W Wariancie 2 model 27B posiada `is_pinned: true`, co chroni go przed wyładowaniem obok modelu 122B.

4. **Kalibracja Parametrów i Bezpieczeństwo:**
   - Sampling: `presence_penalty: 0.0` (ochrona formatów JSON/XML przed ucieczką tokenów), `repetition_penalty: 1.05` (dla modeli DeepSeek: `1.00`).
   - Rozumowanie: Odblokowany budżet myślenia (`thinking_budget_tokens: 32768`, `thinking_budget_enabled: false`).
   - Bezpieczeństwo i trwałość: `hard_stop_enabled: true`, `checkpoints.enabled: true`, `command_allowlist: []`, `lifetime_seconds: 1800`, `allow_lazy_installs: false`.

5. **Zarządzanie Pamięcią Masową (SSD vs HDD) i Skrypt `move_from_SSD_to_HDD.sh`:**
   - Na dysku SSD (`~/.lmstudio/models`) utrzymywane są modele najczęściej używane i o najwyższej wydajności, a rzadziej używane lub starsze wersje przenoszone są na zewnętrzny dysk USB-C (`/Volumes/Seagate_Expansion_Drive/LLM`).
   - Narzędzie [`./move_from_SSD_to_HDD.sh`](move_from_SSD_to_HDD.sh) automatycznie audytuje historię uruchomień modeli z wielu źródeł (rotowane logi oMLX `server.log*`, baza SQLite Hermes Agenta `state.db`, statystyki plików).
   - Skrypt proponuje kandydatów do zwolnienia miejsca na SSD (chroniąc modele `is_default` i `is_pinned`), bezpiecznie kopiuje/weryfikuje pliki na HDD, tworzy dowiązania symboliczne, automatycznie aktualizuje opisy o znacznik `[HDD]` w `model_settings*.json` i OpenCode oraz przeładowuje oMLX przez API.

6. **Synchronizacja i Git:**
   - Wszelkie modyfikacje plików konfiguracyjnych wykonuj w tym katalogu, a następnie synchronizuj do `~/.hermes/config.yaml` oraz `~/.omlx/` za pomocą `./switch-variant.sh`.
   - Zmiany zatwierdzaj i wypychaj do repozytorium GitHub: `https://github.com/wojcio/omlx_hermes_setup.git`.

## 🔄 Ostatnie Zmiany i Stan Projektu (Listopad 2026)
- **Dostosowanie `GLM-5.3-Flash-oQ2e-mtp` (512k + `temperature: 1.0`) po testach A/B z `oQ4e-mtp` (13 Listopada 2026):**
  * Przeprowadzono testy A/B `oQ2e-mtp` vs `oQ4e-mtp` oraz analizę sesji Hermesa `20261019_085129_ca310c`: potwierdzono przewagę `oQ4e` w złożonym rozumowaniu wielowarunkowym oraz zidentyfikowano fallback `effort: medium` $\rightarrow$ `Max` w `chat_template.jinja`.
  * Podniesiono okno kontekstu `GLM-5.3-Flash-oQ2e-mtp` z `262144` (256k) do **`524288` (512k)** oraz skorygowano `temperature` z `0.7` do **`1.0`** (zgodnie z natywnym `generation_config.json`) w [`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json), [`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json), [`config.variant1-single-model.yaml`](config.variant1-single-model.yaml), [`config.variant2-dual-model.yaml`](config.variant2-dual-model.yaml) oraz w dokumentacji (`README.md`, `konfiguracja-modeli.md`, `HowTo_JakUzywac.md`, `SESJA_KONTEKST.md`). `GLM-5.3-Flash-oQ4e-mtp` pozostawiono przy `262144` (256k) / `temperature: 0.7` ze względu na limit RAM (`173.7 GB` w RAM pod sufitem `186 GB`).
- **Trwały `LaunchDaemon` dla `iogpu.wired_limit_mb=186777` i powiadomienia macOS (13 Listopada 2026):**
  * **Architektura dwuczęściowa (`LaunchDaemon` + `LaunchAgent`):**
    - [`launchd/com.wojcio.iogpu-wired-limit.plist`](launchd/com.wojcio.iogpu-wired-limit.plist): systemowy `LaunchDaemon` (`/Library/LaunchDaemons/com.wojcio.iogpu-wired-limit.plist`) ustawiający przy starcie systemu `/usr/sbin/sysctl -w iogpu.wired_limit_mb=186777` (95% ze 192 GiB RAM = 182.4 GiB; zostawia ~9.6 GiB bufora dla kernela macOS i WindowServera).
    - [`launchd/com.wojcio.iogpu-wired-limit-notify.plist`](launchd/com.wojcio.iogpu-wired-limit-notify.plist) + [`launchd/iogpu-wired-limit-notify.sh`](launchd/iogpu-wired-limit-notify.sh): `LaunchAgent` sesji graficznej (`Aqua`) weryfikujący po zalogowaniu `sysctl -n iogpu.wired_limit_mb` i wyświetlający bąbelek powiadomienia macOS (`osascript`) z wpisem do `~/.omlx/logs/wired-limit-notify.log`.
    - [`./install-wired-limit-daemon.sh`](install-wired-limit-daemon.sh): skrypt instalujący oba komponenty (`sudo ./install-wired-limit-daemon.sh` dla `LaunchDaemon` w `/Library/LaunchDaemons/`).
- **Aktualizacja konfiguracji pod oMLX `0.8.0rc1` (build 3731, 13 Listopada 2026):**
  * **Migracja schematu `model_settings*.json` do `SETTINGS_VERSION = 2` oraz aktualizacja `model_profiles.json`:**
    - Przemigrowano [`model_settings.json`](model_settings.json), [`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json) oraz [`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json) przez `ModelSettingsManager` z oMLX `0.8.0rc1` (`version: 1` $\rightarrow$ `2`, jawne wartości domyślne m.in. `turboquant_kv_scheme: "turboquant"`, znormalizowane `turboquant_kv_bits` jako `float`, zachowana wyłączna różnica `is_pinned` w Wariancie 2).
    - Zsynchronizowano zmigrowany przez `0.8.0rc1` plik [`model_profiles.json`](model_profiles.json) (`qwen35_oq_a8_enabled` $\rightarrow$ `a8_prefill_enabled`, `turboquant_kv_scheme: "turboquant"`).
  * **Nowe globalne parametry serwera i schedulera w [`settings.json`](settings.json):**
    - Dodano `scheduler.concurrent_priority: "balanced"` (adaptacyjne dzielenie GPU między nowym prefillem a trwającym dekodowaniem) oraz `server.gpu_keep_warm_idle_window: 300.0` (podtrzymanie wybudzonego GPU po ostatnim żądaniu).
  * **Weryfikacja sprzętowa M2 Ultra (`applegpu_g14d`, 192 GB) i reload API:**
    - Potwierdzono `is_nax_available() == False` (`a8_prefill_enabled` pozostaje wyłączone, brak sprzętowych jednostek NAX z M5+) oraz pozostawiono `"turboquant"` zamiast `"affine4"`/`"affine8"` (kernele TensorOps wymagają M5+; na M2 Ultra `Affine4`/`Affine8` używa ścieżki portable z dekwantyzacją).
    - Zsynchronizowano konfigurację przez `./switch-variant.sh 1` i przeładowano serwer (`POST /admin/api/reload` $\rightarrow$ `200 OK`, `Loaded settings for 27 models`, `0` ostrzeżeń w `server.log`).
- **Narzędzie audytu użycia i bezpiecznej migracji modeli `move_from_SSD_to_HDD.sh` (12 Listopada 2026):**
  * **Wielopoziomowa agregacja historii użycia:**
    - Skrypt bada rotowane logi `~/.omlx/logs/server.log*` (milisekundowe znaczniki `Loading model:` i `Chat completion:`), bazę SQLite `~/.hermes/state.db` (tabele `sessions` i `session_model_usage`), a w ostateczności czasy modyfikacji plików `config.json` i wag `.safetensors`.
  * **Ochrona modeli krytycznych i kategoryzacja kandydatów:**
    - Chroni domyślny model (`is_default: true` -> `Qwen3.8-Flash-Next-oQ5e-mtp`) oraz przypięty kompresor Wariantu 2 (`is_pinned: true`).
    - Kategoryzuje modele na: mocnych kandydatów (>30 dni bezczynności, >20 GB), standardowych kandydatów (>14 dni), mało używanych (>7 dni) oraz aktywnych (<7 dni).
  * **Automatyzacja migracji i spójność ekosystemu:**
    - Wykrywa istniejące już kopie na HDD (unika ponownego kopiowania przez USB-C), kopiuje z wskaźnikiem postępu i weryfikacją sumaryczną, tworzy dowiązania symboliczne w `~/.lmstudio/models/<org>/<model>`, automatycznie oznacza modele jako `[HDD]` w konfiguracjach oMLX i OpenCode oraz wysyła żądanie `POST /admin/api/reload` do oMLX.
- **Wdrożenie 7 nowych modeli MLX/MTP (Gemma 4, GLM 5.3 Flash 320B, Qwen 3.8 oQ6e, Bonsai-2, Nanbeige 4.3), podniesienie sufitu pamięci do 186 GB oraz archiwizacja `[HDD]` (12 Listopada 2026):**
  * **Odblokowanie 186 GB RAM dla GPU Metal i pełna rezydentność `GLM-5.3-Flash-oQ4e-mtp` (173.86 GB):**
    - Po ustawieniu `iogpu.wired_limit_mb=186777`, w `settings.json` skonfigurowano `"prefill_memory_guard": false`, `"memory_guard_tier": "custom"` oraz `"memory_guard_custom_ceiling_gb": 186.0`, co pozwoliło załadować 320-miliardowy model `GLM-5.3-Flash-oQ4e-mtp` w 100% do RAM bez SSD expert offloadu.
  * **Archiwizacja 3 starszych modeli Qwen na dysk USB-C (`/Volumes/Seagate_Expansion_Drive/LLM`) z oznaczeniem `[HDD]`:**
    - Przeniesiono / podlinkowano `Qwen3-235B-A22B-MLX-4bit` (116G), `Qwen3-Coder-Next-MLX-9bit` (83G) oraz `Qwen3.5-122B-A10B-MLX-9bit` (128G) na zewnętrzny dysk Seagate HDD, odzyskując **328 GiB** na wewnętrznym SSD (łącznie z czyszczeniem cache HF odzyskano ~497 GiB; po pobraniu 7 nowych modeli pozostało **650.2 GiB** wolnego miejsca na SSD).
    - Zachowano wszystkie 3 modele w oMLX oraz OpenCode z widocznym oznaczeniem **`[HDD]`**, a domyślny model Hermesa i oMLX przełączono na rezydentny na SSD `Qwen3.8-Flash-Next-oQ5e-mtp`.
  * **Dodanie i profilowanie 7 nowych modeli w Hermes Agent (łącznie 25 modeli), oMLX (27 modeli) i OpenCode (27 modeli):**
    1. `Qwen3.8-Flash-Next-oQ6e-mtp` (`Jundot/`, 6-bit iMatrix VLM, 141.1 GB RAM): `activation_fp16_enabled: true`, Lightning MTP (69.7%, `2.59 tok/cykl`), **60.6–63.9 tok/s**, TTFT **0.58s**. (Wariant `WLSRefit-MTP` usunięto po benchmarku jako wolniejszy: 62.1 tok/s vs 67.5–73.0 tok/s dla `oQ5e-mtp`).
    2. `GLM-5.3-Flash-oQ4e-mtp` (`Jundot/`, 320B MoE / 18B akt., `glm5_next`, VLM, 173.9 GB RAM): Fused KDA prework, Lightning MTP (82.5%, `3.00 tok/cykl`), **TTFT 0.17s** (`bf16`), **25.9–29.9 tok/s**.
    3. `GLM-5.3-Flash-oQ2e-mtp` (`Jundot/`, 320B MoE / 18B akt., 2-bit eksperci + 4-bit router/shared/MTP, VLM, **102.9 GB RAM**): oszczędza **71 GB RAM** względem `oQ4e`, ładuje się w ~16s i generuje **32.1–37.6 tok/s** przy zachowaniu czystego kodu i rozumowania.
    4. `gemma-4-12B-it-oQ8e-mtp` (`Jundot/`, `gemma4_unified` Any-to-Any VLM/Audio, 13.0 GB RAM): `activation_fp16_enabled: true`, Lightning MTP (80.3–92.4%, depth `d8`), **51.4–68.4 tok/s**, TTFT **0.60s**.
    5. `gemma-4-31B-it-oQ6e-mtp` (`Jundot/`, Dense 31B VLM, 26.3 GB RAM): `activation_fp16_enabled: true` (+42% speedup), `gemma4_verify_kernel`, Lightning MTP (88.4%, `4.38 tok/cykl`), **32.4–34.0 tok/s**, TTFT **0.93s**.
    6. `Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed` (`Youssofal/`, 2-bit Hadamard 27B VLM, **8.23 GB RAM**): **31.4 tok/s**, TTFT **0.77s**.
    7. `Nanbeige4.3-33B-MLX-6bit` (`PocketAiHub/`, Dense 33B, 25.2 GB RAM): okno kontekstu **524 288 tokenów (512k)**, **19.6 tok/s**, TTFT **0.93s**.
- **Aktualizacja silnika do Splash M1 1.6.0-m1, uzupełnienie `"activation_fp16_enabled": true` dla `Qwen3.8-Flash-Next-oQ5e-mtp` oraz wyróżnienie Qwen 3.8 Flash w OpenCode (6–7 Listopada 2026):**
  * **Aktualizacja do `Splash 1.6.0-m1` (`/opt/homebrew/bin/splash-m1`):**
    - Zaktualizowano silnik z `1.5.0-m1` do **`1.6.0-m1`** (`paperniuk/splash`), wnoszącego zarządcę pamięci `One memory ledger`, selektywne utrzymywanie rezydentnego KV cache tylko dla czytanych bloków (`Idle KV` #644), zespolony przebieg `MoE gate + up` (#45), `staged hyper-connection norm` (#46), próg prefillu ANE od 128 wierszy (#49), automatyczny restart silnika oraz odporność `--model-dir` na pliki `.DS_Store` (#42).
    - Przeprowadzono ponowną kalibrację podziału GPU + Neural Engine dla `1.6.0-m1` na Mac Studio M2 Ultra (`share 0.26` dla $\ge 551$ wierszy: **54.1 ms** GPU+ANE vs **70.0 ms** sam GPU) oraz przetestowano `Qwen3.8-27B-Uncensored-MLX-SPLASH` w pętli wieloturowej z cache SSD (**50.2–62.0 tok/s**, `3.0–3.5 tok/cykl`, TTFT **0.39–0.58 s**).
  * **Trwały zapis `"activation_fp16_enabled": true` dla `Qwen3.8-Flash-Next-oQ5e-mtp` i weryfikacja produkcyjna w OpenCode (do 225k kontekstu):**
    - Dodano brakujący klucz `"activation_fp16_enabled": true` bezpośrednio do wpisu `Qwen3.8-Flash-Next-oQ5e-mtp` we wszystkich wariantach [`model_settings.json`](model_settings.json), [`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json), [`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json) oraz `~/.omlx/model_settings.json`.
    - W rzeczywistej wielogodzinnej sesji OpenCode (ponad 185 tur narzędziowych, okno rosnące aż do **225 280 tokenów** wraz z późniejszą kompresją kontekstu) model `Qwen3.8-Flash-Next-oQ5e-mtp` utrzymał stabilną prędkość **42.3 – 58.8 tok/s** (przy 218.8k kontekstu: **51.9 tok/s**, `3.11 tok/cykl`, TTFT **3.29s**; po kompresji przy 73k–106k kontekstu: **49.9 – 58.8 tok/s**, do `4.50 tok/cykl`, TTFT **1.38–2.19s**).
  * **Konfiguracja OpenCode (`/Users/wojcio/Desktop/Devel/opencode_omlx` oraz `~/.config/opencode`):**
    - Przesunięto oba modele `Qwen3.8-Flash-Next` na szczyt listy, dodano etykiety z aliasem `(Qwen 3.8 Flash · ...)`, uzupełniono listę `favorite` (oba `Qwen3.8-Flash-Next` + oba `DeepSeek-V4-Flash`) oraz usunięto wycofane w OpenCode 2.2.5 pole `"attachment": true`.
- **Wdrożenie oMLX 0.7.4.dev1 (build 3628), Splash M1 1.5.0-m1 oraz optymalizacja `activation_fp16_enabled` dla Qwen3.8-Flash-Next (4 Listopada 2026):**
  * **Aktualizacja binariów i walidacja schematu:**
    - Zweryfikowano `oMLX 0.7.4.dev1` (build `3628`, `MLX 0.32.4`, `mlx-lm 0.32.3.dev8`, `mlx-vlm 0.7.11`) – wszystkie 20 modeli w `model_settings.json` przechodzi walidację 86-polowego schematu `ModelSettings` z `0` błędami i `0` nieznanymi kluczami.
    - Zaktualizowano `/opt/homebrew/bin/splash-m1` z wersji `1.4.0-m1` do **`1.5.0-m1`** (`paperniuk/splash`), wnoszącej upstreamowe wydania `1.4.1`/`1.5.0`, optymalizację `Prefill Tail` i ANE (#32, -30–70 ms TTFT), skalowaną z 60 rdzeniami GPU atencję długiego kontekstu (#33, +3.5% przy 64k i +7.4% przy 128k), poprawki `Host Steps` (#38), `Column Tile for MoE` (#29) i skwantyzowane routery MoE (#599).
    - Skalibrowano Neural Engine FFN split w Splash 1.5.0-m1 (`share 0.26` dla $\ge 529$ wierszy, 53.1 ms GPU+ANE vs 70.1 ms sam GPU) i zweryfikowano `Qwen3.8-27B-Uncensored-MLX-SPLASH` w oMLX oraz Hermes CLI (**60.5 tok/s**, `3.5 tok/cykl`, deduplikacja bloków cache).
  * **Diagnoza i naprawa kernela `attn_fused` (PR #4901) na M2 Ultra dzięki `activation_fp16_enabled: true`:**
    - Wykryto, że nowy dwuprzebiegowy kernel `omlx_qwen4_attn_sdpa2_gate` (`plan=2` w `attn_fused.py`, PR #4901) w emulowanym na M2 Ultra trybie `bfloat16` przekracza limit rejestrów/wątków grupy (`ValueError: Thread group size (1024) is greater than the maximum allowed threads per threadgroup (896)`) i wyłącza cały moduł `attn_fused`.
    - Włączenie nowej opcji **`"activation_fp16_enabled": true`** dla `Qwen3.8-Flash-Next-oQ5e-mtp` oraz `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` konwertuje liście `bfloat16 -> float16` (2 471 tensorów), aktywuje natywne ścieżki FP16 (PR #5028), pozwala skompilować oba plany `attn_fused` (`plan=1` i `plan=2`) bez błędów i przyspiesza generowanie w fazie czystego rozumowania z `39.62 tok/s` do **`62.56 tok/s`** (+58%, TTFT `0.48s`) oraz do **~97 tok/s** na kodzie.
    - Przeprowadzono audyt kompatybilności `activation_fp16_enabled` dla pozostałych architektur: potwierdzono, że `deepseek_v4` (`wsdpa_attention.py`) i gęste `qwen3_5` (`qwen35_packed_linear.py`) wymagają `bfloat16`, dlatego flagę włączono selektywnie tylko dla modeli `qwen4_exp` (`Qwen3.8-Flash-Next-*`).
- **Wdrożenie nowego modelu `flint-oQ8e` (Recursive Flint MoE 39.8B) – Lider Autonomicznego Kodowania i Tool-Use (28 Października 2026):**
  * **Identyfikacja modelu i architektura:**
    - Dodano do konfiguracji `flint-oQ8e` (`mlx-community/flint-oQ8e`) bazujący na architekturze `FlintForCausalLM` autorstwa Recursive Superintelligence (zespół Richarda Sochera).
    - MoE o łącznej liczbie 39.8 miliarda parametrów z aktywacją **2.5 miliarda parametrów na token** (256 ekspertów, top-6 active + shared expert), 49 warstw hybrydowych (sliding window 513 oraz full attention), pełne okno kontekstu **262 144 tokenów (256k)**.
    - Format oQ8e (kwantyzacja iMatrix 8-bit affine, waga na dysku i w RAM: ~39.4 GB).
  * **Integracja z oMLX 0.7.3rc1:**
    - Model automatycznie obsługiwany przez `VLMBatchedEngine` (`VLM_NATIVE_TEXT_MODEL_TYPES = {"flint"}`).
    - Wykorzystuje dedykowany zespolony kernel dekodowania MoE oMLX: `apply_flint_decode_patch()` (`omlx_flint_router_topk` + weighted combine) oraz buforowanie rotacyjne KV (`RotatingKVCache`).
    - Skonfigurowano optymalne parametry w `model_settings.json` (max_context: 256k, max_tokens: 32k, temp: 0.6, top_p: 0.95, top_k: 20, rep: 1.05, min_p: 0.01, pres: 0.0, TurboQuant KV 8-bit `skip_last`).
  * **Wydajność i weryfikacja w Hermes Agent:**
    - Przetestowano za pośrednictwem API oMLX oraz Hermes CLI (`hermes -m flint-oQ8e -z "..."`).
    - Szybkość dekodowania wynosi imponujące **54.8 – 74.1 tok/s**, a prefill osiąga **607 tok/s** (TTFT: 0.26s).
    - Zweryfikowano bezbłędne wykonywanie wieloetapowych wywołań narzędzi (tool calls) oraz poprawną separację bloków rozumowania `<think>` do pola `reasoning_content`.
  * **Synchronizacja konfiguracji:**
    - Zaktualizowano `config.variant1-single-model.yaml`, `config.variant2-dual-model.yaml`, `config.yaml`, `model_settings.json`, `~/.hermes/config.yaml` oraz `~/.omlx/model_settings.json`.
    - Liczba modeli w konfiguracji Hermesa wzrosła do dokładnie **18**, a łączna liczba wpisów w `model_settings.json` wynosi **20** (18 modeli Hermesa + 2 lokalne modele Huzar).
- **Wdrożenie oMLX 0.7.3rc1, Apple MLX 0.32.4 oraz Splash M1 1.4.0-m1 – Profilowanie Kompresora Wariantu 2 i Architektury Flash-Next (27 Października 2026):**
  * **Aktualizacje binariów:**
    - oMLX podbity do oficjalnego wydania **`0.7.3rc1`** (build `261027180332`) bazującego na **Apple MLX `0.32.4`**, `mlx_metal 0.32.4`, `mlx-lm 0.32.3.dev8` (`0d4d3d04`) oraz `mlx-vlm 0.7.10`.
    - Zaktualizowano launcher `/opt/homebrew/bin/splash-m1` do najnowszej wersji **`1.4.0-m1`** (`paperniuk/splash`), wnoszącej buforowanie query w pamięci threadgroup oraz uaktualnione kernele Metal dla M1/M2.
    - Zweryfikowano zgodność ze schematem `ModelSettings` (wszystkie 19 modeli: 0 błędów).
  * **Changelog & Wpływ na konfigurację:**
    - **TurboQuant KV & Sinks (PR #4856):** Zespolony kernel decode przyjmuje bufor `sinks: mx.array`, rozwiązując problem wyłączania TurboQuant na głębokim oknie (>200k) w `DeepSeek-V4-Flash-0731-MXFP4-MLX`.
    - **Flash-Next Decode Speedup (PR #4880):** Optymalizacja pętli dekodowania architektury Qwen4/Flash-Next.
    - **Metal Timeout Preemption (PR #4872):** Relaksacja limitu context store na procesorach M1/M2 Ultra zapobiega timeoutom `Metal 0000000e` przy długich prefillach (256k).
    - **Hermes Agent Safety (PR #4869):** Kod błędu `incomplete_tool_call` zabezpiecza pętlę agenta przed uciętymi wywołaniami narzędzi.
    - **Unlimited-OCR (PR #4822):** Usunięto powielanie tagów `<image>`.
  * **Architektura Qwen3.8-Flash-Next (oMLX w 192 GB RAM vs Splash GGUF):**
    - Potwierdzono, że Splash wymaga dla Flash-Next formatu GGUF (`_GGUF_ONLY_FAMILIES`) i stosuje kompromisowe strumieniowanie 30-gigabajtowej tablicy n-gramów PLE z dysku SSD (`--ple-memory 2G`), dedykowane dla maszyn $\le$64 GB RAM (~47 tok/s).
    - Na Mac Studio z **192 GB RAM** modele natywne MLX safetensors (`oQ5e-mtp` oraz `Optimized-Speed`) mieszczą się w 100% w RAM i w oMLX z Lightning MTP osiągają aż **73.5 – 75+ tok/s**, deklasując warianty SSD.
  * **Benchmark Wariantu 2 (Dedykowany Kompresor Splash 1.4.0-m1):**
    - Przetestowano kompresję rzeczywistego kontekstu rozmowy (2 168 tokenów): generowanie podsumowań przyspieszyło z 42.7 tok/s do **63.99 tok/s** (+49.8%), TTFT wyniósł **0.31s**, akceptacja DFlash2 **3.92 tok/cykl**, a czas całej kompresji zamknął się w **10.50 s**.
    - Model główny `Qwen3.5-122B` (~92 GB) + kompresor `Qwen 27B Splash` (~15.2 GB, `is_pinned: true`) = **~107 GB**, pozostawiając ~85 GB na bufory. Watchdog `omlx-single-model-guard` zachowuje oba modele.
    - Udokumentowano zasadę: dla kolosów >150 GB (`DeepSeek-V4-Flash MXFP4`, `MiniMax-M3`) należy bezwzględnie używać **Wariantu 1** (Zero-Swap), aby nie przekroczyć sufitu pamięci oMLX (178.5 GB).
- **Weryfikacja kompatybilności z oMLX 0.7.3.dev2 oraz profilowanie prędkości `DeepSeek-V4-Flash-0731-MXFP4-MLX` w funkcji kontekstu:**
  * Zweryfikowano pełną zgodność wszystkich 19 wpisów w [`model_settings.json`](model_settings.json) ze schematem `ModelSettings` w **oMLX `0.7.3.dev2`** (`0` błędów walidacji, `0` nieznanych kluczy).
  * Udokumentowano w [`README.md`](README.md), [`konfiguracja-modeli.md`](konfiguracja-modeli.md), [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md) oraz [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md) automatyczne korzyści z oMLX `0.7.3.dev2` (`mlx-vlm 0.7.10`): szybszy DFlash2 (`+16%` do `+33%` tok/s) dzięki przebiegowi draftera `bf16` w `fp16` z akumulacją rezydualną `fp32` dla modeli 27B (`Qwen3.8-27B-Uncensored-MLX`, `Qwen3.8-27B-FP16_huzar_v1`), zespolone kernele dekodowania dla `MiniMax-M3-ConfigI-MLX` (`+14%` do `+23%` decode), udoskonalony *batch park backoff* w Lightning MTP oraz poprawki parsowania `<think>`, obsługi `tool_choice: none` i obrazów MCP/VLM.
  * Przeprowadzono analizę logów `server.log` wyjaśniającą spadek prędkości `DeepSeek-V4-Flash-0731-MXFP4-MLX` z **31.0–34.6 tok/s** (przy `<45k` kontekstu) do **21.0–23.7 tok/s** (przy `213k–232k` kontekstu): potwierdzono brak regresji w `0.7.3.dev2` (po kompresji kontekstu do `66.7k` prędkość natychmiast wraca do **30.0 tok/s**). Spadek na głębokim kontekście wynika z automatycznego wyłączenia TurboQuant KV przez *attention sinks* (`fp16` KV cache przy `158.84 GB` wag modelu i aktywacji *Soft memory pressure* `164.3 GB`), wydłużenia kroku `backbone` z `~95 ms` do `~128 ms` oraz niższej akceptacji wbudowanego draftera `embedded DSpark` MTP (`80–84%` vs `91–96%`) podczas generowania długich struktur `tool_calls`.
- **Aktualizacja dokumentacji projektu (`.md`) pod oMLX 0.7.2 i Splash 1.3.2-m1.2 oraz przebudowa tabel pod GitHub:**
  * Zaktualizowano [`README.md`](README.md), [`konfiguracja-modeli.md`](konfiguracja-modeli.md), [`HowTo_JakUzywac.md`](HowTo_JakUzywac.md) oraz [`SESJA_KONTEKST.md`](SESJA_KONTEKST.md) o wszystkie wprowadzone optymalizacje akceleracji sprzętowej (Splash 1.3.2-m1.2 z podziałem GPU/ANE `share 0.26`, Lightning MTP, DFlash2, Fused MoE & GDN `qwen4_gdn_decode_wide_proj`, 100 skompilowanych ścieżek Affine `hc_fused` w `Qwen3.8-Flash-Next-oQ5e-mtp`, TurboQuant KV `skip_last` oraz natywny parser `laguna`).
  * Przebudowano obie tabele w [`konfiguracja-modeli.md`](konfiguracja-modeli.md) (redukcja z 11 do 5 kolumn w Tabeli 1 oraz z 6 do 4 kolumn w Tabeli 2, złamanie 95-znakowych identyfikatorów `Coder390`), aby mieściły się w 100% szerokości widoku GitHub bez ucinania prawej krawędzi.
- **Pełny audyt i optymalizacja wszystkich 17 modeli Hermesa (+ 2 lokalnych Huzar) pod oMLX 0.7.2 i Splash 1.3.2-m1.2:**
  * **`Qwen3.8-27B-Coder390-...-MTP-DFlash2` (naprawa krytycznego konfliktu walidacji oMLX 0.7.2):**
    - Usunięto konflikt równoczesnego włączenia `mtp_enabled: true`, `dflash_enabled: true` i `vlm_mtp_enabled: true`, który powodował odrzucenie całej konfiguracji modelu przez `ModelSettings.from_dict()` przy starcie oMLX.
    - Pozostawiono natywne **`mtp_enabled: true`** (wbudowana głowica `mtp-bf16.safetensors` dopasowana do destylacji Coder390) oraz `turboquant_kv_enabled: true` (`8.0` bit, `skip_last: true`).
  * **`Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` (naprawa błędu HTTP 400 w UI/API i akceleracja GDN):**
    - Wyłączono `mtp_enabled: false` (plik sidecar `mtp.safetensors` ma kontrakt `qwen4-next`, co blokowało zapisywanie jakichkolwiek ustawień modelu w oMLX 0.7.2 błędem 400; model korzysta z natywnej tablicy `ngram-table.safetensors`).
    - Włączono nową flagę oMLX 0.7.2 **`qwen4_gdn_decode_wide_proj: true`**, dopuszczającą projekcje 4-bit/gs32 do scalonego kernela dekodowania GDN (`Qwen4 fused B1/T1 GDN decode prework`).
  * **`Qwen3.8-27B-Uncensored-MLX` oraz `Qwen3.8-27B-FP16_huzar_v1` (natywne warianty MLX):**
    - Podpięto lokalny model pomocniczy **`dflash_draft_model: "Qwen3.8-27B-DFlash2"`** przy `dflash_enabled: true` (wcześniej brak jawnego `dflash_draft_model` powodował wyłączenie DFlash przy starcie) oraz ujednolicono kompresję KV 8-bit (`turboquant_skip_last: true`).
  * **`Qwen3-235B-A22B-MLX-4bit`, `Laguna-S-2.1-MLX-8bit`, `Qwen3.5-122B-A10B-MLX-9bit` i pozostałe modele:**
    - Włączono kompresję KV 8-bit (`turboquant_kv_enabled: true`, `bits: 8.0`, `skip_last: true`) dla giganta `Qwen3-235B-A22B-MLX-4bit` (oszczędność połowy pamięci KV przy oknie 256k).
    - Usunięto przestarzałe klucze `dflash_in_memory_cache*`/`dflash_ssd_cache*` z `Qwen3.5-122B` oraz nieobsługiwany w xgrammar `reasoning_parser: "poolside_v1"` z `Laguna-S-2.1` (oMLX 0.7.2 automatycznie przypisuje natywny parser `laguna`), dzięki czemu wszystkie 19 modeli przechodzi walidację `PUT /admin/api/models/{id}/settings` ze statusem `200 OK`.
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
