#!/usr/bin/env bash
# Prove deterministiche degli script e degli hook, senza modello, su sandbox della fixture.
# Uso: tests/test_script.sh
set -uo pipefail

QUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(dirname "$QUI")"
S="$PLUGIN/scripts"
FALLITI=0

ok() { echo "✔ $1"; }
ko() { echo "✗ $1"; FALLITI=$((FALLITI + 1)); }
verifica() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

nuova() { B="$("$QUI/sandbox.sh")"; cd "$B"; export CLAUDE_PROJECT_DIR="$B"; }
hook() { # hook <script> <json>
  local s="$1"; shift
  case "$s" in *.py) printf '%s' "$1" | python3 "$S/$s" ;; *) printf '%s' "$1" | "$S/$s" ;; esac
}
guard() { hook guard.py "{\"tool_name\":\"$1\",\"cwd\":\"$B\",\"tool_input\":$2}"; }
nega() { guard "$@" | grep -q '"permissionDecision": "deny"'; }
permetti() { guard "$@" | grep -q '"permissionDecision": "allow"'; }
commit() { git rev-list --count HEAD; }

echo "— Mappa del Malandrino"
nuova
python3 "$S/marauders_map.py" indice .
A="$(cat indice/*.md | shasum)"
python3 "$S/marauders_map.py" indice .
verifica "indice identico byte per byte su due esecuzioni" '[ "$A" = "$(cat indice/*.md | shasum)" ]'
verifica "fixture senza violazioni" 'python3 "$S/marauders_map.py" verifica . >/dev/null'

echo "— Guard (prova 5)"
verifica "scrittura in indice/ bloccata" 'nega Write "{\"file_path\":\"$B/indice/entita.md\"}"'
verifica "scrittura nel diario bloccata" 'nega Edit "{\"file_path\":\"$B/diario-di-bordo/2026-W40.md\"}"'
verifica "scrittura in .claude/ bloccata" 'nega Write "{\"file_path\":\"$B/.claude/settings.json\"}"'
verifica "scrittura nel clone di watson bloccata" 'nega Write "{\"file_path\":\"$PLUGIN/WATSON.md\"}"'
verifica "scrittura fuori da 221b bloccata" 'nega Write "{\"file_path\":\"/tmp/x.md\"}"'
verifica "git diretto bloccato" 'nega Bash "{\"command\":\"git commit -am x\"}"'
verifica "comando qualsiasi bloccato" 'nega Bash "{\"command\":\"ls note\"}"'
verifica "script con operatori bloccato" 'nega Bash "{\"command\":\"$S/azione.sh --tipo cattura --sommario x; git push\"}"'
verifica "script con sostituzione bloccato" 'nega Bash "{\"command\":\"$S/azione.sh --tipo cattura --sommario \\\"\$(id)\\\"\"}"'
verifica "hook non invocabile dal modello" 'nega Bash "{\"command\":\"$S/contesto.sh\"}"'
verifica "servizi esterni bloccati" 'nega mcp__x__y "{}"'
verifica "nota permessa" 'permetti Write "{\"file_path\":\"$B/note/2026-09/x.md\"}"'
verifica "preferenze permesse" 'permetti Edit "{\"file_path\":\"$B/preferenze.md\"}"'
verifica "area di lavoro di Eevee permessa" 'permetti Write "{\"file_path\":\"$HOME/.watson/lavori/p/x.md\"}"'
verifica "azione.sh permesso" 'permetti Bash "{\"command\":\"$S/azione.sh --tipo cattura --sommario \\\"l'"'"'ultima nota\\\"\"}"'

echo "— Lint (prova 6)"
lint() { hook lint_nota.py "{\"cwd\":\"$B\",\"tool_input\":{\"file_path\":\"$B/$1\"}}"; }
nota() { mkdir -p note/2026-09; printf -- "---\ntitolo: Prova\n%s\nquando: 2026-09-30 10:00\ntodo: false\n---\n" "$2" > "note/2026-09/$1.md"; }
nota tipo-errato 'tipo: chiacchiera'
verifica "tipo non ammesso bloccato" 'lint note/2026-09/tipo-errato.md | grep -q "tipo .chiacchiera. non ammesso"'
nota alias 'tipo: nota
chi: ["[[dave]]"]'
verifica "alias corretto nella forma canonica" 'lint note/2026-09/alias.md | grep -q "usa la forma canonica \[\[davide\]\]"'
nota sconosciuta 'tipo: nota
chi: ["[[marta]]"]'
verifica "nome sconosciuto: rimanda all utente" 'lint note/2026-09/sconosciuta.md | grep -q "chiedi all.utente"'
nota senza-virgolette 'tipo: nota
progetto: [[alpha]]'
verifica "link senza virgolette bloccato" 'lint note/2026-09/senza-virgolette.md | grep -q "tra virgolette"'
nota buona 'tipo: nota
chi: ["[[davide]]"]'
verifica "nota valida non bloccata" '[ -z "$(lint note/2026-09/buona.md)" ]'
N0="$(commit)"
verifica "azione.sh rifiuta note non valide" '! "$S/azione.sh" --tipo cattura --sommario prova --frase prova >/dev/null 2>&1'
verifica "nessun commit con errori" '[ "$(commit)" = "$N0" ]'

