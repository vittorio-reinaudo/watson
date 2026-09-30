#!/usr/bin/env bash
# Installa Watson a partire da questo clone. Si può rilanciare senza effetti collaterali.
set -euo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRAIN="${WATSON_BRAIN:-$HOME/221b}"

# 1. Identità git: tutti i commit di Watson sono a nome dell'utente.
NOME="$(git config user.name || true)"
EMAIL="$(git config user.email || true)"
if [ -z "$NOME" ] || [ -z "$EMAIL" ]; then
  cat >&2 <<'MSG'
✗ La tua identità git non è configurata: Watson firma ogni commit con il tuo nome.
  Impostala e rilancia ./install.sh:

    git config --global user.name "Nome Cognome"
    git config --global user.email "tu@esempio.com"
MSG
  exit 1
fi
command -v claude >/dev/null || { echo "✗ Claude Code non è installato: 'claude' deve funzionare nel terminale." >&2; exit 1; }

# 2. Questo clone è il marketplace; il plugin si installa da qui ed è attivo solo in 221b.
if claude plugin marketplace list 2>/dev/null | grep -q '❯ watson$'; then
  claude plugin marketplace update watson >/dev/null
else
  claude plugin marketplace add "$QUI" >/dev/null
fi
if claude plugin list 2>/dev/null | grep -q '❯ watson@watson$'; then
  claude plugin update watson@watson --scope user >/dev/null 2>&1 || true
else
  claude plugin install watson@watson --scope user >/dev/null
fi
# Disattivato a livello utente, attivato dalle impostazioni di progetto di 221b: gli hook non girano altrove.
claude plugin disable watson@watson --scope user >/dev/null 2>&1 || true
echo "✔ Plugin watson installato dal clone $QUI"

# 3. Il comando e il percorso del clone.
mkdir -p "$HOME/.local/bin" "$HOME/.watson"
ln -sfn "$QUI/bin/watson" "$HOME/.local/bin/watson"
printf 'WATSON_HOME=%s\n' "$QUI" > "$HOME/.watson/config"
echo "✔ Comando watson collegato in ~/.local/bin/"

# 4. Il repository dei dati: si crea solo se non esiste, non si sovrascrive mai.
if [ -e "$BRAIN" ]; then
  echo "✔ 221b già presente in $BRAIN: non lo tocco"
else
  mkdir -p "$(dirname "$BRAIN")"
  cp -R "$QUI/templates/221b" "$BRAIN"
  (
    cd "$BRAIN"
    git init -q
    git symbolic-ref HEAD refs/heads/main
    WATSON_INTERNO=1 "$QUI/scripts/azione.sh" --tipo init --sommario "nasce 221b" --frase "" >/dev/null
  )
  echo "✔ 221b creato in $BRAIN"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "ℹ︎ Aggiungi ~/.local/bin al PATH: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
