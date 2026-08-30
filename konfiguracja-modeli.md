# Konfiguracja Modeli: Hermes Agent & oMLX

Dokumentacja parametrów kontekstu, okien uwagi oraz parametrów samplingu dla modeli uruchamianych w oMLX i Hermes Agent.

---

## 1. Zestawienie Zbiorcze Modeli

| Model | Architektura | max_context (okno kontekstu) | windows (sliding window) | max_tokens (maks. wyjście) | Temperature | Top_p | Top_k | Repetition Penalty | Min_p / Pres. Pen. | Główne Cechy & Przeznaczenie |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Qwen3.5-122B-A10B-MLX-9bit** *(Domyślny)* | Qwen 3.5 MoE | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` *(work)* / `0.6` *(turbo)* | `0.95` | `20` | `1.05` | `0.01` / `1.05` | TurboQuant KV 8-bit, parser `qwen_3_5`, domyślny model główny |
| **Qwen3.8-Flash-Next-MLX-6bit** | Qwen 4 Exp | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Szybki profil `setup`, pełne rozumowanie |
| **Qwen3-Coder-Next-MLX-9bit** | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | RoPE theta 5M, TurboQuant KV 8-bit, generowanie długiego kodu i diffów |
| **Qwen3-Coder-Next-MLX-8bit** | Qwen 3 Next Coder | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.6` | `0.95` | `40` | `1.05` | `0.01` / `0.00` | Wersja 8-bitowa dla optymalizacji pamięci RAM |
| **Qwen3.8-27B-Uncensored-MLX** | Qwen 3.5 Dense | **262 144** (256k) | *Brak (Dense)* | **32 768** | `0.7` | `0.95` | `20` | `1.05` | `0.01` / `0.00` | Model ogólnego przeznaczenia bez cenzury |
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

## 2. Opis Parametrów i Uzasadnienie Wartości

### 1. `max_context` / `context_window` / `context_length`
- **Wartość bazowa: 262 144 (256k tokenów)** dla modeli z rodziny Qwen3.5/3.8/Coder, DeepSeek-V4, Step-3.5, Laguna oraz UI-Venus.
- **Wartości dedykowane**:
  - **Bielik-11B-v3.0-Instruct**: `32 768` (32k) – natywny limit embeddings architektury LLaMA tego wariantu.
  - **Qwen3-235B-A22B**: `40 960` (40k) – natywny limit warstwy `max_position_embeddings`.
- **Znaczenie**: Definiuje całkowitą maksymalną liczbę tokenów (prompt wejściowy + historia konwersacji + wynik narzędzi), jaką silnik może przetworzyć bez odrzucenia żądania.

### 2. `windows` (Sliding Window Attention)
- **DeepSeek-V4 Flash**: `128` – natywne okno lokalnej uwagi w połączeniu z globalną kompresją YaRN.
- **Step-3.5-Flash** oraz **Laguna-S-2.1**: `512` – sliding window optymalizujące prędkość prefillu przy długich kontekstach.
- **Pozostałe modele**: `Brak (Dense attention)` – model przetwarza cały kontekst w pełnej macierzy uwagi.

### 3. `max_tokens` (Maksymalna długość odpowiedzi)
- **Modele 256k**: `32 768` tokenów. Umożliwia swobodne generowanie kompletnych plików źródłowych, rozległych analiz kodu, raportów oraz ścieżek rozumowania w trybie thinking/reasoning.
- **UI-Venus (VLM)**: `16 384` tokenów – dopasowane do odpowiedzi multimodalnych i analizy interfejsów graficznych.
- **Bielik & Qwen-235B**: `8 192` tokenów – zrównoważone proporcje odpowiedzi do rozmiaru okna kontekstowego (32k/40k).

### 4. `temperature`
- **`0.6` dla modeli programistycznych i ścisłych**: `Qwen3-Coder-Next`, `DeepSeek-V4 Flash`, `Step-3.5-Flash`, profil `turbo` w Qwen3.5. Zapewnia determinizm i poprawność składniową.
- **`0.7` dla modeli ogólnych i asystenckich**: `Qwen3.5-122B`, `Qwen3.8-Flash-Next`, `Qwen3.8-27B`, `Bielik-11B`, `Laguna-S`. Optymalny balans kreatywności i precyzji logicznej.

