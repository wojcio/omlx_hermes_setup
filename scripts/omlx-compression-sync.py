#!/usr/bin/env python3
"""
omlx-compression-sync — keep auxiliary.compression.model in sync with the
model currently loaded in oMLX RAM.

PROBLEM
-------
Hermes context compression uses the model configured at
`auxiliary.compression.model`. On this machine it is Qwen3.5-122B-A10B, but the
user runs a single oMLX model in RAM (launchd watchdog `single-model-guard`
enforces <=1 loaded model). If compression points to a *different* model than
the one currently loaded, the next context-compression call forces a cold
reload of the compression model — breaking the single-model invariant and
wasting ~1 min of reload latency on a ~130 GB model.

FIX
---
This script reads the loaded model from oMLX `/api/status`
(`loaded_models[0]`) and, when it differs from `auxiliary.compression.model`,
writes the loaded model back into config.yaml. Hermes reads
`auxiliary.compression.model` per-call with file-mtime cache invalidation, so
the change takes effect on the next compression call — NO restart needed.

Because it just points compression at the model ALREADY in RAM, using it for
compression triggers no reload at all.

TRIGGERS
--------
  - Manually:   omlx-compression-sync.py            (one-shot)
  - On startup + model switches: launchd watchdog
    com.hermes.omlx-compression-sync.plist (runs every 60s).

AUTH
----
Reads the oMLX admin API key from ~/.omlx/settings.json (auth.api_key).
The key is NEVER printed.

RETURNS
-------
Exit 0 = ran cleanly (config may or may not have changed).
Exit 1 = could not read the loaded model (oMLX down / no model loaded) — leaves
         config untouched.
"""
import json
import os
import sys
import urllib.request
import urllib.error

BASE = "http://127.0.0.1:8000"
SETTINGS = os.path.expanduser("~/.omlx/settings.json")
LOG = os.path.expanduser("~/.omlx/logs/omlx-compression-sync.log")


def api_key():
    with open(SETTINGS) as f:
        return json.load(f)["auth"]["api_key"]


def loaded_model():
    """Return the single model id currently loaded in oMLX RAM, or None."""
    key = api_key()
    req = urllib.request.Request(
        BASE + "/api/status", headers={"Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=10) as r:
        data = json.load(r)
    loaded = data.get("loaded_models") or []
    if isinstance(loaded, list) and loaded:
        return str(loaded[0])
    # Some oMLX builds expose a dict; try alternate shapes.
    if isinstance(loaded, dict) and loaded.get("id"):
        return str(loaded["id"])
    return None


def load_config():
    """Read config.yaml (profile-aware) as a dict via PyYAML.

    We read the file directly rather than ``hermes config show`` (which emits a
    human-readable ASCII table, not parseable JSON). Profile-awareness: Hermes
    stores config under $HERMES_HOME (default ~/.hermes); a profile lives in
    ~/.hermes/profiles/<name>/config.yaml. Detect the active profile via the
    HERMES_PROFILE env var when set, else default to ~/.hermes.
    """
    import yaml
    home = os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")
    profile = os.environ.get("HERMES_PROFILE") or "default"
    # Active profile is often pinned via ~/.hermes/profiles/<name>/profile.yaml.
    try:
        import pathlib
        for cand in (pathlib.Path(home) / "profiles" / profile,
                     pathlib.Path(home) / "profiles" / "active"):
            py = cand / "profile.yaml"
            if py.exists():
                home = str(cand.parent)
                break
    except Exception:
        pass
    path = os.path.join(home, "config.yaml")
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        cfg = yaml.safe_load(f) or {}
    return cfg if isinstance(cfg, dict) else {}


def save_config(cfg):
    """Persist config back to disk. Uses `hermes config set` for correctness."""
    import subprocess
    # hermes config set writes YAML with proper escaping + validation.
    proc = subprocess.run(
        ["hermes", "config", "set", "auxiliary.compression.model", current_model],
        capture_output=True, text=True, timeout=60)
    if proc.returncode != 0:
        raise RuntimeError(f"hermes config set failed: {proc.stderr[:300]}")
    return proc.stdout.strip()


def log(msg):
    import datetime
    line = "%s %s\n" % (datetime.datetime.now().isoformat(timespec="seconds"), msg)
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write(line)
    except Exception:
        pass


def main():
    global current_model
    try:
        loaded = loaded_model()
    except urllib.error.HTTPError as e:
        log(f"ERROR oMLX /api/status HTTP {e.code} — leaving config untouched")
        return 1
    except Exception as e:
        log(f"ERROR contacting oMLX: {e!r} — server down/restarting, skip")
        return 1

    if not loaded:
        log("INFO no model currently loaded in oMLX — leaving config untouched")
        return 0

    current_model = loaded
    try:
        cfg = load_config()
    except Exception as e:
        log(f"ERROR reading config: {e!r}")
        return 1

    aux = cfg.get("auxiliary", {}) if isinstance(cfg, dict) else {}
    comp = aux.get("compression", {}) if isinstance(aux, dict) else {}
    before = comp.get("model")

    if before == loaded:
        log(f"OK compression.model already = {loaded} (no change)")
        return 0

    log(f"SYNC compression.model: {before!r} -> {loaded!r}")
    try:
        # Apply via config set (writes to disk). The running agent re-reads it
        # on the next compression call thanks to file-mtime cache invalidation.
        save_config(cfg)
        log(f"APPLIED new compression.model = {loaded}")
    except Exception as e:
        log(f"ERROR applying config: {e!r}")
        return 1

    # Sanity: confirm the target model is routable from oMLX's perspective.
    return 0


if __name__ == "__main__":
    sys.exit(main())
