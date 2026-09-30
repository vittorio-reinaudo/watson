#!/usr/bin/env bash
# Mette in salvo in inbox/ il messaggio originale, l'eventuale domanda rimasta aperta e ogni
# modifica non registrata; riporta il grafo all'ultimo commit e chiude con azione.sh (tipo bozza).
#
# Uso: bozza.sh [--messaggio TESTO] [--domanda TESTO] [--motivo TESTO]
# Senza --messaggio usa l'ultimo messaggio dell'utente salvato in .watson/ultimo-messaggio.
# Stampa il percorso della bozza.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAIN="${WATSON_BRAIN_DIR:-$PWD}"
[ -d "$BRAIN/diario-di-bordo" ] && [ -d "$BRAIN/.git" ] || { echo "✗ $BRAIN non è un repository 221b." >&2; exit 2; }
cd "$BRAIN"

MESSAGGIO="" DOMANDA="" MOTIVO="messaggio non completato"
[ -f .watson/ultimo-messaggio ] && MESSAGGIO="$(cat .watson/ultimo-messaggio)"
while [ $# -gt 0 ]; do
  case "$1" in
    --messaggio) MESSAGGIO="$2"; shift 2 ;;
    --domanda) DOMANDA="$2"; shift 2 ;;
    --motivo) MOTIVO="$2"; shift 2 ;;
    *) echo "Uso: bozza.sh [--messaggio TESTO] [--domanda TESTO] [--motivo TESTO]" >&2; exit 2 ;;
  esac
done

scrivi_bozza() {
  python3 - "$@" <<'PY'
import datetime, os, subprocess, sys
messaggio, domanda, motivo = sys.argv[1:4]
t = os.environ.get("WATSON_ADESSO")
ora = datetime.datetime.strptime(t, "%Y-%m-%d %H:%M") if t else datetime.datetime.now()

def git(*a, **kw):
    return subprocess.run(["git", *a], capture_output=True, check=True, **kw).stdout

stato = git("status", "--porcelain=v1", "-z", "--untracked-files=all").decode().split("\0")
modifiche = []  # (codice, percorso) fuori da inbox/
for voce in filter(None, stato):
    codice, percorso = voce[:2], voce[3:]
    if not percorso.startswith("inbox/"):
        modifiche.append((codice, percorso))

parti = []
for codice, p in modifiche:
    if codice == "??" or "A" in codice:
        with open(p, encoding="utf-8", errors="replace") as f:
            parti.append(f"### {p} (nuovo)\n\n````markdown\n{f.read()}\n````\n")
    else:
        diff = git("diff", "HEAD", "--", p).decode(errors="replace")
        parti.append(f"### {p} (modificato)\n\n````diff\n{diff}\n````\n")

os.makedirs("inbox", exist_ok=True)
base = f"inbox/{ora:%Y-%m-%d_%H%M}_bozza"
nome, n = base + ".md", 1
while os.path.exists(nome):
    n += 1
    nome = f"{base}-{n}.md"
testo = [f"---\ntitolo: Bozza\ncreata: {ora:%Y-%m-%d %H:%M}\nmotivo: {motivo}\n---\n",
         "## Messaggio originale\n", (messaggio or "(non disponibile)") + "\n"]
if domanda:
    testo += ["## Domanda rimasta aperta\n", domanda + "\n"]
if parti:
    testo += ["## Modifiche non registrate\n"] + parti
with open(nome, "w", encoding="utf-8") as f:
    f.write("\n".join(testo))

# Il grafo torna all'ultimo commit: ciò che non è registrato vive solo nella bozza.
for codice, p in modifiche:
    if codice == "??" or "A" in codice:
        os.remove(p)
    else:
        contenuto = git("show", f"HEAD:{p}")
        os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
        with open(p, "wb") as f:
            f.write(contenuto)
print(nome)
PY
}
BOZZA="$(scrivi_bozza "$MESSAGGIO" "$DOMANDA" "$MOTIVO")"

WATSON_BRAIN_DIR="$BRAIN" "$QUI/azione.sh" --tipo bozza --sommario "bozza in inbox" --dettaglio "$MOTIVO" --frase "$MESSAGGIO" >/dev/null
echo "$BOZZA"
