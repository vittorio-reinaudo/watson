#!/usr/bin/env python3
"""Hook dopo ogni scrittura: valida la nota o il nodo appena scritto e, se non è valido,
blocca restituendo al modello esattamente cosa correggere."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import marauders_map  # noqa: E402

GRAFO = ("note", "persone", "progetti")


def main():
    dati = json.load(sys.stdin)
    brain = os.path.realpath(os.environ.get("CLAUDE_PROJECT_DIR") or dati.get("cwd") or os.getcwd())
    if not os.path.isdir(os.path.join(brain, "diario-di-bordo")):
        return
    ti = dati.get("tool_input") or {}
    p = os.path.realpath(ti.get("file_path") or "")
    if not p.startswith(brain + os.sep) or not p.endswith(".md"):
        return
    rel = os.path.relpath(p, brain)
    if rel.split(os.sep)[0] not in GRAFO:
        return
    g = marauders_map.Grafo(brain)
    g.controlla()
    errori = sorted(msg for percorso, msg in g.violazioni if percorso == rel)
    if not errori:
        return
    motivo = (f"✗ {rel} non è valido:\n" + "\n".join(f"- {e}" for e in errori) +
              "\nCorreggi il file prima di proseguire. Un alias si scrive nella forma canonica indicata; "
              "un nome sconosciuto non si inventa mai: se devi chiedere all'utente, prima metti in salvo "
              f"le modifiche con {os.path.dirname(os.path.realpath(__file__))}/bozza.sh --domanda \"<la domanda>\", "
              "poi fai la domanda chiusa (protocollo domanda).")
    print(json.dumps({"decision": "block", "reason": motivo}, ensure_ascii=False))


if __name__ == "__main__":
    main()
