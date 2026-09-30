#!/usr/bin/env bash
# Eevee: l'unica strada per modificare il prodotto.
#
# Uso: eevee_applica.sh --mostra <cartella>   mostra le differenze rispetto al clone di watson
#      eevee_applica.sh <cartella>            prova, applica, fa commit e tag, aggiorna il plugin
#      eevee_applica.sh --annulla             annulla l'ultima modifica applicata, con nuovo commit e tag
#
# La cartella (di solito in ~/.watson/lavori/) rispecchia i percorsi del repository watson e contiene
# solo i file nuovi o modificati. Prima di applicare, le modifiche vengono provate su una copia
# temporanea con i test degli script e del riconoscimento delle intenzioni: se falliscono, niente
# viene applicato. Versione, CHANGELOG e stato della proposta li aggiorna questo script.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${WATSON_HOME:-}" ] && [ -f "$HOME/.watson/config" ]; then
  WATSON_HOME="$(sed -n 's/^WATSON_HOME=//p' "$HOME/.watson/config")"
fi
CLONE="${WATSON_HOME:-$(dirname "$QUI")}"
USO="Uso: eevee_applica.sh --mostra <cartella> | <cartella> | --annulla"

git -C "$CLONE" rev-parse --git-dir >/dev/null 2>&1 || { echo "✗ $CLONE non è il clone di watson." >&2; exit 2; }
git -C "$CLONE" symbolic-ref -q HEAD >/dev/null ||
  { echo "✗ Il clone di watson non è su un ramo (forse dopo git checkout di una versione): torna su main." >&2; exit 2; }
[ -z "$(git -C "$CLONE" status --porcelain)" ] ||
  { echo "✗ Il clone di watson ha modifiche non registrate: Watson non le sovrascrive." >&2; exit 2; }

MODO=applica
case "${1:-}" in
  --mostra) MODO=mostra; shift ;;
  --annulla) MODO=annulla; shift ;;
  ""|-*) echo "$USO" >&2; exit 2 ;;
esac

prossima_versione() { # la minore successiva a quella del plugin e a ogni tag esistente
  python3 - "$CLONE" <<'PY'
import json, re, subprocess, sys
clone = sys.argv[1]
v = json.load(open(f"{clone}/.claude-plugin/plugin.json"))["version"].split(".")
minori = [int(v[1])] + [int(m) for m in re.findall(r"^watson-v0\.(\d+)$",
          subprocess.run(["git", "-C", clone, "tag"], capture_output=True, text=True).stdout, re.M)]
print(f"0.{max(minori) + 1}")
PY
}

imposta_versione() { # imposta_versione <cartella> <0.N>
  python3 - "$1/.claude-plugin/plugin.json" "$2" <<'PY'
import json, sys
p, v = sys.argv[1:3]
d = json.load(open(p))
d["version"] = v + ".0"
open(p, "w").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
}

voce_changelog() { # voce_changelog <cartella> <testo della voce>
  python3 - "$1/CHANGELOG.md" "$2" <<'PY'
import sys
p, voce = sys.argv[1:3]
s = open(p, encoding="utf-8").read()
i = s.find("\n## ")
s = s + "\n" + voce if i < 0 else s[:i + 1] + voce + "\n" + s[i + 1:]
open(p, "w", encoding="utf-8").write(s)
PY
}

aggiorna_plugin() {
  [ "${WATSON_SENZA_AGGIORNARE:-}" = 1 ] && return 0
  claude plugin marketplace update watson >/dev/null 2>&1 || true
  claude plugin update watson@watson >/dev/null 2>&1 || true
}

prova() { # prova <copia>: test degli script e del routing sulla copia modificata
  local copia="$1" personali=()
  local esempi="${WATSON_BRAIN:-$HOME/221b}/esempi-personali.md"
  [ -f "$esempi" ] && personali=(--personali "$esempi")
  echo "Provo la modifica su una copia di watson…"
  if ! "$copia/tests/test_script.sh" > "$copia/.prova-script" 2>&1; then
    echo "✗ Modifica rifiutata: i test degli script falliscono." >&2
    grep '^✗' "$copia/.prova-script" >&2 || tail -20 "$copia/.prova-script" >&2
    return 1
  fi
  if ! "$copia/scripts/test_routing.sh" --plugin "$copia" ${personali[@]+"${personali[@]}"} > "$copia/.prova-routing" 2>&1; then
    echo "✗ Modifica rifiutata: il riconoscimento delle intenzioni è cambiato." >&2
    grep -A3 '^✗' "$copia/.prova-routing" | grep -v '^✔' >&2 || tail -20 "$copia/.prova-routing" >&2
    return 1
  fi
  rm -f "$copia/.prova-script" "$copia/.prova-routing"
}

