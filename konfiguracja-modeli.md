# Konfiguracja Modeli: Hermes Agent & oMLX

Dokumentacja parametrów kontekstu, okien uwagi oraz parametrów samplingu dla modeli uruchamianych w oMLX i Hermes Agent na platformie Apple Silicon (MLX).

---

## 1. Zestawienie Zbiorcze Modeli

| Model | Architektura | max_context (okno kontekstu) | windows (sliding window) | max_tokens (maks. wyjście) | Temperature | Top_p | Top_k | Repetition Penalty | Min_p / Pres. Pen. | Główne Cechy & Przeznaczenie |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Qwen3.5-122B-A10B-MLX-9bit** *(Domyślny)* | Qwen 3.5 MoE | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` *(work)* / `0.6` *(turbo)* | `0.95` | `20` | `1.05` | `0.01` / `0.00` | TurboQuant KV 8-bit, parser `qwen_3_5`, domyślny model główny |
| **Qwen3.8-Flash-Next-MLX-6bit** | Qwen 4 Exp | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Szybki profil `setup`, pełne rozumowanie |
| **Qwen3-Coder-Next-MLX-9bit** | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | RoPE theta 5M, TurboQuant KV 8-bit, generowanie długiego kodu i diffów |
| **Qwen3-Coder-Next-MLX-8bit** | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | Wersja 8-bitowa dla optymalizacji pamięci RAM |
| **Qwen3.8-27B-Uncensored-MLX** | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Lekki model (~15 GB), wariant 2 kompresora |
| **Qwen3.8-27B-MTPLX-Optimized-FP16** | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Najwyższa jakość wag FP16 |
| **Ornith-1.5-35B-A3B-Abliterated-BF16** | Qwen 3.5 MoE | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Model MoE z pełnym oknem 256k |
| **Step-3.5-Flash-4bit** | Step 3.5 MoE | **262 144** (256k) | **512** | **32 768** | `0.6` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Llama3 RoPE scaling (2.0x), sliding window 512 |
| **UI-Venus-1.5-30B-A3B-qx86-mlx** | Qwen 3 VL MoE | **262 144** (256k) | *Brak (Dense)* | **16 384** | `0.7` | `0.80` | `20` | `1.00` | `0.01` / `0.00` | Model multimodalny Vision / UI, typ `vlm` |
| **Laguna-S-2.1-MLX-8bit** | Laguna | **262 144** (256k) | **512** | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Sliding window 512, parser `poolside_v1` |
| **DeepSeek-V4-Flash-MLX-mixed-4_8bit** | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128, rep. penalty 1.00 |
| **DeepSeek-V4-Flash-ConfigI-MLX** | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128 |
| **DeepSeek-V4-Flash-0731-AWQ** | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128 |
| **Bielik-11B-v3.0-Instruct-MLX-8bit** | LLaMA | **32 768** (32k) | *Brak* | **8 192** | `0.7` | `0.90` | `40` | `1.10` | `0.01` / `0.00` | Natywne okno 32k, polski model językowy |
| **Qwen3-235B-A22B-MLX-4bit** | Qwen 3 MoE | **40 960** (40k) | *Brak* | **8 192** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Natywne okno bazowe 40 960 tokenów |

---

## 2. Warianty Architektury Kompresora w Hermesie

Dostępne są dwa zoptymalizowane warianty konfiguracji:

### 🏆 Wariant 1: Zero-Swap Monolith (Domyślny & Rekomendowany)
* **Model główny:** `Qwen3.5-122B-A10B-MLX-9bit` (256k)
* **Kompresor (`auxiliary.compression`):** `Qwen3.5-122B-A10B-MLX-9bit`
* **Zasada działania:** Ten sam model obsługuje rozmowę i generuje podsumowania kompresji kontekstu.
* **Zalety:**
  - **0 sekund opóźnienia przełączania modeli (Zero Swap)** – model nie musi być przeładowywany z dysku SSD.
  - Najwyższa jakość streszczeń i precyzja zachowania faktów technicznych.
  - Idealna zgodność z demonem Watchdoga (`len(loaded) <= 1`).

### ⚡ Wariant 2: Dual-Model Resident (Szybki Lekki Kompresor 27B)
* **Model główny:** `Qwen3.5-122B-A10B-MLX-9bit` (256k)
* **Kompresor (`auxiliary.compression`):** `Qwen3.8-27B-Uncensored-MLX` (256k, ~15 GB)
* **Zasada działania:** Dedykowany, mniejszy model 27B realizuje podsumowania kontekstu.
* **Integracja z Watchdogiem:** Model 27B ma ustawioną flagę `"is_pinned": true` w `model_settings.json`, dzięki czemu demon Watchdoga nie wyładowuje go z pamięci.
* **Pamięć RAM:** 128 GB (122B) + 15 GB (27B) = **~143 GB** (swobodnie mieści się w 192 GB Unified Memory).
* **Zalety:** Szybszy prefill i odciążenie głównego modelu podczas kompresji.

---

## 3. Przełączanie Wariantów (`switch-variant.sh`)

W katalogu projektu znajduje się skrypt umożliwiający błyskawiczną zmianę aktywnego wariantu:

```bash
# Aktywacja Wariantu 1 (Domyślny):
./switch-variant.sh 1

# Aktywacja Wariantu 2 (Dual-Model 27B):
./switch-variant.sh 2
```

Skrypt automatycznie:
1. Podmienia pliki `config.yaml` oraz `model_settings.json`.
2. Kopiuje je do aktywnych katalogów systemowych `~/.hermes/` oraz `~/.omlx/`.

---

## 4. Timeouty i Rozwiązanie Problemu "Nieaktywnego Modelu"

W logach Hermesa zidentyfikowano problem, w którym przy długim kontekście (~175k tokenów) proces kompresji był przerywany komunikatem:
```text
WARNING run_agent: Context compression made no progress for 120.0s; continuing without compression
```
**Przyczyny i zastosowane poprawki:**
1. **Zwiększenie `context_timeout_seconds` do 300s:** Faza prefillu dla 175k tokenów na modelu 122B trwa 1.5–3 minuty. Zwiększenie timeoutu do 5 minut gwarantuje, że Hermes nie uzna modelu za zawieszony w trakcie prefillu.
2. **`context_total_ceiling_seconds: 1200`:** Łączny bezpieczny czas na całą procedurę kompresji to 20 minut.
3. **Odblokowanie pełnego 256k okna:** Usunięto błąd, w którym Hermes odrzucał model kompresora poniżej progu 64k.
4. **Wymuszenie lokalnego oMLX:** Skierowano `auxiliary.compression.provider: omlx` zamiast `auto`, co wyeliminowało błędy braku kredytów (402) i przekroczenia okna (400) w OpenRouterze.

---

## 5. Zestawienie Plików Konfiguracyjnych

- `config.yaml` / `config.variant1-single-model.yaml` – Konfiguracja Hermesa dla Wariantu 1.
- `config.variant2-dual-model.yaml` – Konfiguracja Hermesa dla Wariantu 2.
- `model_settings.json` / `model_settings.variant1-single-model.json` – Ustawienia modeli oMLX dla Wariantu 1.
- `model_settings.variant2-dual-model.json` – Ustawienia modeli oMLX dla Wariantu 2 (`Qwen 27B` jako `pinned`).
- `model_profiles.json` – Profile wykonawcze `work`, `turbo`, `setup` z pełnym oknem 256k.
- `settings.json` – Globalne parametry serwera oMLX.
- `switch-variant.sh` – Skrypt przełączania wariantów.
