#!/usr/bin/env bash
set -euo pipefail

# omlx_bench.sh — Benchmark wszystkich lokalnych modeli oMLX (bez [HDD] w nazwie)
# na wspolnym zadaniu OpenCode: "describe the repo in this directory ".
#
# Uruchomienie:
#   ./omlx_bench.sh --dry-run
#   ./omlx_bench.sh
#   ./omlx_bench.sh --skip GLM-5.3-Flash-oQ2e-mtp,GLM-5.3-Flash-oQ4e-mtp --timeout 480

exec python3 - "$@" <<'PY'
import argparse
import datetime
import json
import os
import pathlib
import re
import signal
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_PROMPT = "describe the repo in this directory "
DEFAULT_OPENCODE_CONFIG = pathlib.Path.home() / ".config/opencode/opencode.json"
DEFAULT_OMLX_SETTINGS = pathlib.Path.home() / ".omlx/settings.json"
DEFAULT_OMLX_MODEL_SETTINGS = pathlib.Path.home() / ".omlx/model_settings.json"
DEFAULT_OMLX_LOG = pathlib.Path.home() / ".omlx/logs/server.log"
DEFAULT_OPENCODE_DB = pathlib.Path.home() / ".local/share/opencode/opencode.db"


def parse_args():
    p = argparse.ArgumentParser(
        prog="omlx_bench.sh",
        description="Testuje w OpenCode wszystkie modele oMLX nieoznaczone jako [HDD].",
    )
    p.add_argument("--prompt", default=DEFAULT_PROMPT, help="Prompt wysylany do opencode run")
    p.add_argument("--dir", default=os.getcwd(), help="Katalog repozytorium do uruchomienia testu")
    p.add_argument("--config", default=str(DEFAULT_OPENCODE_CONFIG), help="Sciezka do opencode.json")
    p.add_argument("--provider", default="omlx", help="ID providera w opencode.json (domyslnie: omlx)")
    p.add_argument("--variant", default="", help="Opcjonalny wariant OpenCode (np. high, medium, low)")
    p.add_argument("--timeout", type=int, default=480, help="Limit czasu na 1 model w sekundach (domyslnie: 480)")
    p.add_argument("--only", default="", help="Lista ID modeli (lub fragmentow) po przecinku do uruchomienia")
    p.add_argument("--skip", default="", help="Lista ID modeli (lub fragmentow) po przecinku do pominiecia")
    p.add_argument("--skip-ocr", action="store_true", help="Pomin wyspecjalizowane modele OCR (olmOCR, Unlimited-OCR)")
    p.add_argument("--archive", action="store_true", help="Oznacz sesje w OpenCode jako zarchiwizowane (--archived)")
    p.add_argument("--no-unload", action="store_true", help="Nie wyładowuj modeli z oMLX pomiedzy testami")
    p.add_argument("--out-dir", default="", help="Katalog wynikow (domyslnie: ./bench_results/<timestamp>)")
    p.add_argument("--dry-run", action="store_true", help="Pokaz liste modeli do testu i zakoncz bez uruchamiania")
    return p.parse_args()


