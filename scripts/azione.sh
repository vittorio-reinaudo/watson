#!/usr/bin/env bash
# Chiude ogni azione che scrive in 221b: rigenera l'indice, verifica le invarianti,
# aggiunge la riga al diario e fa un solo commit a nome dell'utente.
#
# Uso: azione.sh --tipo T --sommario S [--scope P] [--dettaglio D] [--frase F] [--rimuovi inbox/FILE]...
#   --tipo       cattura | aggiorna | mantieni | impara | annulla | bozza
#   --sommario   oggetto del commit, per esempio "incidente sul rilascio"
#   --scope      progetto/persona, per esempio alpha/luca
#   --dettaglio  terzo campo del diario, per esempio "incidente" o "todo chiuso"
#   --frase      la frase originale; se manca, l'ultimo messaggio dell'utente (.watson/ultimo-messaggio)
#   --rimuovi    toglie una bozza da inbox/ dopo averla ripresa (ripetibile; solo file di inbox/)
# Stampa l'id dell'azione. Esce con 1 se la verifica rifiuta il commit, 3 se non c'è niente da registrare.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(dirname "$QUI")"
BRAIN="${WATSON_BRAIN_DIR:-$PWD}"

USO="Uso: azione.sh --tipo T --sommario S [--scope P] [--dettaglio D] [--frase F] [--rimuovi inbox/FILE]..."
TIPO="" SCOPE="" SOMMARIO="" DETTAGLIO="" FRASE="" HA_FRASE=0 RIMUOVI=()
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || { echo "$USO" >&2; exit 2; }
  case "$1" in
    --tipo) TIPO="$2" ;;
    --scope) SCOPE="$2" ;;
    --sommario) SOMMARIO="$2" ;;
    --dettaglio) DETTAGLIO="$2" ;;
    --frase) FRASE="$2"; HA_FRASE=1 ;;
    --rimuovi) RIMUOVI+=("$2") ;;
    *) echo "Argomento sconosciuto: $1. $USO" >&2; exit 2 ;;
  esac
  shift 2
done
[ -n "$TIPO" ] && [ -n "$SOMMARIO" ] || { echo "$USO" >&2; exit 2; }

case "$TIPO" in
  cattura|aggiorna|mantieni|impara|annulla|bozza) ;;
  manuale|init) [ "${WATSON_INTERNO:-}" = 1 ] || { echo "✗ Il tipo $TIPO è riservato agli script di Watson." >&2; exit 2; } ;;
  *) echo "✗ Tipo d'azione sconosciuto: $TIPO (usa cattura, aggiorna, mantieni, impara, annulla o bozza)" >&2; exit 2 ;;
esac
[ -d "$BRAIN/diario-di-bordo" ] && [ -d "$BRAIN/.git" ] || { echo "✗ $BRAIN non è un repository 221b." >&2; exit 2; }
cd "$BRAIN"
if [ $HA_FRASE = 0 ] && [ -f .watson/ultimo-messaggio ]; then FRASE="$(cat .watson/ultimo-messaggio)"; fi
FRASE="$(printf '%s' "$FRASE" | tr '\n' ' ')"

MAPPA=(python3 "$QUI/marauders_map.py")
for p in ${RIMUOVI[@]+"${RIMUOVI[@]}"}; do
  case "$p" in
    inbox/*.md) [[ "$p" != *..* ]] && [ -f "$p" ] || { echo "✗ Bozza inesistente: $p" >&2; exit 2; }; rm -f "$p" ;;
    *) echo "✗ --rimuovi accetta solo file .md di inbox/: $p" >&2; exit 2 ;;
  esac
done
"${MAPPA[@]}" indice .

if [ "$TIPO" != init ] && [ -z "$(git status --porcelain)" ]; then
  echo "Niente da registrare: nessuna modifica in 221b." >&2
  exit 3
fi

if ! VIOLAZIONI="$("${MAPPA[@]}" verifica .)"; then
  if [ "$TIPO" = manuale ]; then
    # Le modifiche a mano si registrano sempre: le incoerenze restano visibili e bloccano le azioni successive.
    printf '%s\n' "$VIOLAZIONI" >&2
  else
    PRIMA=""
    if git rev-parse -q --verify HEAD >/dev/null; then
      TMP="$(mktemp -d)"
      git archive HEAD | tar -x -C "$TMP"
      PRIMA="$("${MAPPA[@]}" verifica "$TMP" --git . || true)"
      rm -rf "$TMP"
    fi
    NUOVE="$(printf '%s\n' "$VIOLAZIONI" | grep -vxF -f <(printf '%s\n' "$PRIMA") || true)"
    if [ -n "$NUOVE" ]; then
      echo "✗ Commit rifiutato: l'azione introdurrebbe incoerenze nel grafo." >&2
      printf '%s\n' "$NUOVE" >&2
      echo "Correggi i file indicati e rilancia azione.sh; se ti manca un'informazione, chiedi all'utente." >&2
      exit 1
    fi
    echo "⚠️ Nel grafo restano incoerenze già presenti prima di questa azione:" >&2
    printf '%s\n' "$VIOLAZIONI" >&2
  fi
fi

read -r BASE SETTIMANA < <(python3 -c '
import datetime, os
t = os.environ.get("WATSON_ADESSO")
d = datetime.datetime.strptime(t, "%Y-%m-%d %H:%M") if t else datetime.datetime.now()
print(d.strftime("a-%Y%m%d-%H%M"), d.strftime("%G-W%V"))')
ID="$BASE" N=1
while grep -rqsE "^$ID · " diario-di-bordo; do N=$((N + 1)); ID="$BASE-$N"; done

DIARIO="diario-di-bordo/$SETTIMANA.md"
[ -f "$DIARIO" ] || printf '# Diario di bordo %s\n\n' "$SETTIMANA" > "$DIARIO"
RIGA="$ID · $TIPO"
for campo in "$DETTAGLIO" "$SCOPE"; do [ -n "$campo" ] && RIGA="$RIGA · $campo"; done
[ -n "$FRASE" ] && RIGA="$RIGA · \"$FRASE\""
printf '%s\n' "$RIGA" >> "$DIARIO"

VERSIONE="$(python3 -c 'import json,sys; print(".".join(json.load(open(sys.argv[1]))["version"].split(".")[:2]))' "$PLUGIN/.claude-plugin/plugin.json")"
if [ -n "$SCOPE" ]; then OGGETTO="$TIPO($SCOPE): $SOMMARIO"; else OGGETTO="$TIPO: $SOMMARIO"; fi
MESSAGGIO="$OGGETTO

azione: $ID"
[ -n "$FRASE" ] && MESSAGGIO="$MESSAGGIO
frase: \"$FRASE\""
MESSAGGIO="$MESSAGGIO
watson: v$VERSIONE"

git add -A
git commit -q -F - <<<"$MESSAGGIO"

# Il push è facoltativo: se fallisce (per esempio offline) riparte con il commit successivo.
if [ -n "$(git remote)" ]; then
  (git push -q >/dev/null 2>&1 &)
fi

echo "$ID"
