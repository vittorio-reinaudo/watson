#!/usr/bin/env bash
# Ricerca in sola lettura, per le sessioni in cui Claude Code non offre gli strumenti Glob e Grep.
#
# Uso: cerca.sh file  <modello> [cartella]   elenca i file il cui nome corrisponde al modello, per esempio "*.md"
#      cerca.sh testo <testo>   [cartella]   righe che contengono il testo (espressione regolare, senza maiuscole)
# La cartella (predefinita: quella corrente, cioè 221b) deve stare in 221b, nel prodotto o in ~/.watson/lavori.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USO="Uso: cerca.sh file <modello> [cartella] | cerca.sh testo <testo> [cartella]"
[ $# -ge 2 ] && [ $# -le 3 ] || { echo "$USO" >&2; exit 2; }
MODO="$1" CHE="$2" DOVE="${3:-.}"

REALE="$(python3 -c 'import os,sys; print(os.path.realpath(os.path.expanduser(sys.argv[1])))' "$DOVE")"
AMMESSO=0
for base in "$PWD" "$(dirname "$QUI")" "${WATSON_HOME:-}" "$HOME/.watson/lavori"; do
  [ -n "$base" ] || continue
  base="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$base")"
  case "$REALE/" in "$base"/*) AMMESSO=1 ;; esac
done
[ $AMMESSO = 1 ] || { echo "✗ cerca.sh legge solo in 221b, nel prodotto e in ~/.watson/lavori." >&2; exit 2; }

case "$MODO" in
  file) find "$DOVE" -name .git -prune -o -type f -name "$CHE" -print | sort ;;
  testo) grep -rniE --exclude-dir=.git -- "$CHE" "$DOVE" || true ;;
  *) echo "$USO" >&2; exit 2 ;;
esac
