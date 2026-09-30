#!/usr/bin/env bash
# Verifica il riconoscimento delle intenzioni: esegue in dry-run ogni frase di esempi.md su una copia
# della fixture e confronta famiglia, componente, tipo e ambiguità con quelli attesi.
#
# Uso: test_routing.sh [--plugin CARTELLA] [--personali FILE] [--paralleli N]
#   --plugin     il plugin da provare (predefinito: quello di questo script)
#   --personali  aggiunge gli esempi di un file nello stesso formato, per esempio 221b/esempi-personali.md
# Esce con 1 se una frase è instradata diversamente dall'atteso; una frase che sbaglia al primo
# tentativo e torna giusta al secondo è segnalata come instabile ma non fa fallire il test.
set -euo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERSONALI="" PARALLELI=6
while [ $# -gt 0 ]; do
  case "$1" in
    --plugin) PLUGIN="$(cd "$2" && pwd)"; shift 2 ;;
    --personali) PERSONALI="$2"; shift 2 ;;
    --paralleli) PARALLELI="$2"; shift 2 ;;
    *) echo "Uso: test_routing.sh [--plugin CARTELLA] [--personali FILE] [--paralleli N]" >&2; exit 2 ;;
  esac
done

SANDBOX="$("$PLUGIN/tests/sandbox.sh")"
trap 'rm -rf "$(dirname "$SANDBOX")"' EXIT

python3 - "$PLUGIN" "$SANDBOX" "$PARALLELI" "$PLUGIN/esempi.md" ${PERSONALI:+"$PERSONALI"} <<'PY'
import concurrent.futures, json, re, subprocess, sys
plugin, sandbox, paralleli, *files = sys.argv[1:]

def esempi(path):
    righe = []
    for riga in open(path, encoding="utf-8"):
        celle = [c.strip() for c in riga.strip().strip("|").split("|")]
        if not riga.startswith("|") or len(celle) != 5 or celle[0] in ("frase", "") or set(celle[0]) <= set("- "):
            continue
        righe.append((path, celle))
    return righe

def interpreta(testo):
    m = re.search(r"\{.*\}", testo, re.S)
    return json.loads(m.group(0))

def esegui(frase):
    for _ in range(2):
        p = subprocess.run(["claude", "-p", f"[dry-run] {frase}", "--plugin-dir", plugin, "--output-format", "json",
                            "--no-session-persistence"], cwd=sandbox, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        try:
            d = json.loads(p.stdout)
            if not d.get("is_error"):
                return interpreta(d.get("result", ""))
        except ValueError:
            pass
    raise RuntimeError((p.stdout or p.stderr).strip()[-200:])

FAMIGLIE = {"cattura": "catturare", "interroga": "interrogare", "aggiorna": "aggiornare", "mantieni": "mantenere"}

def normalizza(nome, valore):
    v = str(valore).strip().lower()
    if nome == "componente":
        return v.split(":")[-1]  # "watson:sherlock" è sherlock
    if nome == "famiglia":
        return FAMIGLIE.get(v, v)
    return str(valore)

def confronta(celle, risposta):
    frase, famiglia, componente, tipo, ambigua = celle
    intenzioni = risposta.get("intenzioni") or []
    diff = []
    for nome, atteso in (("famiglia", famiglia), ("componente", componente), ("tipo", tipo)):
        attesi = [a.strip() for a in atteso.split("+")]
        if atteso == "—":
            continue
        reali = [normalizza(nome, i.get(nome)) for i in intenzioni]
        if len(reali) != len(attesi) or any(r not in a.split("/") for r, a in zip(reali, attesi)):
            diff.append(f"{nome}: atteso {atteso}, ottenuto {' + '.join(reali) or 'niente'}")
    if (ambigua == "sì") != bool(risposta.get("ambigua")):
        diff.append(f"ambigua: atteso {ambigua}, ottenuto {'sì' if risposta.get('ambigua') else 'no'}")
    return diff

casi = [c for f in files for c in esempi(f)]
falliti = 0
with concurrent.futures.ThreadPoolExecutor(int(paralleli)) as pool:
    futuri = [(path, celle, pool.submit(esegui, celle[0])) for path, celle in casi]
    for path, celle, futuro in futuri:
        instabile = False
        try:
            diff = confronta(celle, futuro.result())
            if diff:
                # Una seconda prova distingue un'oscillazione del modello da un instradamento cambiato.
                instabile = not confronta(celle, esegui(celle[0]))
        except Exception as e:
            diff = [f"errore: {e}"]
        if instabile:
            print(f"✔ {celle[0]} (instabile: al primo tentativo {'; '.join(diff)})")
        elif diff:
            falliti += 1
            print(f"✗ {celle[0]}\n  " + "\n  ".join(diff))
        else:
            print(f"✔ {celle[0]}")
print(f"\n{len(casi) - falliti}/{len(casi)} esempi instradati come atteso.")
sys.exit(1 if falliti else 0)
PY
