# Skill: oMLX Compression Sync (kompresor = model w RAM)

**Data:** 31 sierpnia 2026
**Repozytorium:** `omlx_hermes_setup` (branch: `skill_kompresor`)
**Źródło kodu:** `scripts/omlx-compression-sync.py` + watchdog launchd `com.hermes.omlx-compression-sync.plist`

---

## 🎯 Problem

Hermes używa modelu z konfiguracji `auxiliary.compression.model` do kompresji kontekstu.
W tym repozytorium warianty `config.variant1-single-model.yaml` i `config.variant2-dual-model.yaml`
**hardcodują** kompresora na stałą nazwę modelu (`Qwen3.5-122B` albo `Qwen3.8-27B`).

Gdy użytkownik przeładowuje model w oMLX (np. na `Ornith-1.5-35B-A3B-Abliterated-MLX-BF16`),
kompresor nadal wskazuje stary model. Skutek: **każda kompresja wymusza cold-reload drugiego
modelu w RAM** — złamanie zasady „1 model w RAM" (watchdog single-model-guard) i ~1 min
opóźnienia przeładowania ~130 GB modelu.

## 🧠 Rozwiązanie

Skrypt `omlx-compression-sync.py`:
1. Czyta model **aktywny w RAM** z oMLX `/api/status` (`loaded_models[0]`) — to jedyne
   niezawodne źródło prawdy o tym, który model fizycznie jest załadowany.
2. Porównuje go z `auxiliary.compression.model` z `~/.hermes/config.yaml`.
3. Gdy się różnią — ustawia `auxiliary.compression.model` na model z RAM przez
   `hermes config set`.

### Dlaczego to działa bez restartu

Hermes czyta `auxiliary.compression.model` **per-call** (patrz
`agent/auxiliary_client.py::_get_auxiliary_task_config`), z invalidacją cache po mtime pliku
(config.py `_load_config_impl`). Zmiana w config.yamli → **live**, bez restartu Hermesa czy oMLX.

Skrypt jest **idempotentny**: gdy model w RAM = kompresor, nic nie pisze.

### Dlaczego zero-swap

Model kompresora wskazuje na ten sam model, który jest już w RAM (Ornith).
Użycie go do kompresji **nie wymaga przeładowania** — model jest już załadowany.
Zero latency, zero ryzyka dla single-model-guard.

---

## 📂 Pliki w repozytorium

| Plik | Opis |
|------|------|
| `scripts/omlx-compression-sync.py` | Skrypt synchronizujący kompresora z modelem w RAM |
| `com.hermes.omlx-compression-sync.plist` | Watchdog launchd (co 60s, RunAtLoad) — instalowany do `~/Library/LaunchAgents/` |
| `switch-variant.sh` | **Zaktualizowany** — na końcu wywołuje `omlx-compression-sync.py` |
| `skill_kompresor.md` | Ten dokument |

---

## ⚙️ Instalacja watchdoga (launchd)

```bash
# 1. Skrypt już jest w ~/.hermes/scripts/omlx-compression-sync.py
# 2. Plist do LaunchAgents:
cp scripts/com.hermes.omlx-compression-sync.plist ~/Library/LaunchAgents/

# 3. Załaduj:
launchctl unload ~/Library/LaunchAgents/com.hermes.omlx-compression-sync.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.hermes.omlx-compression-sync.plist

# 4. Sprawdź:
launchctl list | grep compression-sync
```

Watchdog uruchamia się przy starcie (`RunAtLoad: true`) i co 60s.
Logi: `~/.omlx/logs/omlx-compression-sync.log`.

---

## 🧪 Testowanie (manualne)

```bash
# Jednorazowe uruchomienie:
python3 /Users/wojcio/.hermes/scripts/omlx-compression-sync.py
echo $?   # 0 = OK

# Idempotency check (powrót → „no change"):
python3 /Users/wojcio/.hermes/scripts/omlx-compression-sync.py

# Log:
tail -3 /Users/wojcio/.omlx/logs/omlx-compression-sync.log
```

---

## 🔑 Auth

Skrypt czyta klucz API oMLX z `~/.omlx/settings.json` (`auth.api_key`) — **nigdy go nie wypisuje**.
Do `/api/status` używa `Authorization: Bearer <key>` (zaakceptowane przez oMLX).

---

## ✅ Status implementacji (31.08.2026)

- [x] Skrypt `omlx-compression-sync.py` — napisany, przetestowany (sync → applied → idempotent)
- [x] Watchdog launchd `com.hermes.omlx-compression-sync.plist` — zainstalowany, aktywny (PID 45816)
- [x] `auxiliary.compression.model` = `Ornith-1.5-35B-A3B-Abliterated-MLX-BF16` (model w RAM)
- [x] Idempotency potwierdzona (re-run → „no change")
- [x] Kod skilla dorzucony do repozytorium (`scripts/`)
- [x] `skill_kompresor.md` — ten dokument
- [ ] `switch-variant.sh` — aktualizacja (uruchamia sync na końcu) — DO ZROZENIA
- [ ] Commit + push do brancha `skill_kompresor`

---

## 🔮 Plan na kolejne kroki

1. Zaktualizować `switch-variant.sh` — na końcu wywołać `omlx-compression-sync.py`,
   żeby po każdym switchu wariantu kompresor zawsze = model w RAM.
2. Commit + push do brancha `skill_kompresor`.
3. (Opcja) Przepisać warianty configu tak, by nie hardcode'owały kompresora —
   pozwolić skryptowi ustalić go dynamicznie.