def safe_filename(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", name)


def discover_models(args):
    cfg_path = pathlib.Path(args.config).expanduser()
    if not cfg_path.exists():
        raise FileNotFoundError(f"Brak pliku konfiguracji OpenCode: {cfg_path}")

    oc_data = json.loads(cfg_path.read_text(encoding="utf-8"))
    prov = oc_data.get("provider", {}).get(args.provider)
    if not prov:
        raise KeyError(f"Brak providera '{args.provider}' w {cfg_path}")

    omlx_models = {}
    if DEFAULT_OMLX_MODEL_SETTINGS.exists():
        try:
            omlx_models = json.loads(DEFAULT_OMLX_MODEL_SETTINGS.read_text(encoding="utf-8")).get("models", {})
        except Exception:
            omlx_models = {}

    only_terms = [t.strip().lower() for t in args.only.split(",") if t.strip()]
    skip_terms = [t.strip().lower() for t in args.skip.split(",") if t.strip()]

    selected = []
    skipped = []
    for mid, meta in prov.get("models", {}).items():
        oc_name = meta.get("name", "")
        ms_disp = (omlx_models.get(mid) or {}).get("display_name", "") or ""
        if "[HDD]" in mid or "[HDD]" in oc_name or "[HDD]" in ms_disp:
            skipped.append((mid, "HDD"))
            continue
        if args.skip_ocr and "ocr" in mid.lower():
            skipped.append((mid, "OCR (--skip-ocr)"))
            continue
        if only_terms and not any(t in mid.lower() for t in only_terms):
            skipped.append((mid, "poza --only"))
            continue
        if skip_terms and any(t in mid.lower() for t in skip_terms):
            skipped.append((mid, "--skip"))
            continue
        selected.append({"id": mid, "name": oc_name or mid})

    base_url = prov.get("options", {}).get("baseURL", "http://127.0.0.1:8000/v1")
    parsed = urllib.parse.urlparse(base_url)
    admin_base = f"{parsed.scheme}://{parsed.netloc}" if parsed.scheme and parsed.netloc else "http://127.0.0.1:8000"
    return selected, skipped, admin_base


def get_omlx_api_key():
    if DEFAULT_OMLX_SETTINGS.exists():
        try:
            data = json.loads(DEFAULT_OMLX_SETTINGS.read_text(encoding="utf-8"))
            key = data.get("auth", {}).get("api_key", "")
            if key:
                return key
        except Exception:
            pass
    return os.environ.get("OMLX_API_KEY", "")


def omlx_login(admin_base: str):
    key = get_omlx_api_key()
    if not key:
        return None
    body = json.dumps({"api_key": key, "remember": True}).encode("utf-8")
    req = urllib.request.Request(
        f"{admin_base}/admin/api/login",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        cookie = resp.headers.get("Set-Cookie", "").split(";")[0]
    return cookie if "=" in cookie else None


def omlx_loaded_models(admin_base: str, cookie: str):
    req = urllib.request.Request(
        f"{admin_base}/admin/api/models",
        headers={"Cookie": cookie, "Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.load(resp)
    models = data.get("models", data if isinstance(data, list) else [])
    return [
        {
            "id": m.get("id") or m.get("model_id"),
            "pinned": bool(m.get("pinned") or m.get("is_pinned")),
            "loading": bool(m.get("is_loading")),
        }
        for m in models
        if isinstance(m, dict) and m.get("loaded")
    ]


def omlx_unload_all(admin_base: str):
    try:
        cookie = omlx_login(admin_base)
        if not cookie:
            print("  [WARN] Brak API key dla oMLX admin API — pomijam unload.")
            return
        loaded = omlx_loaded_models(admin_base, cookie)
        if not loaded:
            return
        for m in loaded:
            mid = m["id"]
            if m["pinned"]:
                print(f"  [INFO] Model {mid} ma is_pinned=true — pomijam unload.")
                continue
            req = urllib.request.Request(
                f"{admin_base}/admin/api/models/{urllib.parse.quote(mid, safe='')}/unload",
                data=b"{}",
                method="POST",
                headers={"Cookie": cookie, "Content-Type": "application/json"},
            )
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    print(f"  [UNLOAD] {mid} -> HTTP {resp.status}")
            except urllib.error.HTTPError as e:
                print(f"  [WARN] Unload {mid} -> HTTP {e.code}")

        # Czekaj az nieprzypiete modele zejda z RAM (max 25s)
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            rem = [m for m in omlx_loaded_models(admin_base, cookie) if not m["pinned"]]
            if not rem:
                break
            time.sleep(1.0)
    except Exception as e:
        print(f"  [WARN] Nie udalo sie polaczyc z oMLX admin API ({admin_base}): {e}")


def inspect_opencode_session(model_id: str, t_start_ms: int, workdir: str):
    info = {
        "session_id": None,
        "status": "unknown",
        "turns": 0,
        "tool_calls": 0,
        "repeated_tool_calls": 0,
        "tokens_input": 0,
        "tokens_output": 0,
        "tokens_reasoning": 0,
        "tokens_cache_read": 0,
        "final_text": "",
        "error": None,
    }
    if not DEFAULT_OPENCODE_DB.exists():
        return info

    try:
        conn = sqlite3.connect(f"file:{DEFAULT_OPENCODE_DB}?mode=ro", uri=True)
        cur = conn.cursor()
        real_dir = os.path.realpath(workdir)
        rows = cur.execute(
            """
            SELECT id, directory, model, time_created, time_updated, idle_outcome,
                   tokens_input, tokens_output, tokens_reasoning, tokens_cache_read
            FROM session_v2
            WHERE time_created >= ?
            ORDER BY time_created DESC
            """,
            (t_start_ms - 5000,),
        ).fetchall()

        target = None
        for r in rows:
            if f'"id":"{model_id}"' in (r[2] or "") and os.path.realpath(r[1] or "") == real_dir:
                target = r
                break
        if not target:
            for r in rows:
                if f'"id":"{model_id}"' in (r[2] or ""):
                    target = r
                    break
        if not target:
            return info

        sid = target[0]
        info["session_id"] = sid
        info["status"] = target[5] or "unknown"
        info["tokens_input"] = target[6] or 0
        info["tokens_output"] = target[7] or 0
        info["tokens_reasoning"] = target[8] or 0
        info["tokens_cache_read"] = target[9] or 0

        msgs = cur.execute(
            "SELECT type, data FROM session_message WHERE session_id=? ORDER BY seq",
            (sid,),
        ).fetchall()
        seen_tools = set()
        last_texts = []
        for mtype, raw in msgs:
            if mtype != "assistant":
                continue
            d = json.loads(raw)
            info["turns"] += 1
            if d.get("error"):
                info["error"] = str(d.get("error"))[:200]
            for item in d.get("content", []):
                itype = item.get("type")
                if itype == "tool":
                    info["tool_calls"] += 1
                    sig = json.dumps(item.get("state", {}).get("input", {}), sort_keys=True, ensure_ascii=False)
                    if sig in seen_tools:
                        info["repeated_tool_calls"] += 1
                    seen_tools.add(sig)
                elif itype == "text" and item.get("text"):
                    last_texts.append(item.get("text"))

        if last_texts:
            info["final_text"] = last_texts[-1]
        conn.close()
    except Exception as e:
        info["error"] = f"db_err: {e}"
    return info


def parse_omlx_log_slice(start_offset: int, model_id: str):
    metrics = {
        "max_prompt": 0,
        "completions": 0,
        "avg_tps": None,
        "min_tps": None,
        "max_tps": None,
        "avg_ttft_s": None,
        "mtp_accept_pct": None,
        "mtp_tok_per_cycle": None,
        "freed_gb": None,
        "errors": [],
    }
    if not DEFAULT_OMLX_LOG.exists():
        return metrics

    with open(DEFAULT_OMLX_LOG, "rb") as f:
        f.seek(0, os.SEEK_END)
        end_pos = f.tell()
        if end_pos <= start_offset:
            return metrics
        f.seek(start_offset)
        text = f.read(end_pos - start_offset).decode("utf-8", errors="replace")

    tps_vals = []
    ttft_vals = []
    accept_vals = []
    tpc_vals = []

    re_cc = re.compile(
        r"Chat completion: model=([^\s,]+), \d+ tokens in [\d.]+s \(([\d.]+) tok/s\), prompt: (\d+).*?(?:stream_visible_ttft=([\d.]+)s)?"
    )
    re_mtp = re.compile(r"MTP\[\d+\] .*?tok/cycle=([\d.]+)\s+accept=\d+/\d+\s+\(([\d.]+)%\)")
    re_unload = re.compile(r"Unloaded model: ([^\s,]+), freed=([\d.]+)GB")

    for line in text.splitlines():
        if "GET /v1/models → 401" in line:
            continue
        m_cc = re_cc.search(line)
        if m_cc and m_cc.group(1) == model_id:
            metrics["completions"] += 1
            tps_vals.append(float(m_cc.group(2)))
            metrics["max_prompt"] = max(metrics["max_prompt"], int(m_cc.group(3)))
            if m_cc.group(4):
                ttft_vals.append(float(m_cc.group(4)))
            continue
        m_mtp = re_mtp.search(line)
        if m_mtp:
            tpc_vals.append(float(m_mtp.group(1)))
            accept_vals.append(float(m_mtp.group(2)))
            continue
        m_un = re_unload.search(line)
        if m_un and m_un.group(1) == model_id:
            metrics["freed_gb"] = float(m_un.group(2))
            continue
        if " ERROR " in line or "out of memory" in line.lower() or "Prefill interrupted" in line:
            metrics["errors"].append(line[-180:])

    if tps_vals:
        metrics["avg_tps"] = round(sum(tps_vals) / len(tps_vals), 1)
        metrics["min_tps"] = round(min(tps_vals), 1)
        metrics["max_tps"] = round(max(tps_vals), 1)
    if ttft_vals:
        metrics["avg_ttft_s"] = round(sum(ttft_vals) / len(ttft_vals), 2)
    if accept_vals:
        metrics["mtp_accept_pct"] = round(sum(accept_vals) / len(accept_vals), 1)
    if tpc_vals:
        metrics["mtp_tok_per_cycle"] = round(sum(tpc_vals) / len(tpc_vals), 2)
    return metrics


def write_summary(out_dir: pathlib.Path, args, results: list):
    lines = [
        f"# Benchmark OpenCode x oMLX (`omlx_bench.sh`)",
        "",
        f"- **Data:** `{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`",
        f"- **Katalog:** `{os.path.realpath(args.dir)}`",
        f"- **Prompt:** `{args.prompt}`",
        f"- **Timeout na model:** `{args.timeout}s` | **Wariant:** `{args.variant or 'domyslny'}`",
        "",
        "| # | Model | Status | Czas | Tury | Tools (powt.) | Max prompt | Avg tok/s | Avg TTFT | MTP accept | RAM freed | Dług. odp. |",
        "|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for idx, r in enumerate(results, 1):
        om = r["omlx"]
        oc = r["opencode"]
        tps_s = f"{om['avg_tps']}" if om["avg_tps"] is not None else "-"
        ttft_s = f"{om['avg_ttft_s']}s" if om["avg_ttft_s"] is not None else "-"
        mtp_s = f"{om['mtp_accept_pct']}% ({om['mtp_tok_per_cycle']})" if om["mtp_accept_pct"] is not None else "-"
        ram_s = f"{om['freed_gb']} GB" if om["freed_gb"] is not None else "-"
        max_p = om["max_prompt"] or oc["tokens_input"] or 0
        lines.append(
            f"| {idx} | `{r['model']}` | **{r['outcome']}** | {r['elapsed_s']}s | {oc['turns']} | "
            f"{oc['tool_calls']} ({oc['repeated_tool_calls']}) | {max_p} | {tps_s} | {ttft_s} | {mtp_s} | {ram_s} | {len(oc['final_text'])} zn. |"
        )
    lines.append("")
    (out_dir / "SUMMARY.md").write_text("\n".join(lines), encoding="utf-8")


def run_single_model(idx: int, total: int, model_id: str, args, out_dir: pathlib.Path, admin_base: str):
    print(f"\n[{idx}/{total}] === Testuje: {model_id} ===")
    if not args.no_unload:
        omlx_unload_all(admin_base)

    log_offset = DEFAULT_OMLX_LOG.stat().st_size if DEFAULT_OMLX_LOG.exists() else 0
    t_start_ms = int(time.time() * 1000)
    t0 = time.monotonic()

    model_spec = f"{args.provider}/{model_id}" + (f"#{args.variant}" if args.variant else "")
    cmd = ["opencode", "run", "-m", model_spec, "--auto", "--title", f"bench: {model_id}"]
    if args.archive:
        cmd.append("--archived")
    cmd.append(args.prompt)

    safe_id = safe_filename(model_id)
    run_log = out_dir / "logs" / f"{safe_id}.log"
    timed_out = False
    rc = -1

    with open(run_log, "w", encoding="utf-8") as lf:
        proc = subprocess.Popen(
            cmd,
            cwd=args.dir,
            stdout=lf,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            rc = proc.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            print(f"  [TIMEOUT] Przekroczono {args.timeout}s — przerywam proces OpenCode...")
            try:
                os.killpg(proc.pid, signal.SIGTERM)
                proc.wait(timeout=5)
            except Exception:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except Exception:
                    pass

    elapsed_s = round(time.monotonic() - t0, 1)
    time.sleep(1.5)

    # Najpierw wyładuj model, aby zlapac tez freed_gb w logu oMLX
    if not args.no_unload:
        omlx_unload_all(admin_base)
        time.sleep(0.5)

    oc_info = inspect_opencode_session(model_id, t_start_ms, args.dir)
    om_info = parse_omlx_log_slice(log_offset, model_id)

    if timed_out:
        outcome = "TIMEOUT"
    elif oc_info["status"] == "succeeded" and rc == 0:
        outcome = "PASS"
    elif rc == 0 and oc_info["final_text"]:
        outcome = "PASS"
    else:
        outcome = f"FAIL(rc={rc},{oc_info['status']})"

    # Zapisz pełną odpowiedź modelu do osobnego pliku Markdown
    resp_file = out_dir / "responses" / f"{safe_id}.md"
    resp_md = [
        f"# {model_id}",
        "",
        f"- **Outcome:** `{outcome}` | **Elapsed:** `{elapsed_s}s` | **Session:** `{oc_info['session_id']}`",
        f"- **Turns:** `{oc_info['turns']}` | **Tools:** `{oc_info['tool_calls']}` (powtórzone: `{oc_info['repeated_tool_calls']}`)",
        f"- **Tokens (OC DB):** in=`{oc_info['tokens_input']}`, out=`{oc_info['tokens_output']}`, reas=`{oc_info['tokens_reasoning']}`, cache=`{oc_info['tokens_cache_read']}`",
        f"- **oMLX:** max_prompt=`{om_info['max_prompt']}`, avg_tps=`{om_info['avg_tps']}`, avg_ttft=`{om_info['avg_ttft_s']}s`, mtp_accept=`{om_info['mtp_accept_pct']}%`, freed=`{om_info['freed_gb']} GB`",
        "",
        "## Odpowiedź końcowa",
        "",
        oc_info["final_text"] or "*(brak odpowiedzi tekstowej — sprawdź log uruchomienia)*",
    ]
    if oc_info["error"] or om_info["errors"]:
        resp_md.extend(["", "## Błędy", "", "```", str(oc_info["error"] or ""), *om_info["errors"], "```"])
    resp_file.write_text("\n".join(resp_md), encoding="utf-8")

    print(
        f"  -> {outcome} w {elapsed_s}s | tury={oc_info['turns']} tools={oc_info['tool_calls']}(rep={oc_info['repeated_tool_calls']}) "
        f"max_prompt={om_info['max_prompt']} avg_tps={om_info['avg_tps']} odp={len(oc_info['final_text'])} zn."
    )
    return {
        "model": model_id,
        "outcome": outcome,
        "rc": rc,
        "timed_out": timed_out,
        "elapsed_s": elapsed_s,
        "opencode": {k: v for k, v in oc_info.items() if k != "final_text"} | {"final_text_len": len(oc_info["final_text"]), "final_text": oc_info["final_text"]},
        "omlx": om_info,
    }


def main():
    args = parse_args()
    selected, skipped, admin_base = discover_models(args)

    print(f"Konfiguracja OpenCode: {args.config}")
    print(f"Katalog testowy:      {os.path.realpath(args.dir)}")
    print(f"Prompt:               {args.prompt!r}")
    print(f"oMLX Admin API:       {admin_base}")
    print(f"Wybrane modele ({len(selected)}):")
    for i, m in enumerate(selected, 1):
        print(f"  {i:2d}. {m['id']}")
    if skipped:
        print(f"Pominięte modele ({len(skipped)}):")
        for mid, reason in skipped:
            print(f"   -  {mid} [{reason}]")

    if args.dry_run:
        return 0
    if not selected:
        print("Brak modeli do przetestowania.")
        return 1

    run_id = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = pathlib.Path(args.out_dir) if args.out_dir else (pathlib.Path(args.dir) / "bench_results" / run_id)
    (out_dir / "logs").mkdir(parents=True, exist_ok=True)
    (out_dir / "responses").mkdir(parents=True, exist_ok=True)
    print(f"\nWyniki beda zapisywane na biezaco w: {out_dir}")

    results = []
    jsonl_path = out_dir / "results.jsonl"
    for i, m in enumerate(selected, 1):
        res = run_single_model(i, len(selected), m["id"], args, out_dir, admin_base)
        results.append(res)
        with open(jsonl_path, "a", encoding="utf-8") as jf:
            jf.write(json.dumps(res, ensure_ascii=False) + "\n")
        write_summary(out_dir, args, results)

    print(f"\nZakonczono! Podsumowanie: {out_dir / 'SUMMARY.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
PY
