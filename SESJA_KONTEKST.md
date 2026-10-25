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

---

## 🚀 9. Naprawa: ładowanie MiniMax-M3-ConfigI-MLX w oMLX (Październik 2026)

Model nie ładował się w oMLX (`Received 1378 parameters not in model`, następnie `Expected shape (129, 6144, 768) but received (129, 6144, 384)`). Przyczyny leżały w `config.json` kwantyzacji `thetom-ai/MiniMax-M3-ConfigI-MLX`:
1. **Brak `vision_config`** – oMLX klasyfikował model jako text-only (`type: llm`) i budował go bez wieży wizyjnej, mimo że wagi zawierają `vision_tower` (515 tensorów). Dodano `vision_config` z oryginalnego `MiniMaxAI/MiniMax-M3` (hidden 1280, 32 warstwy, FFN 5120 – zgodne z wagami).
2. **Brak wpisów kwantyzacji `switch_mlp.gate_up_proj`** – loader łączy `gate_proj` i `up_proj` w `gate_up_proj`, a per-warstwowa kwantyzacja ConfigI (eksperty 2-bit) nie zawierała takiego klucza, więc przyjmowano domyślne 4 bity. Dodano 114 wpisów (w `quantization` i `quantization_config`) z bitami `gate_proj`.

Zmiany są w pliku poza repozytorium (`~/.lmstudio/models/thetom-ai/MiniMax-M3-ConfigI-MLX/config.json`, kopia oryginału: `config.json.bak-no-vision_config`) i trzeba je powtórzyć po ponownym pobraniu modelu. Po `POST /admin/api/reload` model jest wykrywany jako `vlm` i ładuje się poprawnie; test: odpowiedź po polsku z blokiem rozumowania, ~23.6 tok/s.

---

## 🚀 10. Konsolidacja i eliminacja duplikatów modeli (Październik 2026)

Przeprowadzono gruntowną optymalizację rejestru modeli, redukując liczbę pozycji z 20 do **15 kluczowych, wyspecjalizowanych modeli produkcyjnych**. Wyeliminowano zbędne warianty kwantyzacji dublujące te same modele bazowe:

1. **DeepSeek-V4-Flash**:
   - Pozostawiono: flagowy `DeepSeek-V4-Flash-0731-MXFP4-MLX` (~155 GB, najwyższa jakość, MTP depth 3) oraz lżejszy `DeepSeek-V4-Flash-0731-AWQ` (~100 GB z MTP).
   - Usunięto z konfiguracji: `DeepSeek-V4-Flash-MLX-mixed-4_8bit` oraz `DeepSeek-V4-Flash-ConfigI-MLX`.
2. **Qwen3-Coder-Next**:
   - Pozostawiono: `Qwen3-Coder-Next-MLX-9bit` (wyższa precyzja wag kodera dla 192 GB RAM).
   - Usunięto z konfiguracji: `Qwen3-Coder-Next-MLX-8bit`.
3. **Qwen3.8-Flash-Next**:
   - Pozostawiono: `Qwen3.8-Flash-Next-oQ5e-mtp` (lżejszy, iMatrix oraz sprzętowa akceleracja MTP).
   - Usunięto z konfiguracji: `Qwen3.8-Flash-Next-MLX-6bit`.
4. **Klasa 27B**:
   - Pozostawiono: `Qwen3.8-27B-Uncensored-MLX` jako dedykowany i stały kompresor wariantu 2.
   - Usunięto z konfiguracji: `Qwen3.8-27B-MTPLX-Optimized-Quality-FP16`.

Zsynchronizowano konfiguracje oMLX i Hermesa za pomocą `./switch-variant.sh 1`.

---

## 🚀 11. Rozszerzenie bazy do 17 modeli: Cyber-Tiel-Coder-35B oraz Qwen3.8-Flash-Next-MTPLX-Speed (Październik 2026)

Włączono do konfiguracji Hermesa i serwera oMLX dwa nowe, wyspecjalizowane modele pobrane do `~/.lmstudio/models`:

1. **`Cyber-Tiel-Coder-35B-A3B-MLX-oQ6e-MTP`** (`peculiar-ragdoll`):
   - Architektura: `qwen3_5_moe` (`Qwen3_5MoeForConditionalGeneration`), 40 warstw, 256 ekspertów (top-8 routed, zaledwie ~3B aktywnych parametrów na token).
   - Kwantyzacja: `oQ6e` (OpenQuant 6-bit) kalibrowana na zbiorze `oqe_code_multilingual` (iMatrix).
   - Rozmiar: ~31.7 GB w RAM (tekst: ~30.8 GB, wizja: ~0.9 GB).
   - Okno kontekstu: 262 144 (256k), wyjście 32 768 tokenów.
   - Multimodalność i reasoning: VLM (`supports_vision: true`), standardowy parser rozumowania `qwen_3_5` (`<think>` / `</think>`).
   - Rola: lekki, błyskawiczny Coder w pętlach agentowych (`run_command`, edycja plików), stanowiący lżejszą i szybszą alternatywę dla gęstego modelu `Qwen3-Coder-Next-MLX-9bit`.

