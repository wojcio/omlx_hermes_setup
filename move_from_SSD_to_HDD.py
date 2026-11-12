#!/usr/bin/env python3
"""
move_from_SSD_to_HDD.py
Automatyczny audytor i asystent przenoszenia nieużywanych modeli z szybkiego SSD
na zewnętrzny dysk USB-C HDD (/Volumes/Seagate_Expansion_Drive/LLM).

Skanuje historię użycia modeli w oMLX (server.log*), Hermes Agent (state.db)
oraz metadane plików, typuje kandydatów i umożliwia bezpieczną migrację z symlinkowaniem.
"""

import argparse
import glob
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

# --- Ścieżki domyślne ---
DIR_BASE = Path(__file__).resolve().parent
SSD_MODELS_DIR = Path.home() / ".lmstudio" / "models"
HDD_BASE_DIR = Path("/Volumes/Seagate_Expansion_Drive/LLM")
OMLX_LOGS_DIR = Path.home() / ".omlx" / "logs"
HERMES_DB_PATH = Path.home() / ".hermes" / "state.db"
OMLX_API_URL = "http://127.0.0.1:8000"
OMLX_API_KEY = "sk-omlx-0Thr9X0jHr1U2T2ReS17j6Vi"

# Pliki konfiguracyjne do aktualizacji
CONFIG_FILES = [
    DIR_BASE / "model_settings.json",
    DIR_BASE / "model_settings.variant1-single-model.json",
    DIR_BASE / "model_settings.variant2-dual-model.json",
    Path.home() / ".omlx" / "model_settings.json",
]
OPENCODE_CONFIGS = [
    Path("/Users/wojcio/Desktop/Devel/opencode_omlx/opencode.json"),
    Path("/Users/wojcio/Desktop/Devel/opencode_omlx/opencode.json.remote"),
    Path.home() / ".config" / "opencode" / "opencode.json",
]

