# 🧠 Kontekst Sesji Projektowej: oMLX & Hermes Setup

**Data sesji:** 30–31 sierpnia 2026  
**Lokalizacja projektu:** `/Users/wojcio/Desktop/omlx_hermes_config`  
**Zdalne repozytorium:** [https://github.com/wojcio/omlx_hermes_setup.git](https://github.com/wojcio/omlx_hermes_setup.git)  
**Środowisko:** macOS Apple Silicon (Mac Studio M2 Ultra, 192 GB Unified Memory), oMLX Server, Hermes Agent.

---

## 🎯 1. Cel i Zakres Prac w Tej Sesji

1. **Kalibracja okien kontekstu i parametrów samplingu:**
   - Przeanalizowano wszystkie 15 modeli LLM/VLM zainstalowanych lokalnie w `/Users/wojcio/.lmstudio/models`.
   - Odblokowano pełny natywny kontekst **262 144 tokenów (256k)** dla modelu głównego `Qwen3.5-122B-A10B-MLX-9bit` (wcześniej był sztucznie ograniczony do 70k).
   - Skalibrowano parametry samplingu: `temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty` per model.

2. **Analiza i weryfikacja Watchdoga oMLX:**
   - Zidentyfikowano skrypt i usługę `launchd` pilnującą zasady *"at most ONE model loaded in memory at a time"*.
   - Zweryfikowano odporność na długie generowanie (>180s) – potwierdzono brak ryzyka przedwczesnego wyładowania aktywnego modelu dzięki regule `len(loaded) <= 1`, aktualizacji `last_access` oraz blokadom `in_use lease` w silniku oMLX.
   - Utworzono dokumentację projektu w Obsidianie: `Gemini/Projekty/Watchdog-oMLX.md`.

3. **Diagnoza i naprawa problemów z kompresją kontekstu w Hermesie:**
   - Na podstawie analizy logów `~/.hermes/logs/agent.log` zdiagnozowano 3 przyczyny uznawania modelu za nieaktywny podczas kompresji przy dużym kontekście (~175k tokenów):
     1. Zbyt krótki timeout bezczynności (`context_timeout_seconds: 120s`) przy długim prefillu modelu 122B.
     2. Wykrywanie okna kompresora jako 50k tokenów (poniżej wymaganego przez Hermesa progu 64k).
     3. Awaryjne próby routingu do OpenRoutera kończące się błędami 402 (brak środków) i 400 (przekroczenie 32k okna).
   - Zwiększono timeouty kompresji (`context_timeout_seconds: 300s`, `context_total_ceiling_seconds: 1200s`, `auxiliary.compression.timeout: 360s`) i skierowano kompresję na stałe do lokalnego oMLX z oknem 256k.

4. **Architektura dwóch wariantów wykonawczych:**
   - **Wariant 1 (Domyślny / Zero-Swap Monolith):** `Qwen3.5-122B` jako model główny i kompresor (0s opóźnienia przełączania).
   - **Wariant 2 (Dual-Model Resident):** `Qwen3.5-122B` jako główny + `Qwen3.8-27B-Uncensored-MLX` (~15 GB w RAM, `is_pinned: true`) jako szybki, lekki kompresor.
   - Stworzono skrypt bash [`switch-variant.sh`](switch-variant.sh) do automatycznego przełączania wariantów.

5. **Audyt i Kalibracja Parametrów Agentowych (Optymalizacje Jakości i Bezpieczeństwa):**
   - **Korekta `presence_penalty: 0.0`:** Usunięto omyłkowo skopiowaną wartość `1.05` z repetition penalty. Agresywna kara presence penalty wypychała model ze stałych struktur JSON/XML, degradując wywołania narzędzi.
   - **Budżet rozumowania (`thinking_budget_tokens: 32768` / `thinking_budget_enabled: false`):** Odblokowano pełny budżet myślenia, zapobiegając ucinaniu planowania w złożonych, wieloetapowych zadaniach agentowych.
   - **Guardrails pętli narzędzi (`hard_stop_enabled: true`):** Włączono twardy stop zapobiegający nieskończonemu zapętleniu agenta na błędach narzędzi.
   - **Migawki plików (`checkpoints.enabled: true`):** Włączono mechanizm automatycznych snapshotów plików przed mutacjami.
   - **Bezpieczeństwo (`command_allowlist: []`, `allow_lazy_installs: false`):** Usunięto niebezpieczne wyjątki z allowlisty oraz zablokowano samowolne instalacje pakietów w tle.
   - **Trwałość sesji i terminala (`lifetime_seconds: 1800`, `sessions.auto_prune: true`):** Wydłużono czas życia powłoki do 30 min oraz włączono bezpieczne czyszczenie sesji po 90 dniach.

6. **Mapowanie Repozytoriów Hugging Face dla Wszystkich Modeli:**
   - Zidentyfikowano źródłowe repozytoria i organizacje na Hugging Face dla wszystkich 15 modeli lokalnych z `~/.lmstudio/models`.
   - Zintegrowano bezpośrednie linki w tabeli zbiorczej oraz dodano dedykowaną sekcję wykazu repozytoriów w `konfiguracja-modeli.md` i zaktualizowano `README.md`.

7. **Rozwiązanie Problemu Kompresora (Dynamiczny Model Sesji / Zero-Swap):**
   - Zdiagnozowano przyczynę ciągłego wymuszania modelu `Qwen3.5-122B`: demon w tle `com.hermes.omlx-compression-sync` co 60s nadpisywał `auxiliary.compression.model`.
   - Wyłączono i usunięto demona `com.hermes.omlx-compression-sync`.
   - W Wariancie 1 skonfigurowano `auxiliary.compression.provider: auto` i `model: ""` – dzięki temu Hermes natywnie i dynamicznie kompresuje kontekst za pomocą modelu aktualnie aktywnego w danej sesji (0s swap latency, zero przeładowań dla każdego z 15 modeli).

---

## 🗂️ 2. Struktura Plików w Repozytorium

| Plik | Opis i Przeznaczenie |
| :--- | :--- |
| **`config.yaml`** | Aktywna konfiguracja Hermes Agenta (`~/.hermes/config.yaml`). |
| **`config.variant1-single-model.yaml`** | Wzorzec konfiguracji Hermesa dla Wariantu 1 (Zero-Swap). |
| **`config.variant2-dual-model.yaml`** | Wzorzec konfiguracji Hermesa dla Wariantu 2 (Dual-Model 27B). |
| **`model_settings.json`** | Aktywny rejestr modeli oMLX (`~/.omlx/model_settings.json`). |
| **`model_settings.variant1-single-model.json`** | Ustawienia oMLX dla Wariantu 1. |
| **`model_settings.variant2-dual-model.json`** | Ustawienia oMLX dla Wariantu 2 (`Qwen 27B` z `is_pinned: true`). |
| **`model_profiles.json`** | Profile oMLX (`work`, `turbo`, `setup`) z pełnym 256k oknem i TurboQuant KV 8-bit (`~/.omlx/model_profiles.json`). |
| **`settings.json`** | Globalne parametry serwera oMLX i sampling domyślny (`~/.omlx/settings.json`). |
| **`switch-variant.sh`** | Skrypt CLI do przełączania wariantów (`./switch-variant.sh 1` lub `2`). |
| **`konfiguracja-modeli.md`** | Pełna dokumentacja techniczna 15 modeli, tabel parametrów i wariantów. |
| **`README.md`** | Główne wprowadzenie do repozytorium GitHub. |
| **`SESJA_KONTEKST.md`** | Ten plik – zachowanie pełnego kontekstu wiedzy i decyzji sesji. |

---

## ⚙️ 3. Zależności i Ścieżki Systemowe

- **Hermes Agent Config:** `/Users/wojcio/.hermes/config.yaml`
- **Hermes Agent Logs:** `/Users/wojcio/.hermes/logs/agent.log`, `/Users/wojcio/.hermes/logs/errors.log`
- **oMLX App & Server:** `/Applications/oMLX.app`, binarka `/Applications/oMLX.app/Contents/MacOS/oMLX`
- **oMLX Config Directory:** `/Users/wojcio/.omlx/` (`settings.json`, `model_settings.json`, `model_profiles.json`)
- **Modele LLM/MLX:** `/Users/wojcio/.lmstudio/models/`
- **Watchdog Skrypt:** `/Users/wojcio/.hermes/scripts/omlx-single-model-guard.py`
- **Watchdog Launchd Plist:** `/Users/wojcio/Library/LaunchAgents/com.hermes.omlx-single-model-guard.plist`
- **Watchdog Log:** `/Users/wojcio/.omlx/logs/single-model-guard.log`
- **Obsidian Vault (Gemini):** `/Users/wojcio/Library/Mobile Documents/iCloud~md~obsidian/Documents/Gemini/`
  - Notatka projektu: `Gemini/Projekty/Watchdog-oMLX.md`
  - Indeks główny: `Gemini/00-INDEX.md`

---

## 🤖 4. Wskazówki dla Asystenta AI (Dla Kolejnych Sesji)

1. **Praca w katalogu projektu:** Wszelkie zmiany w konfiguracji Hermes/oMLX należy wprowadzać w `/Users/wojcio/Desktop/omlx_hermes_config` i synchronizować skryptem `./switch-variant.sh [1|2]` do katalogów domowych `~/.hermes` i `~/.omlx`.
2. **Git Workflow:** Po edycji plików zawsze wykonuj commit i push do `https://github.com/wojcio/omlx_hermes_setup.git`.
3. **Pamięć o Watchdogu:** Jeśli dodajesz nowy model pomocniczy do współistnienia w RAM obok modelu 122B, pamiętaj o ustawieniu `"is_pinned": true` w `model_settings.json`, aby demon `com.hermes.omlx-single-model-guard` go nie wyładował.
4. **Duży kontekst (256k):** Modele Qwen3.5/3.8 mają pełne okno 262 144 tokenów. Przy operacjach na kontekście >100k tokenów prefill zajmuje do kilkudziesięciu sekund – timeouty w `compression` muszą wynosić minimum 300s.

---

## 🆕 5. Aktualizacja: Rozszerzenie Bazy do 18 Modeli (Wrzesień 2026)

W sesji wrześniowej zidentyfikowano i włączono do konfiguracji oMLX oraz Hermes Agenta 3 nowe modele zrzucone lokalnie do `~/.lmstudio/models`:
1. **`Qwen3.8-Flash-Next-oQ5e-mtp` (`GBP-DE`)**:
   - Format `oQ5e` (Optimum Quantized 5-bit z iMatrix) z akceleracją Multi-Token Prediction (MTP).
   - Pełne okno kontekstu: 262 144 tokenów (256k), max output: 32 768.
   - Architektura Qwen 4 Exp, wysoka wydajność i jakość.
2. **`Qwen3.8-27B-FP16_huzar_v1` (`huzar`)**:
   - Lokalny fine-tune bazy wiedzy Huzar na pełnych wagach FP16 (~27 GB RAM).
   - Pełne okno kontekstu 256k z odblokowanym myśleniem (`enable_thinking: true`).
3. **`Bielik-11B-v3.0-Huzar-MLX-8bit-v1` (`huzar`)**:
   - Lokalny fine-tune bazy wiedzy Huzar na polskim modelu Bielik 11B (LLaMA architecture).
   - Natywne okno 32 768 tokenów (32k), max output: 8 192.

Wszystkie parametry zostały wprowadzone do obu wariantów (`variant1-single-model`, `variant2-dual-model`), zsynchronizowane za pomocą `./switch-variant.sh 1` i zweryfikowane w aktywnym serwerze oMLX oraz CLI Hermesa (`hermes config get providers.omlx.models`).

4. **Wykrywanie oMLX i obsługa zdalnego serwera (`.env` / Tailscale VPN):**
   - Skrypt `switch-variant.sh` wzbogacono o automatyczną detekcję lokalnej obecności oMLX (`omlx` w PATH, `/Applications/oMLX.app`, `~/.omlx/bin/omlx`).
   - Gdy oMLX nie jest obecny lokalnie (lub gdy przekazano flagę `--remote`), skrypt automatycznie przełącza konfigurację Hermesa (`model.base_url`, `providers.omlx.base_url`, `compression.base_url`) na adres zdalny zdefiniowany w `.env` (domyślnie `100.123.37.101:8000` – prywatny serwer właściciela repozytorium via Tailscale VPN).
   - Pomijane jest wtedy kopiowanie konfiguracji do `~/.omlx/`, a klucz `OMLX_API_KEY` jest automatycznie zapewniany w `~/.hermes/.env`.
   - Utworzono pliki `.env` oraz `.env.example` z odpowiednim komentarzem informacyjnym dla innych użytkowników repozytorium.

---

## 🔍 4. Rozszerzenie Bazy o Modele Wizyjne OCR (Wrzesień 2026)

Do ekosystemu dołączono dwa wyspecjalizowane modele typu **VLM (Vision-Language Model)** dedykowane zaawansowanemu OCR dokumentów, faktur i tabel, rozszerzając zestaw z 18 do **20 modeli**:

1. **`olmOCR-2-7B-1025-8bit` (`mlx-community` / `allenai`)**:
   - Model multimodalny bazujący na architekturze `qwen2_5_vl` (`Qwen2_5_VLForConditionalGeneration`).
   - Zoptymalizowany przez AllenAI do precyzyjnej transkrypcji skomplikowanych dokumentów PDF, tabel, wielokolumnowych układów i wzorów matematycznych bezpośrednio do Markdowna.
   - Kontekst: **128 000 tokenów (128k)**, limit wyjściowy: **8 192 tokenów**.
   - Sampling OCR: `temperature: 0.2`, `top_p: 0.90`, `top_k: 20`, `repetition_penalty: 1.05`, `model_type_override: "vlm"`.
   - Waga modelu: kwantyzacja MLX 8-bit (~8.8 GB).

2. **`Unlimited-OCR-8bit` (`mlx-community` / `baidu`)**:
   - Model multimodalny `unlimited-ocr` (`UnlimitedOCRForCausalLM`) bazujący na szkielecie DeepSeek-V2 MoE z autorskim enkoderem wizyjnym `DeepEncoder` (tiling/downsampling 2D).
   - Umożliwia przetwarzanie dokumentów o dowolnej rozdzielczości bez ograniczeń rozmiaru siatki pikseli, wyspecjalizowany w odczycie faktur, paragonów, etykiet i drobnego druku.
   - Kontekst: **32 768 tokenów (32k)**, limit wyjściowy: **8 192 tokenów**.
   - Sampling OCR: `temperature: 0.2`, `top_p: 0.90`, `top_k: 20`, `repetition_penalty: 1.05`, `model_type_override: "vlm"`, `trust_remote_code: true`.
   - Waga modelu: kwantyzacja MLX 8-bit (~3.7 GB).

Obydwa modele zostały skonfigurowane w `model_settings.json` (warianty 1 i 2) jako `vlm` oraz zarejestrowane w Hermesie w `providers.omlx.models` z flagą `supports_vision: true`. Dodatkowo oznaczono model `UI-Venus-1.5-30B-A3B-qx86-hi-mlx` jako `supports_vision: true`.

---

## 🚀 5. Aktualizacja: Włączenie DeepSeek-V4-Flash-0731-MXFP4-MLX (Październik 2026)

Do rejestru oMLX i konfiguracji Hermes Agenta dołączono flagowy model MoE, rozszerzając bazę z 20 do **21 modeli**:

1. **`DeepSeek-V4-Flash-0731-MXFP4-MLX` (`TensorFold`)**:
   - Model MoE architektury `deepseek_v4` (256 routed experts, 6 aktywnych na token, 1 shared expert).
   - Waga modelu w pamięci RAM: wagi MXFP4 zajmujące **155.69 GB** w Unified Memory (zoptymalizowane pod kątem platformy Mac Studio 192 GB).
   - Natywny kontekst: **262 144 tokenów (256k; natywnie 1M, ograniczone ze względu na RAM)** z YaRN RoPE (factor 16, sliding window 128) oraz limitem wyjściowym `max_tokens: 32768`.
   - Akceleracja KV Cache: kompresja **TurboQuant KV 6-bit** (`turboquant_kv_bits: 6.0`), umożliwiająca stabilną obsługę bardzo długich promptów bez przekroczenia limitu RAM.
   - Sprzętowe MTP: Multi-Token Prediction o adaptacyjnej głębokości 3 (`mtp_enabled: true`, `mtp_adaptive_max_depth: 3`).
   - Parsowanie rozumowania: `reasoning_parser: "deepseek_v4"`, odblokowane myślenie (`enable_thinking: true`, `thinking_budget_enabled: false`, budżet bazowy 32k tokenów).
   - Kalibracja samplingu: `temperature: 0.6`, `top_p: 0.95`, `top_k: 40`, `repetition_penalty: 1.00`, `presence_penalty: 0.00`, `min_p: 0.01`.
   - Profile wykonawcze: zdefiniowano profil `work` z pełnym oknem 1M w `model_profiles.json`.
   - Weryfikacja: pomyślnie przetestowano bezpośrednie wywołanie agenta z linii poleceń (`hermes -m DeepSeek-V4-Flash-0731-MXFP4-MLX -z "..."`), uzyskując poprawną odpowiedź w języku polskim z natywnym blokiem `reasoning_content`.



---

## 🚀 6. Aktualizacja: Włączenie MiniMax-M3-ConfigI-MLX (Październik 2026)

Do rejestru oMLX i konfiguracji Hermes Agenta dołączono multimodalny model MoE, rozszerzając bazę z 21 do **22 modeli**:

1. **`MiniMax-M3-ConfigI-MLX` (`thetom-ai`)**:
   - Model MoE architektury `minimax_m3_vl` (60 warstw, 128 lokalnych ekspertów, top-4 routed experts, 1 shared expert, multimodalny projektor VLM).
   - Waga modelu w pamięci RAM: wagi ConfigI zajmujące **~156 GB** w Unified Memory (atencja 4/8-bit, eksperty 2–3-bit).
   - Okno kontekstu: **131 072 tokenów (128k; natywnie 1M, zredukowane ze względu na 192 GB RAM)** z limitem wyjściowym `max_tokens: 32768`.
   - Parsowanie rozumowania: `reasoning_parser: "minimax_m3"`, natywne tagi `<mm:think>` i `</mm:think>`, odblokowane myślenie (`enable_thinking: true`).
   - Kalibracja samplingu: `temperature: 1.0`, `top_p: 0.95`, `top_k: 40`, `repetition_penalty: 1.00`, `presence_penalty: 0.00`, `min_p: 0.01`.
   - Flaga wizji: `supports_vision: true` w konfiguracji Hermesa (`config.yaml`).
   - Synchronizacja: wdrożono przez `./switch-variant.sh 1` do `~/.hermes/config.yaml` oraz `~/.omlx/model_settings.json`.

---

## 🚀 7. Aktualizacja: Usunięcie modelu testowego Bielik-11B-v3.0-Huzar-MLX-8bit-v1 (Październik 2026)

Usunięto model testowy `Bielik-11B-v3.0-Huzar-MLX-8bit-v1` ze wszystkich konfiguracji oMLX i Hermes Agenta (`config.*.yaml`, `model_settings.*.json`, `~/.hermes/config.yaml`, `~/.omlx/model_settings.json`). 
- Model ten służył wyłącznie do celów badawczo-testowych i nie jest przeznaczony do developmentu agentowego w Hermesie.
- Jako oficjalny polski model językowy w środowisku pozostaje `Bielik-11B-v3.0-Instruct-MLX-8bit`.
- Aktualna liczba aktywnych modeli w rejestrze wynosi **21 modeli produkcyjnych**.

---

## 🚀 8. Aktualizacja: Usunięcie lokalnego fine-tune Qwen3.8-27B-FP16_huzar_v1 (Październik 2026)

Usunięto lokalny model fine-tune `Qwen3.8-27B-FP16_huzar_v1` ze wszystkich konfiguracji oMLX i Hermesa (`config.*.yaml`, `model_settings.*.json`, `~/.hermes/config.yaml`, `~/.omlx/model_settings.json`).
- W rejestrze modeli 27B/Flash pozostają oficjalne, zoptymalizowane wersje produkcyjne: `Qwen3.8-27B-Uncensored-MLX`, `Qwen3.8-27B-MTPLX-Optimized-Quality-FP16`, `Qwen3.8-Flash-Next-oQ5e-mtp` oraz `Qwen3.8-Flash-Next-MLX-6bit`.
- Aktualna liczba aktywnych modeli produkcyjnych wynosi **20 modeli**.
