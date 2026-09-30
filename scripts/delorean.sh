#!/usr/bin/env bash
# DeLorean: annulla un'azione di 221b tramite il suo id, con un revert che è a sua volta un'azione.
#
# Uso: delorean.sh <id> | --ultima [--frase F]
# Il diario non si annulla mai (è di sola aggiunta) e l'indice si rigenera: i conflitti su
# diario-di-bordo/ e indice/ si risolvono da soli. Un conflitto su note o nodi annulla il revert
# ed esce con 2, elencando i file coinvolti. Se il revert produrrebbe un'incoerenza, azione.sh lo
# rifiuta (uscita 1) e il revert viene annullato.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAIN="${WATSON_BRAIN_DIR:-$PWD}"
[ -d "$BRAIN/diario-di-bordo" ] && [ -d "$BRAIN/.git" ] || { echo "✗ $BRAIN non è un repository 221b." >&2; exit 2; }
cd "$BRAIN"

USO="Uso: delorean.sh <id> | --ultima [--frase F]"
ID="" FRASE=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ultima) ID=ultima; shift ;;
    --frase) [ $# -ge 2 ] || { echo "$USO" >&2; exit 2; }; FRASE=(--frase "$2"); shift 2 ;;
    a-*) ID="$1"; shift ;;
    *) echo "$USO" >&2; exit 2 ;;
  esac
done
[ -n "$ID" ] || { echo "$USO" >&2; exit 2; }

if [ -n "$(git status --porcelain)" ]; then
  echo "✗ Ci sono modifiche non registrate: chiudi prima l'azione in corso con azione.sh." >&2
  exit 1
fi

if [ "$ID" = ultima ]; then
  SHA="$(git log -1 --format=%H --grep='^azione: a-')"
  ID="$(git log -1 --format=%B "$SHA" | sed -n 's/^azione: //p')"
else
  SHA="$(git log -1 --format=%H --grep="^azione: $ID\$")"
fi
[ -n "$SHA" ] || { echo "✗ Nessuna azione con id $ID." >&2; exit 1; }
OGGETTO="$(git log -1 --format=%s "$SHA")"
case "$OGGETTO" in
  init:*) echo "✗ La creazione di 221b non si annulla." >&2; exit 1 ;;
esac

annulla_revert() { git revert --abort >/dev/null 2>&1 || true; }

if ! git revert --no-commit "$SHA" >/dev/null 2>&1; then
  CONFLITTI="$(git diff --name-only --diff-filter=U | grep -vE '^(indice|diario-di-bordo)/' || true)"
  if [ -n "$CONFLITTI" ]; then
    annulla_revert
    echo "✗ Conflitto: azioni successive a $ID ($OGGETTO) hanno toccato gli stessi file:" >&2
    printf '%s\n' "$CONFLITTI" >&2
    exit 2
  fi
fi

# Il diario resta com'era: l'annullamento è una riga nuova, non la cancellazione di quella vecchia.
for p in $(git ls-tree -r --name-only HEAD diario-di-bordo); do
  git show "HEAD:$p" > "$p"
done
for p in $(git ls-files --others --exclude-standard diario-di-bordo); do
  rm -f "$p"
done

if NUOVO="$(WATSON_BRAIN_DIR="$BRAIN" "$QUI/azione.sh" --tipo annulla --sommario "annulla $ID: $OGGETTO" \
      --dettaglio "→ $ID" ${FRASE[@]+"${FRASE[@]}"})"; then
  echo "Annullata $ID ($OGGETTO) con l'azione $NUOVO"
else
  CODICE=$?
  annulla_revert
  echo "✗ Annullare $ID lascerebbe il grafo incoerente: revert non applicato." >&2
  exit "$CODICE"
fi
