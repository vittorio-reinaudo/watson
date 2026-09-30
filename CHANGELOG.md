# Changelog

Ogni versione rimanda alle proposte in `evoluzioni/` che l'hanno prodotta.

## watson-v0.2 — interrogare e annullare

Proposta: [0000-baseline](evoluzioni/0000-baseline.md).

- Agenti di sola lettura `sherlock` (ricerca, Haiku), `whistledown` (riepiloghi), `q` (briefing per 1:1 e meeting).
- Skill `delorean` e `delorean.sh`: annulla un'azione tramite il suo id o l'ultima, con revert registrato come azione `annulla`; si ferma sui conflitti e rifiuta gli annullamenti che lascerebbero il grafo incoerente.
- Wrapper: continuità di sessione entro 10 minuti, `watson nuovo`, protocollo domanda con opzioni numerate, bozza in `inbox/` se interrompi o non rispondi.
- La risposta a una domanda si registra nel diario insieme al messaggio che l'ha provocata.
- Il contesto di ogni messaggio indica anche l'inizio della settimana corrente.

## watson-v0.1 — catturare con dati consistenti

Proposta: [0000-baseline](evoluzioni/0000-baseline.md).

- Plugin di Claude Code che fa da marketplace di se stesso; `install.sh` idempotente crea `221b` dal template.
- `WATSON.md` e `resoconto.md` iniettati all'avvio, insieme all'indice delle entità, alle preferenze e alle ultime righe del diario.
- Skill `memento` (note), `monica` (todo), `fellowship` (persone e progetti).
- `marauders_map.py`: indice deterministico e verifica di tutte le invarianti.
- `azione.sh`: un'azione, un commit, con indice e diario; rifiuta i commit che introducono incoerenze.
- Hook: contesto e data a ogni messaggio, guard sulle scritture e sui comandi, lint bloccante delle note, stop hook che chiude le azioni lasciate a metà o le mette in bozza.
- `bozza.sh`: nessuna nota persa, nemmeno se Claude Code non risponde.
- `bin/watson`: modalità one-shot e sessione interattiva.
