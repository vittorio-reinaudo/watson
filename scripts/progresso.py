#!/usr/bin/env python3
"""Filtro del wrapper `watson`: mostra l'avanzamento mentre Claude Code lavora.

Legge su stdin l'output `--output-format stream-json` di `claude -p`.
- stdout: la riga dell'evento "result" (e ogni riga non JSON), identiche a prima: il resoconto non cambia.
- stderr: una riga di avanzamento per ogni passo, solo con --mostra (il wrapper la passa se stderr è un terminale).
- --sobrio: solo emoji e verbo, come la preferenza `resoconto: sobrio`.
Le frasi sono fisse, come quelle di resoconto.md: nessun dettaglio tecnico (commit, indice, percorsi).
"""
import json
import os
import sys

# chiave: (emoji, firma e frase, verbo per la modalità sobria)
PASSI = {
    "watson": ("💭", "Watson · Ci penso…", "Elaboro…"),
    "leggi": ("📖", "Watson · Consulto gli appunti…", "Leggo…"),
    "scrivi": ("✍️", "Watson · Scrivo gli appunti…", "Scrivo…"),
    "azione": ("💾", "Watson · Chiudo l'azione…", "Chiudo l'azione…"),
    "bozza": ("⚠️", "Watson · Metto in salvo la bozza…", "Salvo la bozza…"),
    "memento": ("📸", "Memento · Preparo la polaroid…", "Salvo…"),
    "monica": ("📋", "Monica · Aggiorno la lista…", "Aggiorno i todo…"),
    "fellowship": ("🤝", "Fellowship · Riunisco la compagnia…", "Aggiorno persone e progetti…"),
    "delorean": ("⚡", "DeLorean · Torno indietro nel tempo…", "Annullo…"),
    "sherlock": ("🔎", "Sherlock · Indago tra le note…", "Cerco…"),
    "whistledown": ("💌", "Lady Whistledown · Raccolgo le voci…", "Riepilogo…"),
    "q": ("🍸", "Q · Preparo il briefing…", "Preparo il briefing…"),
    "wall-e": ("🤖", "Wall-E · Metto in ordine…", "Riordino…"),
    "eevee": ("✨", "Eevee · Penso a come evolvere…", "Preparo la modifica…"),
}


def passo(uso):
    """Chiave di PASSI per un tool_use, None se non merita una riga."""
    nome, ti = uso.get("name", ""), uso.get("input") or {}
    if nome == "Skill":
        return ti.get("skill", "").split(":")[-1]
    if nome in ("Agent", "Task"):
        return ti.get("subagent_type", "").split(":")[-1]
    if nome in ("Read", "Glob", "Grep"):
        return "leggi"
    if nome in ("Write", "Edit", "MultiEdit"):
        return "scrivi"
    if nome == "Bash":
        comando = ti.get("command", "")
        for script, chiave in (("azione.sh", "azione"), ("bozza.sh", "bozza"), ("cerca.sh", "leggi"),
                               ("eevee_applica.sh", "eevee")):
            if script in comando:
                return chiave
    return None


def main():
    mostra, sobrio = "--mostra" in sys.argv, "--sobrio" in sys.argv
    ultimo = None

    def dillo(chiave):
        nonlocal ultimo
        if not mostra or chiave not in PASSI or chiave == ultimo:
            return
        ultimo = chiave
        emoji, frase, verbo = PASSI[chiave]
        riga = f"{emoji} {verbo if sobrio else frase}"
        if not os.environ.get("NO_COLOR"):
            riga = f"\033[2m{riga}\033[0m"
        print(riga, file=sys.stderr, flush=True)

    dillo("watson")
    for riga in sys.stdin:
        try:
            d = json.loads(riga)
        except ValueError:
            print(riga, end="", flush=True)
            continue
        if d.get("type") == "result":
            print(riga.strip(), flush=True)
        elif d.get("type") == "assistant" and not d.get("parent_tool_use_id"):
            # Solo i passi dell'orchestratore: quelli interni a un agente sono coperti dalla riga dell'agente.
            for blocco in (d.get("message") or {}).get("content") or []:
                if isinstance(blocco, dict) and blocco.get("type") == "tool_use":
                    dillo(passo(blocco))


if __name__ == "__main__":
    main()
