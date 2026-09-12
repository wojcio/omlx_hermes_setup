# Konfiguracja Modeli: Hermes Agent & oMLX

Dokumentacja parametrów kontekstu, okien uwagi oraz parametrów samplingu dla modeli uruchamianych w oMLX i Hermes Agent na platformie Apple Silicon (MLX).

---

## 1. Zestawienie Zbiorcze Modeli

| Model | Architektura | max_context (okno) | windows (sliding) | max_tokens (wyjście) | Temp. | Top_p | Top_k | Rep. Pen. | Min_p / Pres. | Główne Cechy & Przeznaczenie |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| [**Qwen3.5-122B-A10B-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit) *(Domyślny)* | Qwen 3.5 MoE | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` *(work)* / `0.6` *(turbo)* | `0.95` | `20` | `1.05` | `0.01` / `0.00` | TurboQuant KV 8-bit, parser `qwen_3_5`, domyślny model główny |
| [**Qwen3.8-Flash-Next-MLX-6bit**](https://huggingface.co/pipenetwork/Qwen3.8-Flash-Next-MLX-6bit) | Qwen 4 Exp | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Szybki profil `setup`, pełne rozumowanie |
| [**Qwen3-Coder-Next-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit) | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | RoPE theta 5M, TurboQuant KV 8-bit, generowanie długiego kodu i diffów |
| [**Qwen3-Coder-Next-MLX-8bit**](https://huggingface.co/lmstudio-community/Qwen3-Coder-Next-MLX-8bit) | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | Wersja 8-bitowa dla optymalizacji pamięci RAM |
| [**Qwen3.8-27B-Uncensored-MLX**](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Lekki model (~15 GB), wariant 2 kompresora |
| [**Qwen3.8-27B-MTPLX-Optimized-Quality-FP16**](https://huggingface.co/Youssofal/Qwen3.8-27B-MTPLX-Optimized-Quality-FP16) | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Najwyższa jakość wag FP16 |
| [**Ornith-1.5-35B-A3B-Abliterated-MLX-BF16**](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16) | Qwen 3.5 MoE | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Model MoE z pełnym oknem 256k |
| [**Step-3.5-Flash-4bit**](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit) | Step 3.5 MoE | **262 144** (256k) | **512** | **32 768** | `0.6` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Llama3 RoPE scaling (2.0x), sliding window 512 |
| [**UI-Venus-1.5-30B-A3B-qx86-hi-mlx**](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx) | Qwen 3 VL MoE | **262 144** (256k) | *Brak (Dense)* | **16 384** | `0.7` | `0.80` | `20` | `1.00` | `0.01` / `0.00` | Model multimodalny Vision / UI, typ `vlm` |
| [**Laguna-S-2.1-MLX-8bit**](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit) | Laguna | **262 144** (256k) | **512** | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Sliding window 512, parser `poolside_v1` |
| [**DeepSeek-V4-Flash-MLX-mixed-4_8bit**](https://huggingface.co/pipenetwork/DeepSeek-V4-Flash-MLX-mixed-4_8bit) | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128, rep. penalty 1.00 |
| [**DeepSeek-V4-Flash-ConfigI-MLX**](https://huggingface.co/thetom-ai/DeepSeek-V4-Flash-ConfigI-MLX) | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128 |
| [**DeepSeek-V4-Flash-0731-AWQ**](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ) | DeepSeek V4 | **262 144** (256k) | **128** | **32 768** | `0.6` | `0.95` | `40` | `1.00` | `0.01` / `0.00` | YaRN RoPE (factor 16), sliding window 128 |
| [**Bielik-11B-v3.0-Instruct-MLX-8bit**](https://huggingface.co/speakleash/Bielik-11B-v3.0-Instruct-MLX-8bit) | LLaMA | **32 768** (32k) | *Brak* | **8 192** | `0.7` | `0.90` | `40` | `1.10` | `0.01` / `0.00` | Natywne okno 32k, polski model językowy |
| [**Qwen3-235B-A22B-MLX-4bit**](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit) | Qwen 3 MoE | **40 960** (40k) | *Brak* | **8 192** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Natywne okno bazowe 40 960 tokenów |
| [**Qwen3.8-Flash-Next-oQ5e-mtp**](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp) | Qwen 4 Exp | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Format oQ5e iMatrix z MTP, pełne okno 256k, wysoka jakość kwantyzacji |
| [**Qwen3.8-27B-FP16_huzar_v1**](file:///Users/wojcio/.lmstudio/models/huzar/Qwen3.8-27B-FP16_huzar_v1) | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Fine-tune Huzar (baza wiedzy), pełna precyzja FP16 (~27 GB), okno 256k |
| [**Bielik-11B-v3.0-Huzar-MLX-8bit-v1**](file:///Users/wojcio/.lmstudio/models/huzar/Bielik-11B-v3.0-Huzar-MLX-8bit-v1) | LLaMA | **32 768** (32k) | *Brak* | **8 192** | `0.7` | `0.90` | `40` | `1.10` | `0.01` / `0.00` | Fine-tune Huzar (baza wiedzy), natywne okno 32k, polski model językowy |
| [**olmOCR-2-7B-1025-8bit**](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit) | Qwen 2.5 VL | **128 000** (128k) | *Brak (Dense)* | **8 192** | `0.2` | `0.90` | `20` | `1.05` | `0.01` / `0.00` | Model VLM zoptymalizowany pod kątem zaawansowanego OCR dokumentów PDF, tabel, wzorów i układów wielokolumnowych |
| [**Unlimited-OCR-8bit**](https://huggingface.co/mlx-community/Unlimited-OCR-8bit) | UnlimitedOCR (DeepSeek MoE) | **32 768** (32k) | **128** | **8 192** | `0.2` | `0.90` | `20` | `1.05` | `0.01` / `0.00` | Model VLM OCR bez limitu rozdzielczości obrazu (downsampling/tiling 2D), odczyt faktur i etykiet, wymaga `trust_remote_code` |

---

## 2. Bezpośrednie Linki do Repozytoriów Hugging Face

Poniższa tabela zawiera pełny wykaz modeli zarejestrowanych w oMLX wraz z bezpośrednimi linkami do repozytoriów na Hugging Face, organizacją/autorem oraz ścieżką w katalogu lokalnym `~/.lmstudio/models`:

| # | Nazwa Modelu w oMLX | Repozytorium Hugging Face | Autor / Organizacja | Format / Kwantyzacja | Ścieżka Lokalna |
| :-: | :--- | :--- | :--- | :--- | :--- |
| 1 | `Qwen3.5-122B-A10B-MLX-9bit` | [inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit) | `inferencerlabs` | MLX 9-bit MoE | `~/.lmstudio/models/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit` |
| 2 | `Qwen3.8-Flash-Next-MLX-6bit` | [pipenetwork/Qwen3.8-Flash-Next-MLX-6bit](https://huggingface.co/pipenetwork/Qwen3.8-Flash-Next-MLX-6bit) | `pipenetwork` | MLX 6-bit | `~/.lmstudio/models/pipenetwork/Qwen3.8-Flash-Next-MLX-6bit` |
| 3 | `Qwen3-Coder-Next-MLX-9bit` | [inferencerlabs/Qwen3-Coder-Next-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit) | `inferencerlabs` | MLX 9-bit | `~/.lmstudio/models/inferencerlabs/Qwen3-Coder-Next-MLX-9bit` |
| 4 | `Qwen3-Coder-Next-MLX-8bit` | [lmstudio-community/Qwen3-Coder-Next-MLX-8bit](https://huggingface.co/lmstudio-community/Qwen3-Coder-Next-MLX-8bit) | `lmstudio-community` | MLX 8-bit | `~/.lmstudio/models/lmstudio-community/Qwen3-Coder-Next-MLX-8bit` |
| 5 | `Qwen3.8-27B-Uncensored-MLX` | [orcarouter/Qwen3.8-27B-Uncensored-MLX](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | `orcarouter` | MLX Dense (~15 GB) | `~/.lmstudio/models/orcarouter/Qwen3.8-27B-Uncensored-MLX` |
| 6 | `Qwen3.8-27B-MTPLX-Optimized-Quality-FP16` | [Youssofal/Qwen3.8-27B-MTPLX-Optimized-Quality-FP16](https://huggingface.co/Youssofal/Qwen3.8-27B-MTPLX-Optimized-Quality-FP16) | `Youssofal` | MLX FP16 | `~/.lmstudio/models/Youssofal/Qwen3.8-27B-MTPLX-Optimized-Quality-FP16` |
| 7 | `Ornith-1.5-35B-A3B-Abliterated-MLX-BF16` | [PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16) | `PocketAiHub` | MLX BF16 MoE | `~/.lmstudio/models/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16` |
| 8 | `Step-3.5-Flash-4bit` | [mlx-community/Step-3.5-Flash-4bit](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit) | `mlx-community` | MLX 4-bit MoE | `~/.lmstudio/models/mlx-community/Step-3.5-Flash-4bit` |
| 9 | `UI-Venus-1.5-30B-A3B-qx86-hi-mlx` | [nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx) | `nightmedia` | MLX qx86 Vision | `~/.lmstudio/models/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx` |
| 10 | `Laguna-S-2.1-MLX-8bit` | [Vontra/Laguna-S-2.1-MLX-8bit](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit) | `Vontra` | MLX 8-bit | `~/.lmstudio/models/Vontra/Laguna-S-2.1-MLX-8bit` |
| 11 | `DeepSeek-V4-Flash-MLX-mixed-4_8bit` | [pipenetwork/DeepSeek-V4-Flash-MLX-mixed-4_8bit](https://huggingface.co/pipenetwork/DeepSeek-V4-Flash-MLX-mixed-4_8bit) | `pipenetwork` | MLX mixed 4/8-bit | `~/.lmstudio/models/pipenetwork/DeepSeek-V4-Flash-MLX-mixed-4_8bit` |
| 12 | `DeepSeek-V4-Flash-ConfigI-MLX` | [thetom-ai/DeepSeek-V4-Flash-ConfigI-MLX](https://huggingface.co/thetom-ai/DeepSeek-V4-Flash-ConfigI-MLX) | `thetom-ai` | MLX ConfigI | `~/.lmstudio/models/thetom-ai/DeepSeek-V4-Flash-ConfigI-MLX` |
| 13 | `DeepSeek-V4-Flash-0731-AWQ` | [True2456/DeepSeek-V4-Flash-0731-AWQ](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ) | `True2456` | AWQ / MLX | `~/.lmstudio/models/True2456/DeepSeek-V4-Flash-0731-AWQ` |
| 14 | `Bielik-11B-v3.0-Instruct-MLX-8bit` | [speakleash/Bielik-11B-v3.0-Instruct-MLX-8bit](https://huggingface.co/speakleash/Bielik-11B-v3.0-Instruct-MLX-8bit) | `speakleash` | MLX 8-bit | `~/.lmstudio/models/speakleash/Bielik-11B-v3.0-Instruct-MLX-8bit` |
| 15 | `Qwen3-235B-A22B-MLX-4bit` | [Qwen/Qwen3-235B-A22B-MLX-4bit](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit) | `Qwen` | MLX 4-bit MoE | `~/.lmstudio/models/Qwen/Qwen3-235B-A22B-MLX-4bit` |
| 16 | `Qwen3.8-Flash-Next-oQ5e-mtp` | [GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp) | `GBP-DE` | MLX oQ5e iMatrix MTP | `~/.lmstudio/models/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp` |
| 17 | `Qwen3.8-27B-FP16_huzar_v1` | *Lokalny Fine-tune Huzar (baza wiedzy)* | `huzar` / `wojcio` | MLX FP16 Dense (~27 GB) | `~/.lmstudio/models/huzar/Qwen3.8-27B-FP16_huzar_v1` |
| 18 | `Bielik-11B-v3.0-Huzar-MLX-8bit-v1` | *Lokalny Fine-tune Huzar (baza wiedzy)* | `huzar` / `wojcio` | MLX 8-bit LLaMA (~11 GB) | `~/.lmstudio/models/huzar/Bielik-11B-v3.0-Huzar-MLX-8bit-v1` |
| 19 | `olmOCR-2-7B-1025-8bit` | [mlx-community/olmOCR-2-7B-1025-8bit](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit) | `mlx-community` / `allenai` | MLX 8-bit VLM (~8.8 GB) | `~/.lmstudio/models/mlx-community/olmOCR-2-7B-1025-8bit` |
| 20 | `Unlimited-OCR-8bit` | [mlx-community/Unlimited-OCR-8bit](https://huggingface.co/mlx-community/Unlimited-OCR-8bit) | `mlx-community` / `baidu` | MLX 8-bit MoE VLM (~3.7 GB) | `~/.lmstudio/models/mlx-community/Unlimited-OCR-8bit` |
| *LoRA* | `salakash/Minimalism` *(Adapter)* | [salakash/Minimalism](https://huggingface.co/salakash/Minimalism) | `salakash` | LoRA Adapter (Qwen2.5-0.5B) | `~/.lmstudio/models/salakash/Minimalism` |

---

## 3. Warianty Architektury Kompresora w Hermesie

Dostępne są dwa zoptymalizowane warianty konfiguracji:

### 🏆 Wariant 1: Zero-Swap Dynamic (Domyślny & Rekomendowany: Kompresor = Model Sesji)
* **Model główny:** Dowolny z 18 modeli (domyślnie `Qwen3.5-122B-A10B-MLX-9bit`)
* **Kompresor (`auxiliary.compression`):** `provider: auto`, `model: ""`
* **Zasada działania:** Hermes dynamicznie używa do kompresji tego samego modelu, który aktualnie prowadzi konwersację (Ornith, Qwen 122B, Coder itd.).
* **Zalety:**
  - **0 sekund opóźnienia przełączania modeli (Zero Swap)** – model jest już w RAM i w pamięci podręcznej KV.
  - Pełna dynamika: zmiana modelu w Hermesie automatycznie zmienia model wykonujący kompresję.
  - 100% zgodność z regułą pojedynczego modelu w RAM (`len(loaded) <= 1`).

### ⚡ Wariant 2: Dual-Model Resident (Szybki Dedykowany Kompresor 27B)
* **Model główny:** `Qwen3.5-122B-A10B-MLX-9bit` (256k)
* **Kompresor (`auxiliary.compression`):** `Qwen3.8-27B-Uncensored-MLX` (256k, ~15 GB)
* **Zasada działania:** Dedykowany, mniejszy model 27B realizuje podsumowania kontekstu.
* **Integracja z Watchdogiem:** Model 27B ma ustawioną flagę `"is_pinned": true` w `model_settings.json`, dzięki czemu demon Watchdoga nie wyładowuje go z pamięci.
* **Pamięć RAM:** 128 GB (122B) + 15 GB (27B) = **~143 GB** (swobodnie mieści się w 192 GB Unified Memory).
* **Zalety:** Szybszy prefill i odciążenie głównego modelu podczas kompresji.

---

## 4. Przełączanie Wariantów (`switch-variant.sh`)

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

## 5. Timeouty i Rozwiązanie Problemu "Nieaktywnego Modelu"

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

## 6. Zestawienie Plików Konfiguracyjnych

- `config.yaml` / `config.variant1-single-model.yaml` – Konfiguracja Hermesa dla Wariantu 1.
- `config.variant2-dual-model.yaml` – Konfiguracja Hermesa dla Wariantu 2.
- `model_settings.json` / `model_settings.variant1-single-model.json` – Ustawienia modeli oMLX dla Wariantu 1.
- `model_settings.variant2-dual-model.json` – Ustawienia modeli oMLX dla Wariantu 2 (`Qwen 27B` jako `pinned`).
- `model_profiles.json` – Profile wykonawcze `work`, `turbo`, `setup` z pełnym oknem 256k.
- `settings.json` – Globalne parametry serwera oMLX.
- `switch-variant.sh` – Skrypt przełączania wariantów.