echo "— Alias duplicato (prova 7)"
nuova
sed -i.bak 's/^alias: \[\]$/alias: [dave]/' persone/marco.md && rm persone/marco.md.bak
N0="$(commit)"
USCITA="$("$S/azione.sh" --tipo aggiorna --sommario "alias" --frase "marco è dave" 2>&1)"
verifica "commit rifiutato" '[ "$(commit)" = "$N0" ]'
verifica "violazione elencata" 'printf "%s" "$USCITA" | grep -q "\"dave\" appartiene a più nodi"'

echo "— Stop hook (prova 8)"
nuova
nota appesa 'tipo: nota'
PRIMO="$(hook stop.sh '{"stop_hook_active":false}')"
verifica "primo stop: chiede di chiudere con azione.sh" 'printf "%s" "$PRIMO" | grep -q "\"decision\": \"block\"" && printf "%s" "$PRIMO" | grep -q "azione.sh --tipo"'
SECONDO="$(hook stop.sh '{"stop_hook_active":true}')"
verifica "secondo stop: bozza in inbox con avviso" 'printf "%s" "$SECONDO" | grep -q "Salvato in bozza: inbox/"'
verifica "nota spostata fuori dal grafo" '[ ! -e note/2026-09/appesa.md ] && grep -q "tipo: nota" inbox/*_bozza.md'
verifica "repository pulito e consistente" '[ -z "$(git status --porcelain)" ] && python3 "$S/marauders_map.py" verifica . >/dev/null'
verifica "terzo stop: nessun blocco" '[ -z "$(hook stop.sh "{\"stop_hook_active\":true}")" ]'

echo "— Modifiche a mano (prova 9)"
nuova
sed -i.bak 's/\[\[luca\]\]/[[lucaa]]/' note/2026-09/2026-09-23_1500_1-1-luca.md && rm note/2026-09/*.bak
CTX="$(hook contesto.sh '{"hook_event_name":"SessionStart"}')"
verifica "commit manuale registrato" 'git log -1 --format=%s | grep -qx "manuale: modifiche a mano" && grep -q "· manuale · modifiche a mano" diario-di-bordo/*.md'
verifica "incoerenza in cima al contesto" 'printf "%s" "$CTX" | grep -q "additionalContext\": \"⚠️ INCOERENZE NEL GRAFO.*lucaa"'
nota altra-rotta 'tipo: nota
chi: ["[[giulia]]"]'
N0="$(commit)"
verifica "nuova incoerenza rifiutata" '! "$S/azione.sh" --tipo cattura --sommario x --frase x >/dev/null 2>&1 && [ "$(commit)" = "$N0" ]'
rm note/2026-09/altra-rotta.md
nota valida 'tipo: nota'
verifica "azione valida ammessa con incoerenza preesistente" '"$S/azione.sh" --tipo cattura --sommario x --frase x >/dev/null 2>&1'
sed -i.bak 's/\[\[lucaa\]\]/[[luca]]/' note/2026-09/2026-09-23_1500_1-1-luca.md && rm note/2026-09/*.bak
verifica "correzione ammessa" '"$S/azione.sh" --tipo mantieni --sommario "link corretto" --frase x >/dev/null 2>&1 && python3 "$S/marauders_map.py" verifica . >/dev/null'
verifica "tipo manuale riservato agli script" '! "$S/azione.sh" --tipo manuale --sommario x >/dev/null 2>&1'

echo "— Identità (prova 11)"
verifica "solo identità utente nei commit" '! git log --format="%an <%ae> · %cn <%ce>%n%b" | grep -qiE "claude|anthropic|co-authored"'

echo
[ "$FALLITI" -eq 0 ] && echo "Tutte le prove superate." || echo "$FALLITI prove fallite."
exit "$FALLITI"
