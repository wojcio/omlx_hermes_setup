# Konfiguracja Modeli: Hermes Agent & oMLX

Dokumentacja parametrów kontekstu, okien uwagi oraz parametrów samplingu dla modeli uruchamianych w oMLX i Hermes Agent na platformie Apple Silicon (MLX).

---

## 1. Zestawienie Zbiorcze Modeli

> **Wspólne parametry dla wszystkich modeli:** `min_p: 0.01` oraz `presence_penalty: 0.00` (ochrona struktur JSON/XML przed ucieczką tokenów).

| # | Model (Hugging Face) & Architektura | Okno / Wyjście<br>*(Sliding)* | Sampling<br>*(Temp / TopP / TopK / Rep)* | Akceleracja oMLX 0.7.2 & Przeznaczenie |
| :-: | :--- | :---: | :---: | :--- |
| 1 | [**Qwen3.5-122B-A10B-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit)<br>*(Domyślny · Qwen 3.5 MoE)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05`<br>*(turbo: T=0.6)* | TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up, parser `qwen_3_5`, domyślny model główny |
| 2 | [**Qwen3-Coder-Next-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit)<br>*(Qwen 3 Next Coder)* | **256k** / **32k**<br>*(Dense)* | `0.6` / `0.95` / `40` / `1.05` | RoPE theta 5M, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up, generowanie długiego kodu i diffów |
| 3 | [**Qwen3.8-27B-Uncensored-MLX**](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX)<br>*(Qwen 3.5 Dense)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Lekki model (~15 GB), natywne spekulatywne dekodowanie DFlash2 (`Qwen3.8-27B-DFlash2`), TurboQuant KV 8-bit (`skip_last`) |
| 4 | [**Ornith-1.5-35B-A3B-Abliterated-MLX-BF16**](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16)<br>*(Qwen 3.5 MoE)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Model MoE BF16 bez cenzury z pełnym oknem 256k, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up |
| 5 | [**Step-3.5-Flash-4bit**](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit)<br>*(Step 3.5 MoE)* | **256k** / **32k**<br>*(SW: 512)* | `0.6` / `0.95` / `20` / `1.05` | Llama3 RoPE scaling (2.0x), sliding window 512, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up |
| 6 | [**UI-Venus-1.5-30B-A3B-qx86-hi-mlx**](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx)<br>*(Qwen 3 VL MoE)* | **256k** / **16k**<br>*(Dense)* | `0.7` / `0.80` / `20` / `1.00` | Model multimodalny Vision / UI, typ `vlm`, TurboQuant KV 8-bit (`skip_last`) |
| 7 | [**Laguna-S-2.1-MLX-8bit**](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit)<br>*(Laguna MoE)* | **256k** / **32k**<br>*(SW: 512)* | `0.7` / `0.95` / `20` / `1.05` | Sliding window 512, natywny parser `laguna` w oMLX 0.7.2, Fused MoE Gate/Up, TurboQuant KV 8-bit (`skip_last`) |
| 8 | [**DeepSeek-V4-Flash-0731-AWQ**](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ)<br>*(DeepSeek V4 MoE)* | **256k** / **32k**<br>*(SW: 128)* | `0.6` / `0.95` / `40` / `1.00` | YaRN RoPE (factor 16), sliding window 128, Lightning MTP, MLA Latent Attention |
| 9 | [**Qwen3.8-27B-Uncensored-MLX-SPLASH**](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX)<br>*(Qwen 3.5 Dense · Splash)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Silnik Splash 1.4.0-m1 (Threadgroup memory register staging, Metal/ANE FFN split `0.26` + DFlash2 draft), do **64.0 tok/s**, dedykowany kompresor Wariantu 2 |
| 10 | [**Qwen3-235B-A22B-MLX-4bit**](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit)<br>*(Qwen 3 MoE)* | **40k** / **8k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Natywne okno bazowe 40 960 tokenów, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up |
| 11 | [**Qwen3.8-Flash-Next-oQ5e-mtp**](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp)<br>*(Qwen 4 Exp VL)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Format oQ5e iMatrix (typ `vlm`, wizja), Lightning MTP (72.5% akceptacji, 2.50 tok/cykl), 100 ścieżek Affine `hc_fused`, KV 8-bit |
| 12 | [**olmOCR-2-7B-1025-8bit**](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit)<br>*(Qwen 2.5 VL)* | **128k** / **8k**<br>*(Dense)* | `0.2` / `0.90` / `20` / `1.05` | Model VLM do zaawansowanego OCR dokumentów PDF, tabel, wzorów i układów wielokolumnowych |
| 13 | [**Unlimited-OCR-8bit**](https://huggingface.co/mlx-community/Unlimited-OCR-8bit)<br>*(UnlimitedOCR MoE)* | **32k** / **8k**<br>*(SW: 128)* | `0.2` / `0.90` / `20` / `1.05` | Model VLM OCR bez limitu rozdzielczości obrazu (downsampling/tiling 2D), odczyt faktur i etykiet (`trust_remote_code`) |
| 14 | [**DeepSeek-V4-Flash-0731-MXFP4-MLX**](https://huggingface.co/TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX)<br>*(DeepSeek V4 MoE)* | **256k** / **32k**<br>*(SW: 128)* | `0.6` / `0.95` / `40` / `1.00` | YaRN RoPE (factor 16), SW 128, embedded DSpark MTP (depth 3), `fp16` KV (*attention sinks*), 31–34.6 tok/s (<45k) / ~21–24 tok/s (>210k), ~159 GB |
| 15 | [**MiniMax-M3-ConfigI-MLX**](https://huggingface.co/thetom-ai/MiniMax-M3-ConfigI-MLX)<br>*(MiniMax M3 MoE VL)* | **128k** / **32k**<br>*(SW: 128)* | `1.0` / `0.95` / `40` / `1.00` | 60 warstw, 128 ekspertów (top-4), sparse attention, kwantyzacja ConfigI, parser `minimax_m3` (`<mm:think>`), ~156 GB |
| 16 | [**Qwen3.8-27B-Coder390-...-MTP-DFlash2**](https://huggingface.co/nerkyor/Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2)<br>*(Qwen 3.5 Dense VL · BF16)* | **256k** / **32k**<br>*(Dense)* | `0.6` / `0.95` / `40` / `1.05` | Wagi BF16 (~30.6 GB), VLM, natywne Lightning MTP (`mtp-bf16`), KV 8-bit (`skip_last`), 34.6 tok/s, destylacja Opus 5.5 / GPT-6 / Grok 4.7 |
| 17 | [**Qwen3.8-Flash-Next-MTPLX-Optimized-Speed**](https://huggingface.co/Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed)<br>*(Qwen 4 Exp VL)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | 512 ekspertów (top-10), 128 shardów N-gram (32 GB), `qwen4_gdn_decode_wide_proj` (Fused GDN), KV 8-bit, ~73.5 tok/s (~120.8 GB) |
| 18 | [**flint-oQ8e**](https://huggingface.co/mlx-community/flint-oQ8e)<br>*(Recursive Flint MoE)* | **256k** / **32k**<br>*(SW: 513)* | `0.6` / `0.95` / `20` / `1.05` | MoE 39.8B (256 eksp., top-6 = 2.5B akt./tok), oQ8e iMatrix, dedykowany kernel MoE decode patch (`omlx_flint_router_topk`), reasoning `<think>`, do **74.1 tok/s** (~39.4 GB) |

---

## 2. Bezpośrednie Linki do Repozytoriów Hugging Face

Wszystkie modele znajdują się w lokalnym katalogu bazowym `~/.lmstudio/models/<Organizacja>/<Nazwa_Modelu>`:

| # | Identyfikator w oMLX / Hermes (`-m`) | Repozytorium Hugging Face | Format / Rozmiar |
| :-: | :--- | :--- | :--- |
| 1 | `Qwen3.5-122B-A10B-MLX-9bit` | [inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit) | MLX 9-bit MoE (~128 GB) |
| 2 | `Qwen3-Coder-Next-MLX-9bit` | [inferencerlabs/Qwen3-Coder-Next-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit) | MLX 9-bit MoE (~95 GB) |
| 3 | `Qwen3.8-27B-Uncensored-MLX` | [orcarouter/Qwen3.8-27B-Uncensored-MLX](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | MLX Dense 4-bit (~15 GB) |
| 4 | `Ornith-1.5-35B-A3B-Abliterated-MLX-BF16` | [PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16) | MLX BF16 MoE (~70 GB) |
| 5 | `Step-3.5-Flash-4bit` | [mlx-community/Step-3.5-Flash-4bit](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit) | MLX 4-bit MoE (~45 GB) |
| 6 | `UI-Venus-1.5-30B-A3B-qx86-hi-mlx` | [nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx) | MLX qx86 Vision (~30 GB) |
| 7 | `Laguna-S-2.1-MLX-8bit` | [Vontra/Laguna-S-2.1-MLX-8bit](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit) | MLX 8-bit MoE (~25 GB) |
| 8 | `DeepSeek-V4-Flash-0731-AWQ` | [True2456/DeepSeek-V4-Flash-0731-AWQ](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ) | AWQ / MLX MoE (~100 GB) |
| 9 | `Qwen3.8-27B-Uncensored-MLX-SPLASH` | [orcarouter/Qwen3.8-27B-Uncensored-MLX](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | Splash 1.4.0-m1 + DFlash2 (~15 GB) |
| 10 | `Qwen3-235B-A22B-MLX-4bit` | [Qwen/Qwen3-235B-A22B-MLX-4bit](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit) | MLX 4-bit MoE (~130 GB) |
| 11 | `Qwen3.8-Flash-Next-oQ5e-mtp` | [GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp) | MLX oQ5e iMatrix MTP (~135 GB) |
| 12 | `olmOCR-2-7B-1025-8bit` | [mlx-community/olmOCR-2-7B-1025-8bit](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit) | MLX 8-bit VLM (~8.8 GB) |
| 13 | `Unlimited-OCR-8bit` | [mlx-community/Unlimited-OCR-8bit](https://huggingface.co/mlx-community/Unlimited-OCR-8bit) | MLX 8-bit MoE VLM (~3.7 GB) |
| 14 | `DeepSeek-V4-Flash-0731-MXFP4-MLX` | [TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX](https://huggingface.co/TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX) | MLX MXFP4 MoE (~155 GB) |
| 15 | `MiniMax-M3-ConfigI-MLX` | [thetom-ai/MiniMax-M3-ConfigI-MLX](https://huggingface.co/thetom-ai/MiniMax-M3-ConfigI-MLX) | MLX ConfigI MoE VL (~156 GB) |
| 16 | `Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-`<br>`GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2` | [nerkyor/Qwen3.8-27B-Coder390-...-MTP-DFlash2](https://huggingface.co/nerkyor/Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2) | MLX BF16 VLM (~30.6 GB) |
| 17 | `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` | [Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed](https://huggingface.co/Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed) | MLX MTPLX Speed (~120.8 GB) |
| 18 | `flint-oQ8e` | [mlx-community/flint-oQ8e](https://huggingface.co/mlx-community/flint-oQ8e) | MLX oQ8e MoE (~39.4 GB) |
| *LoRA* | `salakash/Minimalism` *(Adapter)* | [salakash/Minimalism](https://huggingface.co/salakash/Minimalism) | LoRA Adapter (Qwen2.5-0.5B) |

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
* **Kompresor (`auxiliary.compression`):** `Qwen3.8-27B-Uncensored-MLX-SPLASH` (256k, ~15 GB, silnik **Splash 1.4.0-m1**)
* **Zasada działania:** Dedykowany, mniejszy model 27B realizuje podsumowania kontekstu napędzany ultraszybkim silnikiem Splash 1.4.0-m1 z podziałem GPU/ANE (`share 0.26`), buforowaniem query w pamięci threadgroup oraz akceleracją spekulatywną DFlash2 (`3.92` tok/cykl).
* **Integracja z Watchdogiem:** Model 27B Splash ma ustawioną flagę `"is_pinned": true` w `model_settings.json`, dzięki czemu demon Watchdoga nie wyładowuje go z pamięci obok modelu głównego.
* **Pamięć RAM:** 128 GB (122B) + 15 GB (27B) + ~1.3 GB (DFlash2 draft) = **~144 GB** (swobodnie mieści się w 192 GB Unified Memory z ~48 GB zapasu).
* **Zalety:** Błyskawiczny prefill, generowanie do **64.0 tok/s**, minimalny TTFT **0.31s** i zerowe obciążenie głównego modelu podczas kompresji.
* **Ograniczenie:** Wariant 2 nie powinien być używany z gigantami >150 GB (`DeepSeek-V4-Flash MXFP4`, `MiniMax-M3`), dla których należy aktywować Wariant 1 (Zero-Swap).

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

### 5.1. Obserwacja Produkcyjna: Skalowanie Prędkości `DeepSeek-V4-Flash-0731-MXFP4-MLX` w Funkcji Kontekstu

Analiza telemetrii `server.log` (porównanie `oMLX 0.7.2` oraz `oMLX 0.7.3.dev2`) wykazała silną zależność prędkości generowania (`TG tok/s`) od bieżącej długości promptu w sesji:

| Wersja oMLX | Długość kontekstu (`prompt`) | Czas kroku (`backbone / cykl`) | Akceptacja DSpark MTP (`tok/cykl`) | Prędkość generowania (`TG tok/s`) |
| :--- | ---: | ---: | ---: | ---: |
| `0.7.2` | **9 623 – 41 708** | `92.1 – 102.3 ms` | `3.30 – 3.65` (89–96%) | **31.0 – 34.6 tok/s** |
| `0.7.2` | **63 578** | `101.2 ms` | `3.03` (85.2%) | **28.3 tok/s** |
| `0.7.3.dev2` | **66 709** | **`95.0 ms`** | **`3.01` (92.5%)** | **30.0 tok/s** |
| `0.7.3.dev2` | **161 154** | `115.0 ms` | `2.98` (84.3%) | **24.7 tok/s** |
| `0.7.2` | **213 534 – 225 841** | `121.8 – 132.1 ms` | `2.58 – 2.76` (80–83%) | **20.9 – 21.7 tok/s** |
| `0.7.3.dev2` | **226 775 – 232 273** | `125.2 – 127.6 ms` | `2.88 – 3.10` (81–88%) | **21.5 – 23.7 tok/s** |

**Kluczowe wnioski techniczne z logów oMLX:**
1. **Brak regresji po aktualizacji do `0.7.3.dev2`:** Przy porównywalnym kontekście (`~65k` oraz `~226k` tokenów) wersja `0.7.3.dev2` utrzymuje o `~1–1.5 tok/s` wyższą przepustowość niż `0.7.2`, a natychmiast po kompresji kontekstu z `232k` do `66k` prędkość wraca w okolice **30+ tok/s**.
2. **Automatyczne wyłączenie TurboQuant KV przez *attention sinks*:** Pomimo ustawienia `turboquant_kv_enabled: true` w konfiguracji, podczas ładowania modelu scheduler oMLX loguje: `TurboQuant disabled: model uses attention sinks, which are not supported by TurboQuant's quantized attention kernels; keeping fp16 KV cache`. Przy wadze modelu `158.84 GB` w RAM i kontekście powyżej `225k` tokenów aktywuje się próg *Soft memory pressure* (`current=164.3GB, soft=164.1GB`), a koszt przeszukiwania bufora przez kernel `DSV4F/M2 v25 MMA indexer score` wydłuża krok `backbone` z `~95 ms` do `~128 ms` (+35%).
3. **Dynamika akceptacji wbudowanego draftera `embedded DSpark` (3 stages, width 3):** Na krótkim kontekście drafter osiąga 91–96% akceptacji (`3.5 tok/cykl`), natomiast przy głębokim kontekście (>210k) i generowaniu rozbudowanych argumentów JSON dla narzędzi (`finish_reason=tool_calls`) akceptacja spada do 80–84% (`2.6–2.9 tok/cykl`), co w połączeniu z dłuższym krokiem `backbone` daje wynikowe **~21–24 tok/s**.

---

## 6. Zestawienie Plików Konfiguracyjnych

- `config.yaml` / `config.variant1-single-model.yaml` – Konfiguracja Hermesa dla Wariantu 1.
- `config.variant2-dual-model.yaml` – Konfiguracja Hermesa dla Wariantu 2.
- `model_settings.json` / `model_settings.variant1-single-model.json` – Ustawienia modeli oMLX dla Wariantu 1.
- `model_settings.variant2-dual-model.json` – Ustawienia modeli oMLX dla Wariantu 2 (`Qwen 27B` jako `pinned`).
- `model_profiles.json` – Profile wykonawcze `work`, `turbo`, `setup` z pełnym oknem 256k.
- `settings.json` – Globalne parametry serwera oMLX.
- `switch-variant.sh` – Skrypt przełączania wariantów.
