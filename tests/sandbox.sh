#!/usr/bin/env bash
# Crea un 221b di prova dalla fixture: tests/sandbox.sh [cartella]. Stampa il percorso.
# Le impostazioni sono quelle del template senza enabledPlugins: nei test il plugin si carica con --plugin-dir.
set -euo pipefail
QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(dirname "$QUI")"
DEST="${1:-$(mktemp -d)/221b}"
mkdir -p "$DEST"
cp -R "$QUI/fixture/." "$DEST/"
mkdir -p "$DEST/.claude"
python3 - "$PLUGIN/templates/221b/.claude/settings.json" "$DEST/.claude/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
s.pop("enabledPlugins", None)
json.dump(s, open(sys.argv[2], "w"), indent=2)
PY
cd "$DEST"
git init -q
git symbolic-ref HEAD refs/heads/main
WATSON_INTERNO=1 "$PLUGIN/scripts/azione.sh" --tipo init --sommario "221b di prova dalla fixture" --frase "" >/dev/null
echo "$DEST"
