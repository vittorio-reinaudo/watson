#!/usr/bin/env python3
"""Hook prima di ogni strumento: fa rispettare i confini di Watson in 221b.

- Scritture solo in note/, persone/, progetti/, inbox/, preferenze.md, esempi-personali.md
  e nell'area di lavoro di Eevee (~/.watson/lavori/); mai altrove, mai nel clone di watson.
- Shell solo per gli script del plugin, senza operatori di shell; niente git diretto.
- Nessuno strumento esterno (MCP, web): 221b contiene dati personali.
Qualsiasi errore interno nega l'operazione.
"""
import json
import os
import shlex
import sys

PLUGIN = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SCRIPT_AMMESSI = ["azione.sh", "bozza.sh", "delorean.sh", "eevee_applica.sh", "marauders_map.py", "test_routing.sh"]
CARTELLE = ("note", "persone", "progetti", "inbox")
FILE = ("preferenze.md", "esempi-personali.md")
SCRITTURA = ("Write", "Edit", "MultiEdit", "NotebookEdit")


def decidi(decisione, motivo=""):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                             "permissionDecision": decisione,
                                             "permissionDecisionReason": motivo}}, ensure_ascii=False))
    sys.exit(0)


def dentro(percorso, base):
    return percorso == base or percorso.startswith(base.rstrip(os.sep) + os.sep)


def brain_di(dati):
    root = os.environ.get("CLAUDE_PROJECT_DIR") or dati.get("cwd") or os.getcwd()
    root = os.path.realpath(root)
    return root if os.path.isdir(os.path.join(root, "diario-di-bordo")) else None


def controlla_scrittura(brain, dati):
    ti = dati.get("tool_input") or {}
    grezzo = ti.get("file_path") or ti.get("notebook_path") or ""
    p = os.path.realpath(os.path.join(dati.get("cwd") or brain, os.path.expanduser(grezzo)))
    lavori = os.path.realpath(os.path.expanduser("~/.watson/lavori"))
    home = os.environ.get("WATSON_HOME")
    if dentro(p, PLUGIN) or (home and dentro(p, os.path.realpath(home))):
        decidi("deny", "Il repository watson non si modifica direttamente, da nessun componente: "
                       "prepara le modifiche in ~/.watson/lavori/ e applicale con eevee_applica.sh.")
    if dentro(p, lavori):
        decidi("allow", "area di lavoro di Eevee")
    if not dentro(p, brain):
        decidi("deny", "Watson scrive solo dentro 221b e nell'area di lavoro ~/.watson/lavori/.")
    rel = os.path.relpath(p, brain)
    primo = rel.split(os.sep)[0]
    if rel in FILE or (primo in CARTELLE and rel != primo):
        decidi("allow", "scrittura ammessa in 221b")
    if primo in ("indice", "diario-di-bordo"):
        decidi("deny", f"{primo}/ non si scrive mai a mano: cambia solo tramite azione.sh, che lo rigenera "
                       "e lo include nel commit. Scrivi le note e chiudi l'azione con azione.sh.")
    decidi("deny", "In 221b Watson scrive solo in note/, persone/, progetti/, inbox/, preferenze.md "
                   "ed esempi-personali.md.")


def controlla_shell(dati):
    cmd = (dati.get("tool_input") or {}).get("command", "")
    elenco = ", ".join(os.path.join(PLUGIN, "scripts", s) for s in SCRIPT_AMMESSI)
    rifiuto = ("Watson esegue solo gli script del plugin, chiamati direttamente con il percorso assoluto e "
               f"senza operatori di shell (; | & > < $ `): {elenco}.")
    if cmd.split()[:1] == ["git"]:
        decidi("deny", "Niente git diretto: i commit li fa azione.sh, gli annullamenti delorean.sh. " + rifiuto)
    if "\n" in cmd or "`" in cmd or "$" in cmd:
        decidi("deny", rifiuto)
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        token = list(lex)
    except ValueError:
        decidi("deny", "Comando non leggibile (virgolette non chiuse?). " + rifiuto)
    if not token or any(t and all(c in "();<>|&" for c in t) for t in token):
        decidi("deny", rifiuto)
    eseguibile = os.path.realpath(os.path.expanduser(token[0]))
    if os.path.dirname(eseguibile) == os.path.join(PLUGIN, "scripts") and os.path.basename(eseguibile) in SCRIPT_AMMESSI:
        decidi("allow", "script del plugin")
    decidi("deny", rifiuto)


def main():
    dati = json.load(sys.stdin)
    brain = brain_di(dati)
    if brain is None:
        sys.exit(0)  # fuori da 221b il guard non interviene
    nome = dati.get("tool_name", "")
    if nome in SCRITTURA:
        controlla_scrittura(brain, dati)
    if nome == "Bash":
        controlla_shell(dati)
    if nome.startswith("mcp__") or nome in ("WebFetch", "WebSearch"):
        decidi("deny", "Watson non usa servizi esterni: 221b contiene dati personali.")
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:  # fail closed
        decidi("deny", f"guard: errore interno ({e}), operazione negata")
