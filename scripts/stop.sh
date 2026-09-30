#!/usr/bin/env bash
# Hook di fine risposta: nessuna modifica resta a metà.
# Primo tentativo con modifiche non registrate: blocca e chiede al modello di chiudere l'azione.
# Secondo tentativo nello stesso giro: mette tutto in bozza in inbox/ e chiede di riportare l'avviso.
set -uo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="$(cat)"
BRAIN="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -d "$BRAIN/diario-di-bordo" ] && [ -d "$BRAIN/.git" ] || exit 0
cd "$BRAIN"

SPORCO="$(git status --porcelain)"
[ -z "$SPORCO" ] && exit 0

json() { python3 -c 'import json,sys; print(json.dumps({sys.argv[1]: sys.argv[2], **({"decision": "block"} if sys.argv[1] == "reason" else {})}, ensure_ascii=False))' "$@"; }

ATTIVO="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("stop_hook_active", False))' "$INPUT")"
if [ "$ATTIVO" != True ]; then
  json reason "Ci sono modifiche non registrate in 221b:
$SPORCO
Chiudi l'azione con $QUI/azione.sh --tipo <tipo> --sommario \"<sommario>\" --scope \"<scope>\" --dettaglio \"<dettaglio>\". Se azione.sh rifiuta il commit, correggi i file come indicato. Se ti manca un'informazione, metti in salvo con $QUI/bozza.sh --domanda \"<domanda>\" e poi fai la domanda."
elif BOZZA="$(WATSON_BRAIN_DIR="$BRAIN" "$QUI/bozza.sh" --motivo "azione non chiusa a fine risposta" 2>&1)"; then
  json reason "Le modifiche non registrate sono state salvate in bozza in $BOZZA e il grafo è tornato all'ultimo stato valido. Non modificare altro: chiudi il resoconto con la riga
⚠️ Watson · Salvato in bozza: $BOZZA (azione non chiusa)"
else
  # Non si blocca più: l'avviso arriva direttamente all'utente.
  json systemMessage "⚠️ Watson · Restano modifiche non registrate in 221b e non sono riuscito a salvarle in bozza: $BOZZA"
fi