2. **`Qwen3.8-Flash-Next-MTPLX-Optimized-Speed`** (`Youssofal`):
   - Architektura: `qwen4_exp` (`Qwen4ExpForConditionalGeneration`), 48 warstw, 512 ekspertów (top-10 routed).
   - Kwantyzacja & Akceleracja: zintegrowany `mtplx_runtime.json` (v2.9.3) z wielopoziomowym schematem (4-bit rdzeń, 8-bit krytyczne warstwy, zachowane BF16), MTP depth 3 oraz dedykowana tablica ngramów (`ngram-table.safetensors`, 32 GB).
   - Rozmiar: ~120.8 GB w RAM.
   - Prędkość: pomiary wykazują aż **~73.5 tok/s** (1.68x przyspieszenie względem autoregresji 43.8 tok/s).
   - Okno kontekstu: 262 144 (256k), wyjście 32 768 tokenów, VLM (`supports_vision: true`), parser `qwen_3_5`.
   - Rola: profil maksymalnego throughputu generowania do długich, interaktywnych sesji z agentem. Współistnieje obok dokładniejszego modelu `Qwen3.8-Flash-Next-oQ5e-mtp` (GBP-DE).

Zaktualizowano pliki `config.*.yaml`, `model_settings.*.json`, `konfiguracja-modeli.md`, `README.md` oraz `GEMINI.md`.

---

## 🚀 14. Naprawa: ładowanie Qwen3.8-Flash-Next-MTPLX-Optimized-Speed w oMLX (Październik 2026)

Model `Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` zgłaszał błąd ładowania `HTTP 409: Model failed to load: VLM load failed: Received 1 parameters not in model: language_model.model.layers.1.ple.conv_weight.; LLM fallback also failed: Model type qwen4_exp not supported.`

### Zdiagnozowane przyczyny i wdrożone rozwiązania:
1. **Niezgodność nazwy wagi splotu 1D w warstwie PLE (`conv_weight` vs `conv1d.weight`):**
   - W pliku `model-00018-of-00019.safetensors` oraz `model.safetensors.index.json` klucz tensora splotu warstwy 1 PLE został wyeksportowany pod nazwą `language_model.model.layers.1.ple.conv_weight`.
   - Moduł architektury MLX (`Qwen4ExpPLELayer` w `language.py`) definiuje moduł splotu jako `self.conv1d = nn.Conv1d(...)`, ściśle oczekując klucza `language_model.model.layers.1.ple.conv1d.weight`.
   - Utworzono kopię zapasową shardu 18 (`.bak`) oraz indeksu, i zaktualizowano klucz tensora na `conv1d.weight`.

2. **N-gram Embedding: Format monolityczny MTPLX vs shardy oMLX (`Missing 128 parameters`):**
   - Po rozwiązaniu problemu splotu, oMLX zgłosił brak 128 parametrów: `language_model.model.layers.1.ple.ple_embedding.ngram_embedding.shards.0.weight` .. `shards.127.weight`.
   - Repozytorium upstreamowe `Youssofal` zostało przygotowane pod autorski silnik MTPLX i scaliło 128 shardów N-gram do pojedynczego pliku monolitycznego `ngram-table.safetensors` (zawierającego `ngram.weight`, `ngram.scales`, `ngram.biases` o 320 001 536 wierszach), usuwając podział na shardy z indeksu i pliku konfiguracyjnego.
   - oMLX (poprzez moduł zgodności `mlx_vlm_qwen4_exp_compat`) w trybach `resident` i `mmap` wymaga standardowego podziału tabeli N-gram na 128 shardów (po 2 500 012 wierszy na shard), obecności konfiguracji kwantyzacji (`bits: 4, group_size: 32, mode: affine`) w `config.json` oraz mapowania w `model.safetensors.index.json`.
   - Wygenerowano natywnie w MLX 8 zbalansowanych plików safetensors (`model-ngram-00001-of-00008.safetensors` do `00008`, po 16 shardów / ~3.73 GB każdy) zawierających precyzyjne wycinki tabeli (`weight`, `scales`, `biases`).
   - Zaktualizowano `config.json` o 128 wpisów `shards.{i}` w sekcji `quantization` (kopia oryginału w `config.json.bak`).
   - Do `model.safetensors.index.json` dodano 384 nowe klucze mapujące tenzory N-gram do nowych plików shardów.