# Kolory ANSI do terminala
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_RED = "\033[31m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_BLUE = "\033[34m"
C_MAGENTA = "\033[35m"
C_CYAN = "\033[36m"
C_GRAY = "\033[90m"


def get_disk_free_gb(path: Path) -> float:
    try:
        usage = shutil.disk_usage(path)
        return usage.free / (1024**3)
    except Exception:
        return 0.0


def scan_omlx_logs() -> dict[str, tuple[datetime, str]]:
    """Wyciąga najnowsze znaczniki czasu użycia modeli z rotowanych logów oMLX."""
    usage = {}
    if not OMLX_LOGS_DIR.exists():
        return usage

    log_files = sorted(glob.glob(str(OMLX_LOGS_DIR / "server.log*")))
    ts_re = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
    load_re = re.compile(r"Loading model: ([\w\.\-]+)")
    chat_re = re.compile(r"Chat completion: model=([\w\.\-]+)")

    for lf in log_files:
        try:
            with open(lf, "r", errors="ignore") as f:
                for line in f:
                    target = None
                    m_load = load_re.search(line)
                    m_chat = chat_re.search(line)
                    if m_load:
                        target = m_load.group(1)
                    elif m_chat:
                        target = m_chat.group(1)

                    if target:
                        m_ts = ts_re.match(line)
                        if m_ts:
                            dt = datetime.strptime(m_ts.group(1), "%Y-%m-%d %H:%M:%S")
                            if target not in usage or dt > usage[target][0]:
                                usage[target] = (dt, "oMLX log")
        except Exception:
            pass
    return usage


def scan_hermes_db() -> dict[str, tuple[datetime, str]]:
    """Wyciąga najnowsze znaczniki czasu sesji z bazy SQLite Hermesa."""
    usage = {}
    if not HERMES_DB_PATH.exists():
        return usage

    try:
        con = sqlite3.connect(HERMES_DB_PATH)
        cur = con.cursor()
        rows = cur.execute(
            "SELECT model, MAX(last_activity_at), MAX(started_at) "
            "FROM sessions WHERE model IS NOT NULL GROUP BY model"
        ).fetchall()
        for m, last_act, start in rows:
            ts = last_act or start
            if ts:
                dt = datetime.fromtimestamp(ts)
                usage[m] = (dt, "Hermes DB")
        con.close()
    except Exception:
        pass
    return usage


def get_live_omlx_status() -> dict[str, dict]:
    """Odpytuje działający serwer oMLX o stan modeli (loaded, last_access)."""
    try:
        req = urllib.request.Request(
            f"{OMLX_API_URL}/admin/api/models",
            headers={"Authorization": f"Bearer {OMLX_API_KEY}"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            models = data.get("models", data) if isinstance(data, dict) else data
            return {m["id"]: m for m in models if "id" in m}
    except Exception:
        return {}


def get_dir_size_gb(path: Path) -> float:
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            fp = os.path.join(root, f)
            if not os.path.islink(fp):
                try:
                    total += os.path.getsize(fp)
                except OSError:
                    pass
    return total / (1024**3)


def count_files_in_dir(path: Path) -> int:
    cnt = 0
    for root, _dirs, files in os.walk(path):
        cnt += len([f for f in files if not f.startswith(".")])
    return cnt


def load_model_settings() -> dict:
    ms_path = DIR_BASE / "model_settings.json"
    if ms_path.exists():
        try:
            with open(ms_path) as f:
                return json.load(f).get("models", {})
        except Exception:
            pass
    return {}


def collect_models_data(threshold_days: int = 14) -> list[dict]:
    """Zbiera pełne dane o wszystkich modelach w ~/.lmstudio/models."""
    usage_omlx = scan_omlx_logs()
    usage_hermes = scan_hermes_db()
    live_omlx = get_live_omlx_status()
    model_settings = load_model_settings()

    models_list = []
    now = datetime.now()

    if not SSD_MODELS_DIR.exists():
        return models_list

    # Skanuj katalogi w ~/.lmstudio/models
    for root, dirs, _files in os.walk(SSD_MODELS_DIR):
        for d in list(dirs):
            full_d = Path(root) / d
            is_link = full_d.is_symlink()
            cfg_file = full_d / "config.json"

            if cfg_file.exists() or is_link:
                # To jest katalog modelu
                dirs.remove(d)
                rel_path = full_d.relative_to(SSD_MODELS_DIR)
                model_id = full_d.name

                target_hdd = HDD_BASE_DIR / rel_path
                already_on_hdd = is_link or target_hdd.is_dir()

                # Ustal ostatnie użycie
                last_dt = None
                source = "Brak wpisów"

                if model_id in usage_omlx:
                    last_dt, source = usage_omlx[model_id]

                if model_id in usage_hermes:
                    h_dt, h_src = usage_hermes[model_id]
                    if last_dt is None or h_dt > last_dt:
                        last_dt, source = h_dt, h_src

                # Fallback z live API oMLX
                live_info = live_omlx.get(model_id, {})
                live_la = live_info.get("last_access")
                if live_la:
                    try:
                        api_dt = datetime.fromisoformat(live_la.replace("Z", "+00:00")).replace(tzinfo=None)
                        if last_dt is None or api_dt > last_dt:
                            last_dt, source = api_dt, "oMLX live API"
                    except Exception:
                        pass

                # Fallback ze znaczników pliku config.json / safetensors
                if last_dt is None:
                    try:
                        st = cfg_file.stat()
                        file_dt = datetime.fromtimestamp(st.st_mtime)
                        last_dt, source = file_dt, "Plik config.json (mtime)"
                    except Exception:
                        pass

                days_ago = (now - last_dt).days if last_dt else 999

                # Rozmiar i status fizyczny
                if is_link:
                    size_gb = 0.0
                    loc = "HDD (Link)"
                    link_target = os.readlink(full_d)
                else:
                    size_gb = get_dir_size_gb(full_d)
                    loc = "SSD"
                    link_target = None

                cfg = model_settings.get(model_id, {})
                is_default = cfg.get("is_default", False)
                is_pinned = cfg.get("is_pinned", False)

                # Klasyfikacja priorytetu
                priority = "OTHER"
                if loc == "SSD":
                    if is_default:
                        priority = "PROTECTED_DEFAULT"
                    elif is_pinned:
                        priority = "PROTECTED_PINNED"
                    elif days_ago >= max(threshold_days, 30) and size_gb >= 20.0:
                        priority = "HIGH_CANDIDATE"
                    elif days_ago >= threshold_days:
                        priority = "MEDIUM_CANDIDATE"
                    elif days_ago >= 7:
                        priority = "LOW_USAGE"
                    else:
                        priority = "ACTIVE"
                else:
                    priority = "ALREADY_HDD"

                models_list.append({
                    "id": model_id,
                    "rel_path": rel_path,
                    "full_path": full_d,
                    "target_hdd": target_hdd,
                    "loc": loc,
                    "is_link": is_link,
                    "link_target": link_target,
                    "size_gb": size_gb,
                    "last_dt": last_dt,
                    "days_ago": days_ago,
                    "source": source,
                    "is_default": is_default,
                    "is_pinned": is_pinned,
                    "priority": priority,
                })

    # Sortuj: najpierw SSD wg priorytetu i dni bezczynności malejąco, potem rozmiar malejąco
    prio_order = {
        "HIGH_CANDIDATE": 1,
        "MEDIUM_CANDIDATE": 2,
        "LOW_USAGE": 3,
        "ACTIVE": 4,
        "PROTECTED_PINNED": 5,
        "PROTECTED_DEFAULT": 6,
        "ALREADY_HDD": 7,
    }
    models_list.sort(key=lambda m: (prio_order.get(m["priority"], 99), -m["days_ago"], -m["size_gb"]))
    return models_list


def print_dashboard(models: list[dict], threshold_days: int) -> list[dict]:
    """Drukuje elegancką, kolorową tabelę audytu i zwraca listę kandydatów na SSD."""
    ssd_free = get_disk_free_gb(SSD_MODELS_DIR)
    hdd_free = get_disk_free_gb(HDD_BASE_DIR) if HDD_BASE_DIR.exists() else 0.0

    print("\n" + "=" * 118)
    print(f"{C_BOLD}{C_CYAN}  📦 AUDYTOR MODELI: KANDYDACI DO PRZENIESIENIA Z SSD NA HDD{C_RESET}")
    print("=" * 118)

    hdd_status_str = f"{C_GREEN}Podłączony ({hdd_free:.1f} GiB wolnego){C_RESET}" if HDD_BASE_DIR.exists() else f"{C_RED}NIEPODŁĄCZONY!{C_RESET}"
    print(f"  • Szybki dysk SSD:   {C_BOLD}{ssd_free:.1f} GiB wolnego miejsca{C_RESET} ({SSD_MODELS_DIR})")
    print(f"  • Dysk zewnętrzny:  {hdd_status_str} ({HDD_BASE_DIR})")
    print(f"  • Kryterium audytu: Modele nieużywane od co najmniej {C_BOLD}{threshold_days} dni{C_RESET}")
    print("-" * 118)

    header = (
        f"{C_BOLD}{'Nr':<4} | {'Model ID':<42} | {'Rozmiar':<9} | {'Ostatnie Użycie':<16} | "
        f"{'Dni':<6} | {'Źródło':<13} | {'Status / Rekomendacja'}{C_RESET}"
    )
    print(header)
    print("-" * 118)

    candidates = []
    ssd_idx = 0

    for m in models:
        dt_str = m["last_dt"].strftime("%Y-%m-%d %H:%M") if m["last_dt"] else "Nigdy"
        days_str = f"{m['days_ago']}d" if m["last_dt"] else "-"
        src_str = m["source"][:13]
        mid_display = m["id"][:40]

        if m["loc"] == "SSD":
            ssd_idx += 1
            nr_str = f"[{ssd_idx:>2}]"
            candidates.append(m)

            if m["priority"] == "HIGH_CANDIDATE":
                status = f"{C_RED}{C_BOLD}🔴 MOCNY KANDYDAT (>30d, >20G){C_RESET}"
            elif m["priority"] == "MEDIUM_CANDIDATE":
                status = f"{C_YELLOW}{C_BOLD}🟡 KANDYDAT (>{threshold_days}d){C_RESET}"
            elif m["priority"] == "LOW_USAGE":
                status = f"{C_YELLOW}🟡 Mało używany (>7d){C_RESET}"
            elif m["priority"] == "PROTECTED_DEFAULT":
                status = f"{C_BLUE}🔒 Domyślny model (Chroniony){C_RESET}"
            elif m["priority"] == "PROTECTED_PINNED":
                status = f"{C_BLUE}🔒 Przypięty kompresor (Chroniony){C_RESET}"
            else:
                status = f"{C_GREEN}🟢 Aktywny (<7d){C_RESET}"

            row = (
                f"{C_BOLD}{nr_str:<4}{C_RESET} | {mid_display:<42} | {m['size_gb']:>6.1f} GB | "
                f"{dt_str:<16} | {days_str:>6} | {src_str:<13} | {status}"
            )
            print(row)
        else:
            # Już na HDD
            status = f"{C_GRAY}📦 Zarchiwizowany na HDD [Link]{C_RESET}"
            row = (
                f"{C_GRAY}{'--':<4} | {mid_display:<42} | {'[HDD]':>9} | "
                f"{dt_str:<16} | {days_str:>6} | {src_str:<13} | {status}{C_RESET}"
            )
            print(row)

    print("-" * 118)

    candidates_qualifying = [c for c in candidates if c["priority"] in ("HIGH_CANDIDATE", "MEDIUM_CANDIDATE")]
    potential_gb = sum(c["size_gb"] for c in candidates_qualifying)
    candidate_cnt = len(candidates_qualifying)
    print(
        f"  {C_BOLD}Podsumowanie:{C_RESET} Znaleziono {C_BOLD}{len(candidates)}{C_RESET} modeli na SSD, "
        f"w tym {C_RED}{C_BOLD}{candidate_cnt} rekomendowanych kandydatów{C_RESET} (nieużywanych od >={threshold_days}d)."
    )
    print(
        f"  Przeniesienie wszystkich kandydatów zwolni: {C_GREEN}{C_BOLD}{potential_gb:.1f} GiB{C_RESET} na szybkim dysku SSD!"
    )
    print("=" * 118)
    return candidates


def update_model_configs(model_id: str) -> None:
    """Aktualizuje model_settings*.json oraz opencode*.json dodając oznaczenie [HDD]."""
    hdd_tag = f"[HDD] {model_id}"
    desc = "Archiwum na zewnętrznym dysku USB-C HDD (/Volumes/Seagate_Expansion_Drive/LLM)"

    # 1. model_settings*.json
    for p in CONFIG_FILES:
        if p.exists():
            try:
                with open(p) as f:
                    data = json.load(f)
                if "models" in data and model_id in data["models"]:
                    data["models"][model_id]["display_name"] = hdd_tag
                    data["models"][model_id]["model_alias"] = hdd_tag
                    data["models"][model_id]["description"] = desc
                    with open(p, "w") as f:
                        json.dump(data, f, indent=2, ensure_ascii=False)
            except Exception as e:
                print(f"  [!] Ostrzeżenie przy aktualizacji {p.name}: {e}")

    # 2. OpenCode configs
    for op in OPENCODE_CONFIGS:
        if op.exists():
            try:
                with open(op) as f:
                    data = json.load(f)
                for prov_key in ["omlx", "omlxremote"]:
                    models_dict = data.get("provider", {}).get(prov_key, {}).get("models", {})
                    if model_id in models_dict:
                        curr_name = models_dict[model_id].get("name", "")
                        if "[HDD]" not in curr_name:
                            prefix = "[omlxremote] " if prov_key == "omlxremote" and not curr_name.startswith("[omlxremote]") else ""
                            # Wstaw [HDD] z zachowaniem etykiety
                            if prov_key == "omlxremote" and curr_name.startswith("[omlxremote] "):
                                models_dict[model_id]["name"] = f"[omlxremote] [HDD] {curr_name[13:]}"
                            else:
                                models_dict[model_id]["name"] = f"{prefix}[HDD] {curr_name}"
                with open(op, "w") as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
            except Exception as e:
                print(f"  [!] Ostrzeżenie przy aktualizacji OpenCode ({op.name}): {e}")

    # 3. Reload oMLX API
    try:
        req = urllib.request.Request(
            f"{OMLX_API_URL}/admin/api/reload",
            method="POST",
            headers={"Authorization": f"Bearer {OMLX_API_KEY}"},
        )
        urllib.request.urlopen(req, timeout=10)
    except Exception:
        pass


def copy_with_progress(src_dir: Path, dst_dir: Path) -> bool:
    """Kopiuje pliki z src_dir do dst_dir wyświetlając postęp."""
    dst_dir.mkdir(parents=True, exist_ok=True)
    all_files = []
    total_bytes = 0

    for root, _dirs, files in os.walk(src_dir):
        for f in files:
            fp = Path(root) / f
            if not fp.is_symlink():
                sz = fp.stat().st_size
                all_files.append((fp, sz))
                total_bytes += sz

    copied_bytes = 0
    t0 = time.time()
    last_print = 0

    for idx, (fp, sz) in enumerate(all_files, start=1):
        rel_f = fp.relative_to(src_dir)
        target_f = dst_dir / rel_f
        target_f.parent.mkdir(parents=True, exist_ok=True)

        # Kopiuj jeśli plik nie istnieje lub ma inny rozmiar
        if target_f.exists() and target_f.stat().st_size == sz:
            copied_bytes += sz
            continue

        with open(fp, "rb") as f_in, open(target_f, "wb") as f_out:
            while True:
                buf = f_in.read(16 * 1024 * 1024)  # 16 MB chunks
                if not buf:
                    break
                f_out.write(buf)
                copied_bytes += len(buf)
                now = time.time()
                if now - last_print >= 0.5:
                    pct = (copied_bytes / max(total_bytes, 1)) * 100
                    elapsed = max(now - t0, 0.1)
                    speed_mbs = (copied_bytes / (1024**2)) / elapsed
                    cur_gb = copied_bytes / (1024**3)
                    tot_gb = total_bytes / (1024**3)
                    print(
                        f"\r  -> Kopiowanie: {cur_gb:.1f}/{tot_gb:.1f} GiB ({pct:.1f}%) "
                        f"| {speed_mbs:.1f} MB/s | plik {idx}/{len(all_files)}",
                        end="",
                        flush=True,
                    )
                    last_print = now

    print(f"\r  -> Zakończono transfer {total_bytes / (1024**3):.1f} GiB do {dst_dir}!    ", flush=True)
    return True


def migrate_model(m: dict) -> bool:
    """Wykonuje bezpieczną migrację modelu z SSD na HDD z weryfikacją i symlinkowaniem."""
    src = m["full_path"]
    dst = m["target_hdd"]
    model_id = m["id"]

    print("\n" + "=" * 80)
    print(f"{C_BOLD}{C_CYAN}ROZPOCZYNANIE MIGRACJI MODELU:{C_RESET} {C_BOLD}{model_id}{C_RESET}")
    print(f"  • Źródło (SSD): {src} ({m['size_gb']:.2f} GiB)")
    print(f"  • Cel (HDD):    {dst}")
    print("=" * 80)

    if not HDD_BASE_DIR.exists():
        print(f"{C_RED}BŁĄD: Dysk HDD {HDD_BASE_DIR} nie jest podłączony! Przerwano.{C_RESET}")
        return False

    free_hdd = get_disk_free_gb(HDD_BASE_DIR)
    if free_hdd < m["size_gb"] + 2.0:
        print(f"{C_RED}BŁĄD: Za mało miejsca na dysku HDD ({free_hdd:.1f} GiB wolnego, wymagane {m['size_gb']:.1f} GiB)!{C_RESET}")
        return False

    # Sprawdź czy na HDD jest już kompletna kopia
    already_complete = False
    if dst.is_dir():
        src_files = count_files_in_dir(src)
        dst_files = count_files_in_dir(dst)
        src_sz = get_dir_size_gb(src)
        dst_sz = get_dir_size_gb(dst)

        if dst_files >= src_files and abs(dst_sz - src_sz) < 0.1:
            already_complete = True
            print(f"  {C_GREEN}✓ Wykryto kompletną, gotową kopię na HDD ({dst_files} plików, {dst_sz:.1f} GiB)!{C_RESET}")
            print("    Pominięto czasochłonne ponowne kopiowanie przez USB-C.")

    if not already_complete:
        print(f"  Rozpoczynam kopiowanie danych na zewnętrzny dysk USB-C...")
        ok = copy_with_progress(src, dst)
        if not ok:
            print(f"{C_RED}BŁĄD: Kopiowanie zakończone niepowodzeniem! Zachowuję pliki na SSD.{C_RESET}")
            return False

        # Weryfikacja po skopiowaniu
        src_files = count_files_in_dir(src)
        dst_files = count_files_in_dir(dst)
        src_sz = get_dir_size_gb(src)
        dst_sz = get_dir_size_gb(dst)
        if dst_files < src_files or dst_sz < (src_sz * 0.99):
            print(f"{C_RED}BŁĄD WERYFIKACJI: Rozmiar na HDD ({dst_sz:.1f} GiB, {dst_files} plików) jest mniejszy niż na SSD ({src_sz:.1f} GiB, {src_files} plików)!{C_RESET}")
            return False
        print(f"  {C_GREEN}✓ Weryfikacja spójności kopii na HDD pomyślna ({dst_files} plików, {dst_sz:.1f} GiB)!{C_RESET}")

    # Bezpieczne usunięcie z SSD i utworzenie symlinka
    print(f"  Zwalnianie miejsca na SSD ({src})...")
    shutil.rmtree(src)
    os.symlink(str(dst), str(src))
    print(f"  {C_GREEN}✓ Utworzono dowiązanie symboliczne:{C_RESET} {src} -> {dst}")

    # Aktualizacja konfiguracji oMLX i OpenCode
    print(f"  Aktualizacja wpisów konfiguracyjnych i odświeżanie serwera oMLX...")
    update_model_configs(model_id)

    ssd_free_now = get_disk_free_gb(SSD_MODELS_DIR)
    print(f"{C_GREEN}{C_BOLD}SUKCES! Odzyskano {m['size_gb']:.2f} GiB na szybkim dysku SSD!{C_RESET}")
    print(f"  Aktualne wolne miejsce na SSD: {C_BOLD}{ssd_free_now:.1f} GiB{C_RESET}")
    print(f"  Model {C_BOLD}{model_id}{C_RESET} jest nadal w pełni dostępny w oMLX i OpenCode jako {C_CYAN}[HDD]{C_RESET}.\n")
    return True


def interactive_menu(candidates: list[dict]) -> None:
    """Obsługuje interaktywne zapytanie użytkownika o wybór modeli do przeniesienia."""
    selectable = [c for c in candidates if c["loc"] == "SSD" and not c["is_default"] and not c["is_pinned"]]
    if not selectable:
        print(f"\n{C_GREEN}Wszystkie modele na SSD są chronione lub zostały już zarchiwizowane!{C_RESET}")
        return

    while True:
        try:
            print("\n" + C_BOLD + "Wybierz akcję:" + C_RESET)
            print("  • Podaj " + C_CYAN + "numer modelu" + C_RESET + " (np. 1 lub 1 3 4), aby go przenieść na HDD")
            print("  • Wpisz " + C_CYAN + "all" + C_RESET + " (lub 'recommended'), aby przenieść wszystkich czerwonych kandydatów")
            print("  • Wpisz " + C_CYAN + "q" + C_RESET + " (lub wciśnij Enter), aby zakończyć")
            ans = input(C_BOLD + "Twój wybór: " + C_RESET).strip().lower()

            if not ans or ans in ["q", "exit", "quit"]:
                print("Zakończono audyt. Żadne pliki nie zostały przeniesione.")
                break

            targets = []
            if ans in ["all", "recommended", "rec"]:
                targets = [c for c in selectable if c["priority"] in ("HIGH_CANDIDATE", "MEDIUM_CANDIDATE")]
                if not targets:
                    targets = [c for c in selectable if "CANDIDATE" in c["priority"] or c["priority"] == "LOW_USAGE"]
            else:
                tokens = ans.split()
                for tok in tokens:
                    if tok.isdigit():
                        idx = int(tok) - 1
                        if 0 <= idx < len(candidates):
                            cand = candidates[idx]
                            if cand["is_default"] or cand["is_pinned"]:
                                print(f"{C_YELLOW}Model {cand['id']} jest chroniony (domyślny/przypięty)! Pomijam.{C_RESET}")
                            elif cand["loc"] != "SSD":
                                print(f"{C_YELLOW}Model {cand['id']} jest już na HDD! Pomijam.{C_RESET}")
                            elif cand not in targets:
                                targets.append(cand)
                        else:
                            print(f"{C_RED}Nieprawidłowy numer: {tok}{C_RESET}")
                    else:
                        # Wyszukiwanie po nazwie
                        matched = [c for c in selectable if tok.lower() in c["id"].lower()]
                        for m in matched:
                            if m not in targets:
                                targets.append(m)

            if not targets:
                print(f"{C_YELLOW}Nie wybrano żadnych modeli do przeniesienia.{C_RESET}")
                continue

            total_gain = sum(t["size_gb"] for t in targets)
            print(f"\n{C_BOLD}Wybrano do przeniesienia ({len(targets)} modeli, łącznie {total_gain:.1f} GiB):{C_RESET}")
            for t in targets:
                print(f"  • {C_CYAN}{t['id']}{C_RESET} ({t['size_gb']:.1f} GiB, nieużywany od {t['days_ago']} dni)")

            confirm = input(f"\nCzy na pewno przenieść powyższe {len(targets)} modeli na HDD? (tak/nie): ").strip().lower()
            if confirm in ["t", "tak", "y", "yes"]:
                for t in targets:
                    migrate_model(t)
                print(f"\n{C_GREEN}{C_BOLD}Wszystkie wybrane modele zostały pomyślnie zarchiwizowane!{C_RESET}")
            else:
                print("Anulowano przenoszenie.")
            break
        except (KeyboardInterrupt, EOFError):
            print("\nPrzerwano.")
            break


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audytor i asystent przenoszenia nieużywanych modeli z SSD na Seagate HDD."
    )
    parser.add_argument(
        "--days", "-d",
        type=int,
        default=14,
        help="Próg dni bezczynności kwalifikujący model jako kandydata (domyślnie: 14 dni)",
    )
    parser.add_argument(
        "--check", "--dry-run", "-c",
        action="store_true",
        help="Tylko audyt i wyświetlenie tabeli kandydatów (bez pytań o przenoszenie)",
    )
    parser.add_argument(
        "--target", "-t",
        type=str,
        default=None,
        help="Bezpośrednia nazwa lub fragment nazwy modelu do przeniesienia",
    )
    args = parser.parse_args()

    models = collect_models_data(threshold_days=args.days)
    candidates = print_dashboard(models, threshold_days=args.days)

    if args.target:
        matches = [c for c in candidates if args.target.lower() in c["id"].lower() and c["loc"] == "SSD"]
        if not matches:
            print(f"\n{C_RED}Nie znaleziono modelu na SSD pasującego do frazy: '{args.target}'{C_RESET}")
            sys.exit(1)
        for m in matches:
            if m["is_default"] or m["is_pinned"]:
                print(f"{C_YELLOW}Model {m['id']} jest chroniony (domyślny lub przypięty kompresor)!{C_RESET}")
                continue
            migrate_model(m)
        return

    if not args.check:
        interactive_menu(candidates)


if __name__ == "__main__":
    main()
