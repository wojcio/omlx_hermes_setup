# oMLX & Hermes Setup

Zestaw zoptymalizowanych konfiguracji dla **oMLX** oraz **Hermes Agent** z precyzyjnie dobranymi oknami kontekstu (`max_context`), limitami wyjściowymi (`max_tokens`) oraz parametrami próbkowania (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty`) dla lokalnych modeli językowych na Apple Silicon (MLX).

---

## 📖 Pełna dokumentacja

Szczegółowy opis wszystkich 22 modeli (w tym zaawansowanego modelu MoE `DeepSeek-V4-Flash-0731-MXFP4-MLX` z oknem 1M oraz wyspecjalizowanych modeli Vision / OCR: `olmOCR-2-7B-1025-8bit`, `Unlimited-OCR-8bit`, `UI-Venus-1.5-30B`), bezpośrednie linki do repozytoriów Hugging Face, tabelę parametrów, analizę wariantów oraz uzasadnienie techniczne znajdziesz w pliku:

👉 **[Konfiguracja Modeli & Hugging Face (konfiguracja-modeli.md)](konfiguracja-modeli.md)**

---

## ⚡ Warianty Architektury

Repozytorium udostępnia dwa gotowe warianty konfiguracji:

1. **Wariant 1 (Domyślny & Rekomendowany): `Zero-Swap Dynamic` (Kompresor = Model Sesji)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (lub dowolny inny wybrany model, np. `DeepSeek-V4-Flash-0731-MXFP4-MLX`)
   - Kompresor: **Dynamiczny** (`auxiliary.compression.provider: auto`, `model: ''`) — zawsze kompresuje ten model, z którym aktualnie prowadzona jest rozmowa.
   - *Brak opóźnień związanych z przełączaniem modeli w pamięci RAM (0s swap latency) dla wszystkich 22 modeli.*

2. **Wariant 2: `Dual-Model Resident` (Dedykowany Szybki Kompresor 27B)**
   - Model główny: `Qwen3.5-122B-A10B-MLX-9bit` (256k)
   - Kompresor: `Qwen3.8-27B-Uncensored-MLX` (256k, ~15 GB w RAM, `is_pinned: true`)
   - *Szybki, dedykowany model do podsumowań kontekstu współistniejący z modelem głównym.*

### 🔄 Szybkie przełączanie wariantów:

```bash
# Przełączenie na Wariant 1 (rekomendowany, dynamiczny kompresor sesji):
./switch-variant.sh 1

# Przełączenie na Wariant 2 (dedykowany kompresor 27B):
./switch-variant.sh 2

# Wymuszenie trybu zdalnego (IP z pliku .env):
./switch-variant.sh 1 --remote

# Wymuszenie trybu lokalnego:
./switch-variant.sh 1 --local
```

### 🌐 Automatyczna Detekcja oMLX (Lokalny vs Zdalny Serwer)

Skrypt `./switch-variant.sh` automatycznie sprawdza, czy oMLX jest zainstalowany na bieżącej maszynie:
1. **Lokalny oMLX wykryty:** Konfiguruje Hermesa na `http://127.0.0.1:8000/v1` oraz synchronizuje pliki konfiguracyjne do `~/.omlx/`.
2. **Brak lokalnego oMLX:** Automatycznie przełącza Hermesa na zdalny serwer oMLX, pobierając adres IP z pliku `.env` (domyślnie `100.123.37.101` – prywatny serwer właściciela repozytorium dostępny via **Tailscale VPN**). Pomija katalog `~/.omlx/`.

> [!TIP]
> **Posiadasz własny serwer oMLX?**  
> Zmodyfikuj plik `.env`, wpisując własne IP serwera (`OMLX_IP=...`) oraz klucz (`OMLX_API_KEY=...`).

---

## 📁 Zawartość repozytorium

- **[`config.yaml`](config.yaml)** – Aktywna konfiguracja agenta Hermes (domyślnie Wariant 1).
- **[`config.variant1-single-model.yaml`](config.variant1-single-model.yaml)** – Konfiguracja Hermesa dla Wariantu 1 (kompresor dynamiczny).
- **[`config.variant2-dual-model.yaml`](config.variant2-dual-model.yaml)** – Konfiguracja Hermesa dla Wariantu 2 (kompresor 27B).
- **[`model_settings.json`](model_settings.json)** – Aktywny rejestr modeli w oMLX.
- **[`model_settings.variant1-single-model.json`](model_settings.variant1-single-model.json)** – Ustawienia modeli dla Wariantu 1.
- **[`model_settings.variant2-dual-model.json`](model_settings.variant2-dual-model.json)** – Ustawienia modeli dla Wariantu 2 (`Qwen 27B` przypięty w RAM).
- **[`model_profiles.json`](model_profiles.json)** – Dedykowane profile wykonawcze (`work`, `turbo`, `setup`).
- **[`settings.json`](settings.json)** – Globalne parametry serwera oMLX oraz domyślny sampling.
- **[`switch-variant.sh`](switch-variant.sh)** – Skrypt bash do automatycznego przełączania wariantów.
- **[`konfiguracja-modeli.md`](konfiguracja-modeli.md)** – Kompletna dokumentacja techniczna 22 modeli i linki Hugging Face.
