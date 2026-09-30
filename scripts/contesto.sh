#!/usr/bin/env bash
# Hook di avvio della sessione e di invio di ogni messaggio.
#   SessionStart, contesto.sh regole     inietta WATSON.md
#   SessionStart, contesto.sh resoconto  inietta resoconto.md
#   SessionStart, contesto.sh            registra le modifiche fatte a mano, verifica le invarianti e inietta
#                                        incoerenze, indice delle entità, preferenze, ultime righe del diario
#   UserPromptSubmit                     salva il messaggio (per le bozze) e aggiunge data e ora correnti
# Il contesto è diviso in tre parti perché Claude Code tronca ogni additionalContext oltre i 10.000 caratteri.
set -uo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(dirname "$QUI")"
PARTE="${1:-dati}"
INPUT="$(cat)"
BRAIN="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -d "$BRAIN/diario-di-bordo" ] && [ -d "$BRAIN/.git" ] || exit 0
cd "$BRAIN"
mkdir -p .watson

EVENTO="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("hook_event_name",""))' "$INPUT")"

if [ "$EVENTO" = UserPromptSubmit ]; then
  python3 - "$INPUT" <<'PY'
import datetime, json, os, sys
dati = json.loads(sys.argv[1])
messaggio = dati.get("prompt", "")

def ultima_risposta(trascrizione):
    testo = ""
    try:
        with open(trascrizione, encoding="utf-8") as f:
            for riga in f:
                m = json.loads(riga).get("message") or {}
                if m.get("role") == "assistant" and isinstance(m.get("content"), list):
                    parti = [b.get("text", "") for b in m["content"] if b.get("type") == "text"]
                    if parti:
                        testo = "".join(parti)
    except (OSError, ValueError):
        pass
    return testo

# Una risposta a una domanda si registra insieme al messaggio che l'ha provocata.
if ultima_risposta(dati.get("transcript_path") or "").lstrip().startswith("? "):
    try:
        with open(".watson/ultimo-messaggio", encoding="utf-8") as f:
            messaggio = f.read() + " → " + messaggio
    except OSError:
        pass
with open(".watson/ultimo-messaggio", "w", encoding="utf-8") as f:
    f.write(messaggio)
t = os.environ.get("WATSON_ADESSO")
ora = datetime.datetime.strptime(t, "%Y-%m-%d %H:%M") if t else datetime.datetime.now()
giorni = ["lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato", "domenica"]
g = lambda d: f"{giorni[d.weekday()]} {d:%Y-%m-%d}"
ieri = ora - datetime.timedelta(days=1)
prossimi = ", ".join(g(ora + datetime.timedelta(days=i)) for i in range(1, 8))
lunedi = ora - datetime.timedelta(days=ora.weekday())
testo = (f"[adesso: {giorni[ora.weekday()]} {ora:%Y-%m-%d %H:%M} · ieri: {g(ieri)} · "
         f"questa settimana: da {g(lunedi)} · prossimi giorni: {prossimi}]")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": testo}},
                 ensure_ascii=False))
PY
  exit 0
fi

inietta() {
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.stdin.read()}}, ensure_ascii=False))'
}

# In una sessione ripresa regole e frasi fisse sono già nella conversazione.
ORIGINE="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("source",""))' "$INPUT")"
if [ "$ORIGINE" = resume ] && [ "$PARTE" != dati ]; then exit 0; fi

case "$PARTE" in
  regole) sed "s|\${CLAUDE_PLUGIN_ROOT}|$PLUGIN|g" "$PLUGIN/WATSON.md" | inietta; exit 0 ;;
  resoconto) inietta < "$PLUGIN/resoconto.md"; exit 0 ;;
esac

# Parte dati: prima registra le modifiche fatte a mano, poi descrive lo stato del grafo.
MANUALE=""
if [ -n "$(git status --porcelain)" ]; then
  if WATSON_INTERNO=1 WATSON_BRAIN_DIR="$BRAIN" "$QUI/azione.sh" --tipo manuale --sommario "modifiche a mano" \
       --dettaglio "modifiche a mano" --frase "" >/dev/null 2>&1; then
    MANUALE="Le modifiche fatte a mano dall'utente sono state registrate in un commit \"manuale: modifiche a mano\"."
  else
    MANUALE="Attenzione: non sono riuscito a registrare le modifiche fatte a mano."
  fi
fi
python3 "$QUI/marauders_map.py" indice . >/dev/null 2>&1
VIOLAZIONI="$(python3 "$QUI/marauders_map.py" verifica . 2>&1)"

python3 - "$MANUALE" "$VIOLAZIONI" <<'PY' | inietta
import glob, sys
manuale, violazioni = sys.argv[1:3]

def leggi(p):
    try:
        with open(p, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return "(assente)"

parti = []
if violazioni.strip():
    parti.append("⚠️ INCOERENZE NEL GRAFO. La prima riga della tua risposta deve segnalarle all'utente, in breve, "
                 "proponendo di sistemarle. Finché restano, azione.sh rifiuta ogni azione che ne aggiunga altre.\n"
                 + violazioni.strip())
if manuale:
    parti.append(manuale)
parti.append("# Indice delle entità (indice/entita.md)\n\n" + leggi("indice/entita.md"))
parti.append("# Preferenze (preferenze.md)\n\n" + leggi("preferenze.md"))
righe = []
for p in sorted(glob.glob("diario-di-bordo/*.md")):
    righe += [r for r in leggi(p).splitlines() if r.startswith("a-")]
parti.append("# Ultime righe del diario di bordo\n\n" + ("\n".join(righe[-5:]) or "(vuoto)"))
print("\n\n".join(parti))
PY