### Wyniki weryfikacji:
- Endpoint oMLX `POST /admin/api/reload` pomyślnie zaindeksował model.
- Test inferencji `/v1/chat/completions`: model załadował się do Unified Memory w 36s, osiągając generowanie **41.1 tok/s** z czasem do pierwszego tokenu (TTFT) zaledwie **0.16s**.
- Test Hermes CLI: `hermes -z "Napisz jedno słowo: SUKCES" -m "Qwen3.8-Flash-Next-MTPLX-Optimized-Speed"` zwrócił poprawnie `SUKCES`.

---

## 🚀 15. Aktualizacja do oMLX 0.7.2 oraz Splash M1 1.3.2-m1.2 i pełny audyt 19 modeli (Październik 2026)

### 1. Aktualizacja silnika Splash do wersji `1.3.2-m1.2` (`paperniuk/splash`):
- Zaktualizowano binarkę `/opt/homebrew/bin/splash-m1` z `1.3.2-m1.1` do **`1.3.2-m1.2`** (wsparcie dla Apple GPU family 8 – M2 Ultra).
- Nowy algorytm kalibracji Neural Engine FFN split zwiększył udział ANE z `0.24` do **`0.26`** dla bloków $\ge 533$ wierszy, skracając czas warstwy FFN z `70.5 ms` (sam GPU) do **`53.1 ms`** (GPU + ANE).
- Zweryfikowano działanie `Qwen3.8-27B-Uncensored-MLX-SPLASH` z cache KV na SSD i w Hermes CLI (~42.7 tok/s).

### 2. Diagnostyka i naprawa `Qwen3.8-Flash-Next-oQ5e-mtp` (Affine `hc_fused` + Lightning MTP):
- Naprawiono ładowanie modelu poprzez zmianę `model_type_override` z `"llm"` na `"vlm"` (architektura `qwen4_exp` wymaga silnika `mlx_vlm`), dodano `reasoning_parser: "qwen_3_5"`, `thinking_budget_tokens: 32768`, `presence_penalty: 0.0` oraz `turboquant_skip_last: true`.
- Potwierdzono, że w przeciwieństwie do wersji `Speed` (gdzie wagi miksera HC są w nieskwantyzowanym BF16), wariant `oQ5e` posiada wszystkie 296 tensorów Hyper-Connection w formacie **Affine 6-bit / group 64**, dzięki czemu oMLX 0.7.2 kompiluje dla niego **100 dedykowanych ścieżek `hc_fused`** na GPU.
- Wbudowane tensory `mtp.` uruchamiają natywne **Lightning MTP**, osiągając **72.5% akceptacji draftów** (2.50 tok/cykl).

### 3. Kompleksowy audyt i optymalizacja wszystkich 19 modeli pod oMLX 0.7.2:
- **`Qwen3.8-27B-Coder390-...-MTP-DFlash2`:** Usunięto konflikt jednoczesnego włączenia `mtp_enabled: true`, `dflash_enabled: true` i `vlm_mtp_enabled: true` (powodował odrzucenie całego wpisu przez walidator `ModelSettings.from_dict()` w oMLX 0.7.2). Pozostawiono natywną głowicę **`mtp_enabled: true`** (`mtp-bf16.safetensors` dopasowane do destylacji Coder390) oraz `turboquant_kv_enabled: true` (8-bit, `skip_last: true`).
- **`Qwen3.8-Flash-Next-MTPLX-Optimized-Speed`:** Wyłączono `mtp_enabled: false` (plik sidecar `mtp.safetensors` ma kontrakt `qwen4-next`, co powodowało błąd `HTTP 400` przy zapisie ustawień w oMLX 0.7.2; model korzysta z 128 shardów N-gram) oraz włączono nową flagę **`qwen4_gdn_decode_wide_proj: true`** (scalony kernel dekodowania GDN dla projekcji 4-bit/gs32).
- **`Qwen3.8-27B-Uncensored-MLX` i `Qwen3.8-27B-FP16_huzar_v1`:** Podpięto lokalny model pomocniczy **`dflash_draft_model: "Qwen3.8-27B-DFlash2"`** przy `dflash_enabled: true` oraz ujednolicono `turboquant_skip_last: true`.
- **`Qwen3-235B-A22B-MLX-4bit` i `Laguna-S-2.1-MLX-8bit`:** Włączono kompresję `turboquant_kv_enabled: true` (8-bit, `skip_last: true`) dla `Qwen3-235B` oraz usunięto nieobsługiwany w xgrammar `reasoning_parser: "poolside_v1"` z `Laguna-S-2.1` (oMLX 0.7.2 automatycznie używa natywnego parsera `laguna`).
- **Walidacja API:** Wszystkie 19 modeli zarejestrowanych w oMLX pomyślnie przechodzi walidację `PUT /admin/api/models/{id}/settings` ze statusem `200 OK`.

---