if [ "$MODO" = annulla ]; then
  SHA="$(git -C "$CLONE" log -1 --format=%H --grep='^eevee: ' || true)"
  [ -n "$SHA" ] || { echo "✗ Nessuna modifica di Eevee da annullare." >&2; exit 1; }
  DA="$(git -C "$CLONE" tag --points-at "$SHA" | grep '^watson-v' | head -1)"
  VERSIONE="$(prossima_versione)"
  cd "$CLONE"
  if ! git revert --no-commit "$SHA" >/dev/null 2>&1; then
    CONFLITTI="$(git diff --name-only --diff-filter=U)"
    git revert --abort
    echo "✗ Conflitto: modifiche successive a $DA hanno toccato gli stessi file:" >&2
    printf '%s\n' "$CONFLITTI" >&2
    exit 2
  fi
  # Changelog e proposte restano come storia; cambiano solo versione e comportamento.
  for p in CHANGELOG.md $(git ls-tree -r --name-only HEAD evoluzioni); do git show "HEAD:$p" > "$p"; done
  imposta_versione "$CLONE" "$VERSIONE"
  voce_changelog "$CLONE" "## watson-v$VERSIONE — annullata $DA

Torna al comportamento precedente a $DA.
"
  if ! "$CLONE/tests/test_script.sh" >/dev/null 2>&1; then
    git revert --abort
    echo "✗ Annullamento rifiutato: con il revert i test degli script falliscono." >&2
    exit 1
  fi
  git add -A
  git commit -q -m "eevee: annulla $DA (watson-v$VERSIONE)"
  git tag "watson-v$VERSIONE"
  aggiorna_plugin
  echo "watson-v$VERSIONE"
  exit 0
fi

[ $# -eq 1 ] || { echo "$USO" >&2; exit 2; }
LAVORO="$(cd "$1" && pwd)" || exit 2
FILES="$(cd "$LAVORO" && find . -type f ! -name '.*' | sed 's|^\./||' | sort)"
[ -n "$FILES" ] || { echo "✗ La cartella $LAVORO è vuota." >&2; exit 2; }
while IFS= read -r f; do
  case "$f" in
    *..*|.git/*|.claude-plugin/plugin.json|CHANGELOG.md)
      echo "✗ $f non si modifica da qui (versione e changelog li aggiorna lo script)." >&2; exit 2 ;;
  esac
done <<<"$FILES"

if [ "$MODO" = mostra ]; then
  while IFS= read -r f; do
    if [ -f "$CLONE/$f" ]; then
      diff -u --label "a/$f" --label "b/$f" "$CLONE/$f" "$LAVORO/$f" || true
    else
      diff -u --label /dev/null --label "b/$f" /dev/null "$LAVORO/$f" || true
    fi
  done <<<"$FILES"
  exit 0
fi

VERSIONE="$(prossima_versione)"
TAG="watson-v$VERSIONE"
COPIA="$(mktemp -d)/watson"
mkdir -p "$COPIA"
trap 'rm -rf "$(dirname "$COPIA")"' EXIT
git -C "$CLONE" archive HEAD | tar -x -C "$COPIA"
while IFS= read -r f; do
  mkdir -p "$COPIA/$(dirname "$f")"
  cp "$LAVORO/$f" "$COPIA/$f"
done <<<"$FILES"

# Contabilità: versione, stato della proposta, voce del changelog.
imposta_versione "$COPIA" "$VERSIONE"
TITOLO="$(python3 - "$COPIA" "$TAG" $(grep '^evoluzioni/' <<<"$FILES" || true) <<'PY'
import re, sys
copia, tag, *proposte = sys.argv[1:]
titoli = []
for p in proposte:
    s = open(f"{copia}/{p}", encoding="utf-8").read()
    s = re.sub(r"^versione:.*$", f"versione: {tag}", s, count=1, flags=re.M)
    s = re.sub(r"^stato:.*$", "stato: applicata", s, count=1, flags=re.M)
    open(f"{copia}/{p}", "w", encoding="utf-8").write(s)
    m = re.search(r"^titolo:\s*(.+)$", s, re.M)
    titoli.append((m.group(1).strip() if m else p, p))
print(" · ".join(t for t, _ in titoli) or "modifica senza proposta")
for t, p in titoli:
    print(f"Proposta: [{p.split('/')[-1][:-3]}]({p}).")
PY
)"
TESTA="$(head -1 <<<"$TITOLO")"
voce_changelog "$COPIA" "## $TAG — $TESTA

$(tail -n +2 <<<"$TITOLO")
"

prova "$COPIA" || exit 1

while IFS= read -r f; do
  mkdir -p "$CLONE/$(dirname "$f")"
  cp "$COPIA/$f" "$CLONE/$f"
done <<<"$FILES"$'\n'".claude-plugin/plugin.json"$'\n'"CHANGELOG.md"
git -C "$CLONE" add -A
git -C "$CLONE" commit -q -m "eevee: $TESTA ($TAG)"
git -C "$CLONE" tag "$TAG"
aggiorna_plugin
echo "$TAG"
