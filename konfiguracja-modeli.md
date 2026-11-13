# Konfiguracja Modeli: Hermes Agent & oMLX

Dokumentacja parametrów kontekstu, okien uwagi oraz parametrów samplingu dla modeli uruchamianych w oMLX i Hermes Agent na platformie Apple Silicon (MLX).

---

## 1. Zestawienie Zbiorcze Modeli

> **Wspólne parametry dla wszystkich modeli:** `min_p: 0.01` oraz `presence_penalty: 0.00` (ochrona struktur JSON/XML przed ucieczką tokenów).

| # | Model (Hugging Face) & Architektura | Okno / Wyjście<br>*(Sliding)* | Sampling<br>*(Temp / TopP / TopK / Rep)* | Akceleracja oMLX 0.8.0rc1 & Przeznaczenie |
| :-: | :--- | :---: | :---: | :--- |
| 1 | [**Qwen3.8-Flash-Next-oQ5e-mtp**](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp)<br>*(Domyślny · Qwen 4 Exp VL)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Format oQ5e iMatrix (typ `vlm`, ~119.9 GB), `activation_fp16_enabled` (2471 tensorów), `attn_fused`, 100 ścieżek Affine `hc_fused`, Lightning MTP (**67.5–97 tok/s**) |
| 2 | [**Qwen3.8-Flash-Next-oQ6e-mtp**](https://huggingface.co/Jundot/Qwen3.8-Flash-Next-oQ6e-mtp)<br>*(Qwen 4 Exp VL · 6-bit)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Wyższa precyzja oQ6e iMatrix (typ `vlm`, ~141.1 GB), `activation_fp16_enabled`, `attn_fused`, Affine `hc_fused`, Lightning MTP (**60.6–63.9 tok/s**, TTFT 0.58s) |
| 3 | [**Qwen3.8-Flash-Next-MTPLX-Optimized-Speed**](https://huggingface.co/Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed)<br>*(Qwen 4 Exp VL)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | 512 eksp. (top-10), 128 shardów N-gram, `activation_fp16_enabled`, `qwen4_gdn_decode_wide_proj` (Fused GDN/HC FP16), KV 8-bit, **~73.5 tok/s** (~120.8 GB) |
| 4 | [**GLM-5.3-Flash-oQ4e-mtp**](https://huggingface.co/Jundot/GLM-5.3-Flash-oQ4e-mtp)<br>*(GLM 5.3 Next MoE VL · 320B/A18B)* | **256k** / **32k**<br>*(1M native)* | `0.7` / `0.95` / `20` / `1.05` | Kolos 320B MoE (18B akt./tok, 173.9 GB w RAM bez offloadu przy suficie 186 GB), VLM, Fused KDA prework, Lightning MTP (82.5% akceptacji), **25.9–29.9 tok/s**, TTFT **0.17s** |
| 5 | [**gemma-4-12B-it-oQ8e-mtp**](https://huggingface.co/Jundot/gemma-4-12B-it-oQ8e-mtp)<br>*(Gemma 4 Unified · Any-to-Any)* | **256k** / **32k**<br>*(SW: 512)* | `0.7` / `0.95` / `64` / `1.05` | Multimodalny tekst/obraz/audio (~13.0 GB RAM), `activation_fp16_enabled`, TurboQuant KV 8-bit, Lightning MTP (80.3–92.4%, do `d8`), **51.4–68.4 tok/s** |
| 6 | [**gemma-4-31B-it-oQ6e-mtp**](https://huggingface.co/Jundot/gemma-4-31B-it-oQ6e-mtp)<br>*(Gemma 4 Dense VL · 31B)* | **256k** / **32k**<br>*(SW: 1024)* | `0.7` / `0.95` / `64` / `1.05` | Gęsty 31B VLM (~26.3 GB RAM), `activation_fp16_enabled` (+42% speedup), `gemma4_verify_kernel`, TurboQuant KV 8-bit, Lightning MTP (88.4%, `4.38 tok/cykl`), **32.4–34.0 tok/s** |
| 7 | [**Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed**](https://huggingface.co/Youssofal/Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed)<br>*(Prism Hadamard Qwen 3.5 VL)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Ultralekki 2-bit Hadamard 27B VLM (zaledwie **8.23 GB RAM**, automatyczne zwolnienie 420 MB biasów t5), TurboQuant KV 8-bit, **31.4 tok/s**, TTFT 0.77s |
| 8 | [**Nanbeige4.3-33B-MLX-6bit**](https://huggingface.co/PocketAiHub/Nanbeige4.3-33B-MLX-6bit)<br>*(Llama Dense 33B · 512k)* | **512k** / **32k**<br>*(Dense)* | `0.6` / `0.95` / `20` / `1.05` | Gęsty 33B model agentowy i programistyczny (~25.2 GB RAM) z gigantycznym oknem **524 288 tokenów (512k)**, TurboQuant KV 8-bit (`skip_last`), **19.6 tok/s** |
| 9 | [**flint-oQ8e**](https://huggingface.co/mlx-community/flint-oQ8e)<br>*(Recursive Flint MoE)* | **256k** / **32k**<br>*(SW: 513)* | `0.6` / `0.95` / `20` / `1.05` | MoE 39.8B (256 eksp., top-6 = 2.5B akt./tok), oQ8e iMatrix, dedykowany kernel MoE decode patch (`omlx_flint_router_topk`), reasoning `<think>`, do **74.1 tok/s** (~39.4 GB) |
| 10 | [**Qwen3.8-27B-Coder390-...-MTP-DFlash2**](https://huggingface.co/nerkyor/Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2)<br>*(Qwen 3.5 Dense VL · BF16)* | **256k** / **32k**<br>*(Dense)* | `0.6` / `0.95` / `40` / `1.05` | Wagi BF16 (~30.6 GB), VLM, natywne Lightning MTP (`mtp-bf16`), `activation_fp16_enabled`, KV 8-bit (`skip_last`), **34.6 tok/s**, destylacja Opus 5.5 / GPT-6 / Grok 4.7 |
| 11 | [**Qwen3.8-27B-Uncensored-MLX-SPLASH**](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX)<br>*(Qwen 3.5 Dense · Splash)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Silnik Splash **1.6.1-m1** (Metal/ANE FFN split `0.26`, One memory ledger, Idle KV + DFlash2 draft), **69.2 tok/s śr.** (szczyt **91.2 tok/s**), kompresor Wariantu 2 |
| 12 | [**Qwen3.8-27B-Uncensored-MLX**](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX)<br>*(Qwen 3.5 Dense)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Lekki model (~15 GB), natywne spekulatywne dekodowanie DFlash2 (`Qwen3.8-27B-DFlash2`), TurboQuant KV 8-bit (`skip_last`) |
| 13 | [**DeepSeek-V4-Flash-0731-MXFP4-MLX**](https://huggingface.co/TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX)<br>*(DeepSeek V4 MoE)* | **256k** / **32k**<br>*(SW: 128)* | `0.6` / `0.95` / `40` / `1.00` | YaRN RoPE (factor 16), SW 128, embedded DSpark MTP (depth 3), `fp16` KV (*attention sinks*), 31–34.6 tok/s (<45k) / ~21–24 tok/s (>210k), ~159 GB |
| 14 | [**DeepSeek-V4-Flash-0731-AWQ**](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ)<br>*(DeepSeek V4 MoE)* | **256k** / **32k**<br>*(SW: 128)* | `0.6` / `0.95` / `40` / `1.00` | YaRN RoPE (factor 16), sliding window 128, Lightning MTP, MLA Latent Attention (~100 GB) |
| 15 | [**MiniMax-M3-ConfigI-MLX**](https://huggingface.co/thetom-ai/MiniMax-M3-ConfigI-MLX)<br>*(MiniMax M3 MoE VL)* | **128k** / **32k**<br>*(SW: 128)* | `1.0` / `0.95` / `40` / `1.00` | 60 warstw, 128 ekspertów (top-4), sparse attention, kwantyzacja ConfigI, parser `minimax_m3` (`<mm:think>`), ~156 GB *(znany błąd >4k tok: `jundot/omlx#5233`)* |
| 16 | [**Ornith-1.5-35B-A3B-Abliterated-MLX-BF16**](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16)<br>*(Qwen 3.5 MoE)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Model MoE BF16 bez cenzury z pełnym oknem 256k, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up (~70 GB) |
| 17 | [**Step-3.5-Flash-4bit**](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit)<br>*(Step 3.5 MoE)* | **256k** / **32k**<br>*(SW: 512)* | `0.6` / `0.95` / `20` / `1.05` | Llama3 RoPE scaling (2.0x), sliding window 512, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up (~45 GB) |
| 18 | [**Laguna-S-2.1-MLX-8bit**](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit)<br>*(Laguna MoE)* | **256k** / **32k**<br>*(SW: 512)* | `0.7` / `0.95` / `20` / `1.05` | Sliding window 512, natywny parser `laguna` w oMLX 0.7.2+, Fused MoE Gate/Up, TurboQuant KV 8-bit (`skip_last`) (~25 GB) |
| 19 | [**UI-Venus-1.5-30B-A3B-qx86-hi-mlx**](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx)<br>*(Qwen 3 VL MoE)* | **256k** / **16k**<br>*(Dense)* | `0.7` / `0.80` / `20` / `1.00` | Model multimodalny Vision / UI, typ `vlm`, TurboQuant KV 8-bit (`skip_last`) (~30 GB) |
| 20 | [**olmOCR-2-7B-1025-8bit**](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit)<br>*(Qwen 2.5 VL)* | **128k** / **8k**<br>*(Dense)* | `0.2` / `0.90` / `20` / `1.05` | Model VLM do zaawansowanego OCR dokumentów PDF, tabel, wzorów i układów wielokolumnowych (~8.8 GB) |
| 21 | [**Unlimited-OCR-8bit**](https://huggingface.co/mlx-community/Unlimited-OCR-8bit)<br>*(UnlimitedOCR MoE)* | **32k** / **8k**<br>*(SW: 128)* | `0.2` / `0.90` / `20` / `1.05` | Model VLM OCR bez limitu rozdzielczości obrazu (downsampling/tiling 2D), odczyt faktur i etykiet (`trust_remote_code`, ~3.7 GB) |
| 22 | [**[HDD] Qwen3.5-122B-A10B-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit)<br>*(Qwen 3.5 MoE · Archiwum HDD)* | **256k** / **32k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up, parser `qwen_3_5`, podlinkowany na `/Volumes/Seagate_Expansion_Drive/LLM` (~128 GB) |
| 23 | [**[HDD] Qwen3-Coder-Next-MLX-9bit**](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit)<br>*(Qwen 3 Next Coder · Archiwum HDD)* | **256k** / **32k**<br>*(Dense)* | `0.6` / `0.95` / `40` / `1.05` | RoPE theta 5M, TurboQuant KV 8-bit (`skip_last`), Fused MoE Gate/Up, podlinkowany na `/Volumes/Seagate_Expansion_Drive/LLM` (~83 GB) |
| 24 | [**[HDD] Qwen3-235B-A22B-MLX-4bit**](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit)<br>*(Qwen 3 MoE · Archiwum HDD)* | **40k** / **8k**<br>*(Dense)* | `0.7` / `0.95` / `20` / `1.05` | Natywne okno bazowe 40 960 tokenów, TurboQuant KV 8-bit (`skip_last`), podlinkowany na `/Volumes/Seagate_Expansion_Drive/LLM` (~116 GB) |

---

## 2. Bezpośrednie Linki do Repozytoriów Hugging Face

Wszystkie modele znajdują się w lokalnym katalogu bazowym `~/.lmstudio/models/<Organizacja>/<Nazwa_Modelu>` (modele `[HDD]` są dowiązaniami symbolicznymi do `/Volumes/Seagate_Expansion_Drive/LLM/<Organizacja>/<Nazwa_Modelu>`):

| # | Identyfikator w oMLX / Hermes (`-m`) | Repozytorium Hugging Face | Format / Rozmiar |
| :-: | :--- | :--- | :--- |
| 1 | `Qwen3.8-Flash-Next-oQ5e-mtp` | [GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp](https://huggingface.co/GBP-DE/Qwen3.8-Flash-Next-oQ5e-mtp) | MLX oQ5e iMatrix MTP (~119.9 GB) |
| 2 | `Qwen3.8-Flash-Next-oQ6e-mtp` | [Jundot/Qwen3.8-Flash-Next-oQ6e-mtp](https://huggingface.co/Jundot/Qwen3.8-Flash-Next-oQ6e-mtp) | MLX oQ6e iMatrix MTP (~141.1 GB) |
| 3 | `Qwen3.8-Flash-Next-MTPLX-Optimized-Speed` | [Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed](https://huggingface.co/Youssofal/Qwen3.8-Flash-Next-MTPLX-Optimized-Speed) | MLX MTPLX Speed (~120.8 GB) |
| 4 | `GLM-5.3-Flash-oQ4e-mtp` | [Jundot/GLM-5.3-Flash-oQ4e-mtp](https://huggingface.co/Jundot/GLM-5.3-Flash-oQ4e-mtp) | MLX oQ4e 320B MoE MTP (~173.9 GB) |
| 5 | `gemma-4-12B-it-oQ8e-mtp` | [Jundot/gemma-4-12B-it-oQ8e-mtp](https://huggingface.co/Jundot/gemma-4-12B-it-oQ8e-mtp) | MLX oQ8e Any-to-Any MTP (~13.0 GB) |
| 6 | `gemma-4-31B-it-oQ6e-mtp` | [Jundot/gemma-4-31B-it-oQ6e-mtp](https://huggingface.co/Jundot/gemma-4-31B-it-oQ6e-mtp) | MLX oQ6e Dense VLM MTP (~26.3 GB) |
| 7 | `Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed` | [Youssofal/Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed](https://huggingface.co/Youssofal/Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed) | MLX 2-bit Hadamard VLM (~8.23 GB) |
| 8 | `Nanbeige4.3-33B-MLX-6bit` | [PocketAiHub/Nanbeige4.3-33B-MLX-6bit](https://huggingface.co/PocketAiHub/Nanbeige4.3-33B-MLX-6bit) | MLX 6-bit Dense 512k (~25.2 GB) |
| 9 | `flint-oQ8e` | [mlx-community/flint-oQ8e](https://huggingface.co/mlx-community/flint-oQ8e) | MLX oQ8e MoE (~39.4 GB) |
| 10 | `Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-`<br>`GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2` | [nerkyor/Qwen3.8-27B-Coder390-...-MTP-DFlash2](https://huggingface.co/nerkyor/Qwen3.8-27B-Coder390-EfficientThink-Opus5.5-GPT6Astra-Grok4.7-DSV4Pro-K3-SFT-RLOO-MTP-DFlash2) | MLX BF16 VLM (~30.6 GB) |
| 11 | `Qwen3.8-27B-Uncensored-MLX-SPLASH` | [orcarouter/Qwen3.8-27B-Uncensored-MLX](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | Splash 1.6.1-m1 + DFlash2 (~15 GB) |
| 12 | `Qwen3.8-27B-Uncensored-MLX` | [orcarouter/Qwen3.8-27B-Uncensored-MLX](https://huggingface.co/orcarouter/Qwen3.8-27B-Uncensored-MLX) | MLX Dense 4-bit (~15 GB) |
| 13 | `DeepSeek-V4-Flash-0731-MXFP4-MLX` | [TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX](https://huggingface.co/TensorFold/DeepSeek-V4-Flash-0731-MXFP4-MLX) | MLX MXFP4 MoE (~159 GB) |
| 14 | `DeepSeek-V4-Flash-0731-AWQ` | [True2456/DeepSeek-V4-Flash-0731-AWQ](https://huggingface.co/True2456/DeepSeek-V4-Flash-0731-AWQ) | AWQ / MLX MoE (~100 GB) |
| 15 | `MiniMax-M3-ConfigI-MLX` | [thetom-ai/MiniMax-M3-ConfigI-MLX](https://huggingface.co/thetom-ai/MiniMax-M3-ConfigI-MLX) | MLX ConfigI MoE VL (~156 GB) |
| 16 | `Ornith-1.5-35B-A3B-Abliterated-MLX-BF16` | [PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16](https://huggingface.co/PocketAiHub/Ornith-1.5-35B-A3B-Abliterated-MLX-BF16) | MLX BF16 MoE (~70 GB) |
| 17 | `Step-3.5-Flash-4bit` | [mlx-community/Step-3.5-Flash-4bit](https://huggingface.co/mlx-community/Step-3.5-Flash-4bit) | MLX 4-bit MoE (~45 GB) |
| 18 | `Laguna-S-2.1-MLX-8bit` | [Vontra/Laguna-S-2.1-MLX-8bit](https://huggingface.co/Vontra/Laguna-S-2.1-MLX-8bit) | MLX 8-bit MoE (~25 GB) |
| 19 | `UI-Venus-1.5-30B-A3B-qx86-hi-mlx` | [nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx](https://huggingface.co/nightmedia/UI-Venus-1.5-30B-A3B-qx86-hi-mlx) | MLX qx86 Vision (~30 GB) |
| 20 | `olmOCR-2-7B-1025-8bit` | [mlx-community/olmOCR-2-7B-1025-8bit](https://huggingface.co/mlx-community/olmOCR-2-7B-1025-8bit) | MLX 8-bit VLM (~8.8 GB) |
| 21 | `Unlimited-OCR-8bit` | [mlx-community/Unlimited-OCR-8bit](https://huggingface.co/mlx-community/Unlimited-OCR-8bit) | MLX 8-bit MoE VLM (~3.7 GB) |
| 22 | `Qwen3.5-122B-A10B-MLX-9bit` *(`[HDD]`)* | [inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3.5-122B-A10B-MLX-9bit) | MLX 9-bit MoE (~128 GB · USB-C HDD) |
| 23 | `Qwen3-Coder-Next-MLX-9bit` *(`[HDD]`)* | [inferencerlabs/Qwen3-Coder-Next-MLX-9bit](https://huggingface.co/inferencerlabs/Qwen3-Coder-Next-MLX-9bit) | MLX 9-bit MoE (~83 GB · USB-C HDD) |
| 24 | `Qwen3-235B-A22B-MLX-4bit` *(`[HDD]`)* | [Qwen/Qwen3-235B-A22B-MLX-4bit](https://huggingface.co/Qwen/Qwen3-235B-A22B-MLX-4bit) | MLX 4-bit MoE (~116 GB · USB-C HDD) |
| *LoRA* | `salakash/Minimalism` *(Adapter)* | [salakash/Minimalism](https://huggingface.co/salakash/Minimalism) | LoRA Adapter (Qwen2.5-0.5B) |

---

## 3. Warianty Architektury Kompresora w Hermesie

Dostępne są dwa zoptymalizowane warianty konfiguracji:

### 🏆 Wariant 1: Zero-Swap Dynamic (Domyślny & Rekomendowany: Kompresor = Model Sesji)
* **Model główny:** Dowolny z 24 modeli (domyślnie `Qwen3.8-Flash-Next-oQ5e-mtp`)
* **Kompresor (`auxiliary.compression`):** `provider: auto`, `model: ""`
* **Zasada działania:** Hermes dynamicznie używa do kompresji tego samego modelu, który aktualnie prowadzi konwersację (`Qwen3.8-Flash-Next`, `GLM-5.3-Flash`, `Gemma 4`, `flint-oQ8e` itd.).
* **Zalety:**
  - **0 sekund opóźnienia przełączania modeli (Zero Swap)** – model jest już w RAM i w pamięci podręcznej KV.
  - Pełna dynamika: zmiana modelu w Hermesie automatycznie zmienia model wykonujący kompresję.
  - 100% zgodność z regułą pojedynczego modelu w RAM (`len(loaded) <= 1`, sufit pamięci oMLX `186 GB`).

### ⚡ Wariant 2: Dual-Model Resident (Szybki Dedykowany Kompresor 27B)
* **Model główny:** `Qwen3.8-Flash-Next-oQ5e-mtp` (256k, ~119.9 GB)
* **Kompresor (`auxiliary.compression`):** `Qwen3.8-27B-Uncensored-MLX-SPLASH` (256k, ~15 GB, silnik **Splash 1.6.1-m1**)
* **Zasada działania:** Dedykowany, mniejszy model 27B realizuje podsumowania kontekstu napędzany ultraszybkim silnikiem Splash 1.6.1-m1 z podziałem GPU/ANE (`share 0.26`), zarządcą pamięci `One memory ledger`, optymalizacją `Idle KV` oraz akceleracją spekulatywną DFlash2 (`3.5–3.92` tok/cykl).
* **Integracja z Watchdogiem:** Model 27B Splash ma ustawioną flagę `"is_pinned": true` w `model_settings.json`, dzięki czemu demon Watchdoga nie wyładowuje go z pamięci obok modelu głównego.
* **Pamięć RAM:** ~120 GB (`Flash-Next-oQ5e`) + 15 GB (`27B Splash`) + ~1.3 GB (`DFlash2 draft`) = **~136.3 GB** (swobodnie mieści się w 186 GB limitu Metal z ~50 GB zapasu).
* **Zalety:** Błyskawiczny prefill, generowanie do **69.2 tok/s śr. / 91.2 tok/s szczyt**, minimalny TTFT **0.31s** i zerowe obciążenie głównego modelu podczas kompresji.
* **Ograniczenie:** Wariant 2 nie powinien być używany z gigantami >150 GB (`GLM-5.3-Flash-oQ4e-mtp` 173.9 GB, `DeepSeek-V4-Flash MXFP4` 159 GB, `MiniMax-M3` 156 GB), dla których należy aktywować Wariant 1 (Zero-Swap).

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

### 5.2. Benchmark 7 Nowych Modeli MLX/MTP (Listopad 2026, oMLX 0.7.4.dev1, Limit 186 GB RAM)

Wyniki pomiarów przeprowadzonych na Mac Studio M2 Ultra (192 GB Unified Memory, `iogpu.wired_limit_mb=186777`, `memory_guard_custom_ceiling_gb: 186.0`):

| Model | Architektura | RAM w oMLX | TTFT (Hot) | Prędkość Decode (`tok/s`) | Akceleracja MTP / FP16 Recast |
| :--- | :--- | ---: | ---: | ---: | :--- |
| **`Qwen3.8-Flash-Next-oQ5e-mtp`** *(ref)* | `qwen4_exp` (VLM) | `119.90 GB` | `0.58s` | **67.52 – 72.98 tok/s** | `activation_fp16_enabled: true`, MTP 65.6–79.8% (`2.24 tok/cykl`) |
| **`Qwen3.8-Flash-Next-oQ6e-mtp`** | `qwen4_exp` (VLM, 6-bit) | `141.08 GB` | `0.58s` | **60.62 – 63.92 tok/s** | `activation_fp16_enabled: true`, MTP 60.9–69.7% (`2.59 tok/cykl`) |
| **`GLM-5.3-Flash-oQ4e-mtp`** | `glm5_next` (320B/A18B VLM) | `173.86 GB` | **`0.17s`** *(bf16)* | **25.85 – 29.89 tok/s** | 100% w RAM, Fused KDA prework, MTP 82.5% (`3.00 tok/cykl`) |
| **`GLM-5.3-Flash-oQ2e-mtp`** | `glm5_next` (320B/A18B VLM) | `102.87 GB` | `0.81s` | **32.05 – 37.63 tok/s** | Hybrydowy 2-bit/4-bit (-71 GB RAM!), Fused KDA, MTP 71.5–77.3% (`2.39 tok/cykl`) |
| **`gemma-4-12B-it-oQ8e-mtp`** | `gemma4_unified` (VLM/Audio) | `13.01 GB` | `0.60s` | **51.38 – 68.38 tok/s** | `activation_fp16_enabled: true`, MTP 80.3–92.4% (`3.34 tok/cykl`, depth `d8`) |
| **`gemma-4-31B-it-oQ6e-mtp`** | `gemma4` (Dense 31B VLM) | `26.25 GB` | `0.93s` | **32.41 – 34.03 tok/s** | `activation_fp16_enabled: true` (+42% speedup), `gemma4_verify_kernel`, MTP 88.4% (`4.38 tok/cykl`) |
| **`Ternary-Bonsai-2-27B-MTPLX-Optimized-Speed`** | `prism_hadamard_qwen35` (VLM) | **`8.23 GB`** | `0.77s` | **31.41 tok/s** | 2-bit Hadamard, automatyczne zwolnienie 420 MB biasów t5, KV 8-bit |
| **`Nanbeige4.3-33B-MLX-6bit`** | `llama` (Dense 33B, **512k**) | `25.23 GB` | `0.93s` | **19.42 – 19.58 tok/s** | Okno kontekstu **524 288 tokenów (512k)**, KV 8-bit (`skip_last`) |

### 5.3. Porównanie A/B `GLM-5.3-Flash-oQ2e-mtp` vs `GLM-5.3-Flash-oQ4e-mtp` (13 Listopada 2026)

Bezpośrednie testy porównawcze na Mac Studio M2 Ultra (192 GB RAM, czyste wywołania API oMLX w trybie domyślnym `Max` z pełnym czyszczeniem RAM między modelami):

* **Architektura kwantów (`README.md` / `oq_imatrix_report.json`):** W obu checkpointach warstwy krytyczne (`8.976B` wag Affine 8-bit, `0.607B` BF16, `0.086B` FP32, Vision Encoder `1.050 GiB`, głowica MTP `4.013 GiB`) oraz kalibracja imatrix (`oqe_code_multilingual`, 100% pokrycia `38 688` ekspertów) są identyczne. Różni się wyłącznie `304.406B` wag routowanych ekspertów MoE (Affine 2-bit `2.746 bpw` w `oQ2e` vs Affine 4-bit `4.641 bpw` z nowszym „Better Low-Bit oQ” `#4776` w `oQ4e`).
* **Pamięć i szybkość:**
  * `oQ2e-mtp`: `102.87 GB` w RAM (`107.86 GB` estymacja), cold-load **18.87 s**, generacja **30.4–35.1 tok/s**.
  * `oQ4e-mtp`: `173.73 GB` w RAM (`182.28 GB` estymacja pod limitem `186 GB`), cold-load **177.07 s**, generacja **25.0–30.0 tok/s**, wyraźnie głębsze trafienia MTP (`d3 = 968/1285` vs `414/546` w zadaniu kombinatorycznym).
* **Jakość rozumowania i wnioski konfiguracyjne:**
  * **Tool-calling na czystym prompcie:** oba modele zdały w ~5.4–5.6 s (`oQ4e` w 37 tok, `oQ2e` w 67 tok).
  * **Wielowarunkowa logika / bug-hunt / kombinatoryka:** `oQ4e` rozwiązał zagadkę z 5 warunkami bezbłędnie (wyłapując dodatkowo dwuznaczność sformułowania) oraz użył zwięzłego dowodu bijekcją, podczas gdy `oQ2e` pogubił warunek w zagadce logicznej i częściej wpadał w rozwlekłe wyliczanie ręczne lub pętle powtórzeń w długim `<think>`.
  * **Korekta ustawień (historyczna) i decyzja końcowa (13 Listopada 2026):** mimo podniesienia okna `oQ2e-mtp` do `524 288` i `temperature: 1.0`, w wieloturowym benchmarku OpenCode (`omlx_bench.sh`) `GLM-5.3-Flash-oQ2e-mtp` przegrał zdecydowanie z lżejszym i ponad 2x szybszym `Qwen3.8-Flash-Next-oQ5e-mtp` (oraz `oQ4e-mtp`), dlatego **`GLM-5.3-Flash-oQ2e-mtp` został trwale usunięty** z dysku SSD (~103 GiB odzyskane) i konfiguracji (`24` modele w Hermesie / `26` w oMLX). **`GLM-5.3-Flash-oQ4e-mtp`** pozostaje przy `262 144` (256k) i `temperature: 0.7`.
  * **Pułapka `chat_template.jinja`:** szablon modelu rozpoznaje wyłącznie `low` i `high` — każde inne ustawienie (w tym `effort: medium` z Hermesa) aktywuje tryb **`Max`**.

### 5.4. Benchmark OpenCode (`omlx_bench.sh`) & Splash `1.6.1-m1` (13 Listopada 2026)

* **Zautomatyzowany benchmark [`./omlx_bench.sh`](omlx_bench.sh):** testuje wszystkie aktywne modele z SSD (pomijając `[HDD]`) tym samym wieloturowym zapytaniem narzędziowym OpenCode (`describe the repo in this directory`).
* **`Splash 1.6.1-m1` (`Qwen3.8-27B-Uncensored-MLX-SPLASH`):** po aktualizacji silnika do **`1.6.1-m1`** model zaliczył pełny bieg OpenCode (`PASS w 197.2s | tury=4 tools=6(rep=0) max_prompt=28792 avg_tps=69.2 odp=3601 zn.`, szczyt **91.2 tok/s** w 2. turze).
* **Archiwizacja `Qwen3.8-27B-FP16_huzar_v1-SPLASH` (`[HDD]`):** oznaczony jako `[HDD]` w `model_settings*.json` oraz OpenCode.
* **Błąd `MiniMax-M3-ConfigI-MLX` > 4096 tokenów (`jundot/omlx#5233`):** zgłoszony błąd `ValueError: Thread group size (512) is greater than the maximum allowed threads per threadgroup (384).` w `msa_sparse_attention_b1` na M2 Ultra.

---

## 6. Zestawienie Plików Konfiguracyjnych

- `config.yaml` / `config.variant1-single-model.yaml` – Konfiguracja Hermesa dla Wariantu 1.
- `config.variant2-dual-model.yaml` – Konfiguracja Hermesa dla Wariantu 2.
- `model_settings.json` / `model_settings.variant1-single-model.json` – Ustawienia modeli oMLX dla Wariantu 1.
- `model_settings.variant2-dual-model.json` – Ustawienia modeli oMLX dla Wariantu 2 (`Qwen 27B` jako `pinned`).
- `model_profiles.json` – Profile wykonawcze `work`, `turbo`, `setup` z pełnym oknem 256k.
- `settings.json` – Globalne parametry serwera oMLX.
- `switch-variant.sh` – Skrypt przełączania wariantów.