## 🚀 16. Aktualizacja do oMLX 0.7.3.dev2 oraz analiza skalowania prędkości `DeepSeek-V4-Flash-0731-MXFP4-MLX` w funkcji kontekstu (Październik 2026)

### 1. Walidacja i nowości w `oMLX 0.7.3.dev2` (`mlx-vlm 0.7.10`):
- Zweryfikowano wszystkie 19 modeli w `model_settings.json` za pomocą `omlx.model_settings.ModelSettings.from_dict()` z wbudowanego środowiska Python w `/Applications/oMLX.app` (`0` błędów, `0` nieznanych kluczy).
- Potwierdzono automatyczne korzyści z nowej wersji: szybszy DFlash2 (`+16%` do `+33%` tok/s) dzięki uruchomieniu draftera `bf16` w `fp16` z akumulacją rezydualną `fp32` dla modeli 27B (`Qwen3.8-27B-Uncensored-MLX`, `Qwen3.8-27B-FP16_huzar_v1`), zespolone kernele dekodowania dla `MiniMax-M3-ConfigI-MLX` (`+14%` do `+23%` decode), udoskonalony *batch park backoff* w Lightning MTP oraz poprawki separacji `<think>`, obsługi `tool_choice: none` i miniatur obrazów z narzędzi MCP.

### 2. Analiza telemetrii `server.log`: dlaczego `DeepSeek-V4-Flash-0731-MXFP4-MLX` zwalnia z ~32–34 TG do ~21–24 TG przy >210k kontekstu?
Na podstawie 126 wpisów `Chat completion` oraz statystyk `MTP[...]` w `~/.omlx/logs/server.log` zestawiono wyniki przed aktualizacją (`oMLX 0.7.2`) i po aktualizacji (`oMLX 0.7.3.dev2` o godz. 13:01):

| Godzina | Wersja oMLX | Kontekst (`prompt`) | Krok `backbone / cykl` | Akceptacja DSpark MTP (`tok/cykl`) | Prędkość (`TG tok/s`) |
| :--- | :--- | ---: | ---: | ---: | ---: |
| `03:02 – 03:06` | `0.7.2` | **9 623 – 41 708** | `92.1 – 102.3 ms` | `3.30 – 3.65` (89–96%) | **31.0 – 34.6 tok/s** |
| `03:23:13` | `0.7.2` | **63 578** | `101.2 ms` | `3.03` (85.2%) | **28.3 tok/s** |
| `07:39 – 07:48` | `0.7.2` | **213 534 – 225 841** | `121.8 – 132.1 ms` | `2.58 – 2.76` (80–83%) | **20.9 – 21.7 tok/s** |
| `14:31:28` | `0.7.3.dev2` | **226 775** | `127.6 ms` | `2.88` (81.3%) | **21.5 tok/s** |
| `14:35:06` | `0.7.3.dev2` | **232 273** | `125.2 ms` | `3.10` (88.1%) | **23.7 tok/s** |
| `14:36:24` | `0.7.3.dev2` | **161 154** | `115.0 ms` | `2.98` (84.3%) | **24.7 tok/s** |
| `14:39:58` | `0.7.3.dev2` | **66 709** | **`95.0 ms`** | **`3.01` (92.5%)** | **30.0 tok/s** |

- **Wniosek 1 (brak regresji):** Przy identycznym rozmiarze kontekstu (`~65k` oraz `~226k` tokenów) `oMLX 0.7.3.dev2` jest o `~1–1.5 tok/s` szybszy od `0.7.2`. Gdy sesja została skompresowana z `232 273` do `66 709` tokenów, prędkość natychmiast wróciła do **`30.0 tok/s`**.
- **Wniosek 2 (wyłączenie TurboQuant KV przez *attention sinks* i koszt pamięci):** Przy starcie modelu oMLX loguje `TurboQuant disabled: model uses attention sinks, which are not supported by TurboQuant's quantized attention kernels; keeping fp16 KV cache`. Sam model zajmuje `158.84 GB` RAM, więc powyżej `225k` tokenów osiągany jest próg *Soft memory pressure* (`current=164.3GB, soft=164.1GB`), a koszt przeszukiwania kontekstu przez kernel `DSV4F/M2 v25 MMA indexer score` wydłuża pojedynczy cykl `backbone` z `~95 ms` do `~128 ms` (+35%).
- **Wniosek 3 (współczynnik akceptacji `embedded DSpark` MTP przy `tool_calls`):** Na krótkim kontekście 3-etapowy drafter DSpark trafia `91–96%` tokenów (`~3.5 tok/cykl`), natomiast przy `>210k` tokenów i generowaniu rozbudowanych wywołań narzędzi (`finish_reason=tool_calls`) akceptacja spada do `80–84%` (`2.6–2.9 tok/cykl`), co razem z dłuższym krokiem `backbone` daje `~21–24 tok/s`.