### 5. `top_p` (Nucleus Sampling) & `min_p`
- **`top_p: 0.95`**: Standard branżowy dla modeli z rodziny Qwen, Step i DeepSeek.
- **`top_p: 0.90`**: Dla modelu Bielik-11B.
- **`top_p: 0.80`**: Dla modelu UI-Venus (zgodnie z natywną konfiguracją generacji).
- **`min_p: 0.01`**: Odrzuca skrajnie mało prawdopodobne tokeny z "ogona" rozkładu prawdopodobieństwa, zapobiegając halucynacjom.

### 6. `top_k`
- **`40`**: Dla modeli kodujących (`Qwen3-Coder-Next`), DeepSeek-V4 oraz Bielik (szerszy zbiór alternatywnych tokenów technicznych).
- **`20`**: Dla modeli konwersacyjnych i asystenckich.

### 7. `repetition_penalty` & `presence_penalty`
- **`1.00` (Brak kary)**: Modele **DeepSeek-V4** oraz **UI-Venus**. Architektury te są bardzo wrażliwe na kary powtórzeń; wyższe wartości mogą uszkadzać formatowanie JSON i generowanie bloków myślenia.
- **`1.05`**: Standard dla modeli **Qwen3.5 / 3.8 / Step / Laguna**. Skutecznie eliminuje zapętlenia w długich odpowiedziach bez degradacji składni.
- **`1.10`**: Model **Bielik-11B** (architektura LLaMA dobrze reaguje na nieco wyższą karę).
- **`presence_penalty: 1.05`**: Skonfigurowane dla profilu roboczego `Qwen3.5-122B-A10B-MLX-9bit`.

---

## 3. Szczegóły Konfiguracji Plików

### A. `config.yaml` (Hermes Agent)
- Zapewnia Hermesowi informację o dostępnych oknach kontekstowych per model w oMLX.
- Kluczowe ustawienia:
  ```yaml
  model:
    default: Qwen3.5-122B-A10B-MLX-9bit
    provider: omlx
    context_window: 262144
    context_length: 262144
    max_tokens: 32768
    base_url: http://127.0.0.1:8000/v1
  providers:
    omlx:
      default_model: Qwen3.5-122B-A10B-MLX-9bit
      models:
        Qwen3.5-122B-A10B-MLX-9bit:
          context_window: 262144
          context_length: 262144
          max_tokens: 32768
        # ... wszystkie 15 modeli skonfigurowane
  ```

### B. `settings.json` (oMLX Global Server)
- Globalne parametry domyślne serwera oMLX:
  ```json
  "sampling": {
    "max_context_window": 262144,
    "max_context_window_policy": null,
    "max_tokens": 32768,
    "temperature": 0.7,
    "top_p": 0.95,
    "top_k": 20,
    "repetition_penalty": 1.05
  }
  ```

### C. `model_profiles.json` (Profile oMLX)
- Dedykowane profile wykonawcze:
  - **Qwen3.5-122B `work`**: `max_context_window: 262144`, `max_tokens: 32768`, `temp: 0.7`, `thinking_budget_tokens: 8192`, `turboquant_kv_bits: 8`.
  - **Qwen3.5-122B `turbo`**: `max_context_window: 262144`, `max_tokens: 32768`, `temp: 0.6`, `turboquant_kv_bits: 8`.
  - **Qwen3.8-Flash-Next `setup`**: `max_context_window: 262144`, `max_tokens: 32768`, `temp: 0.7`.

### D. `model_settings.json` (Rejestr modeli oMLX)
- Precyzyjne wpisy per-model dla wszystkich modeli znajdujących się w katalogu `.lmstudio/models`.
- Automatyczne ładowanie optymalnego parsera rozumowania (`reasoning_parser: "qwen_3_5"`, `"deepseek_v4"`, `"poolside_v1"`).
- Włączenie kompresji pamięci KV TurboQuant (`turboquant_kv_bits: 8`) dla modeli o dużym zapotrzebowaniu na pamięć RAM.
