# oMLX & Hermes Setup

Zestaw zoptymalizowanych konfiguracji dla **oMLX** oraz **Hermes Agent** z precyzyjnie dobranymi oknami kontekstu (`max_context`), limitami wyjściowymi (`max_tokens`) oraz parametrami próbkowania (`temperature`, `top_p`, `top_k`, `repetition_penalty`, `min_p`, `presence_penalty`) dla lokalnych modeli językowych na Apple Silicon (MLX).

---

## 📖 Pełna dokumentacja

Szczegółowy opis wszystkich 15 modeli, tabelę parametrów oraz uzasadnienie techniczne znajdziesz w pliku:

👉 **[Konfiguracja Modeli (konfiguracja-modeli.md)](konfiguracja-modeli.md)**

---

## 📁 Zawartość repozytorium

- **[`config.yaml`](config.yaml)** – Główna konfiguracja agenta Hermes (odblokowane pełne okna kontekstowe per-model do 256k tokenów).
- **[`settings.json`](settings.json)** – Globalne parametry serwera oMLX oraz domyślny sampling.
- **[`model_settings.json`](model_settings.json)** – Rejestr konfiguracji per-model w oMLX (parser myślenia, TurboQuant KV 8-bit, parametry samplingu).
- **[`model_profiles.json`](model_profiles.json)** – Dedykowane profile wykonawcze (`work`, `turbo`, `setup`).
- **[`konfiguracja-modeli.md`](konfiguracja-modeli.md)** – Kompletna dokumentacja modeli i ich specyfikacji technicznej.
