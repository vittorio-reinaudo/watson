---
id: 0000
titolo: Stato iniziale e assunzioni
stato: applicata
percorso: completo
idee: []
versione: watson-v0.1
---

## Problema

Costruire Watson a partire da `SPEC.md` (versione 0.2 della specifica) come plugin di Claude Code. Questo documento raccoglie le decisioni prese dove la specifica lascia spazio, le differenze tra la specifica e il comportamento reale di Claude Code (verificato sulla versione 2.1.285) e i default delle decisioni aperte.

## Comportamento atteso

### Decisioni aperte: default adottati

- **Viewer:** file compatibili con Obsidian (link `[[nome]]` tra virgolette nel frontmatter); Watson funziona solo da terminale.
- **Insieme delle relazioni:** le sei della specifica: `chi`, `progetto`, `owner`, `progetti` (membro di), `segue`, `blocca`.
- **Todo:** flag `todo: true` su una nota.
- **Stato attuale nei nodi:** aggiornato solo su richiesta.
- **Finestra di sessione:** 10 minuti.
- **Remoto git di 221b:** nessuno; se l'utente lo aggiunge, push in background dopo ogni commit.
- **Migrazione:** a carico di Wall-E, con piano mostrato prima (fase 3).

### Come si adatta Claude Code

- **Modello della sessione principale.** Un plugin non può impostarlo: Haiku è impostato con `"model": "haiku"` nel `.claude/settings.json` di `221b`, che vale anche in modalità headless.
- **Attivo solo in 221b.** Un plugin installato con ambito utente sarebbe attivo in ogni progetto. `install.sh` lo installa e lo disattiva a livello utente; le impostazioni di progetto di `221b` lo riattivano solo lì.
- **Plugin caricato dal clone.** Un marketplace di tipo directory carica il plugin direttamente dal clone, senza copia in cache: le modifiche al clone valgono dalla sessione successiva. `eevee_applica.sh` e `install.sh` chiamano comunque `claude plugin update`.
- **Limite del contesto iniettato.** Claude Code tronca ogni `additionalContext` oltre circa 10.000 caratteri. Il contesto di avvio è diviso in tre hook: `WATSON.md`, `resoconto.md` (iniettato anch'esso, per avere sempre le frasi fisse) e i dati (incoerenze, indice delle entità, preferenze, ultime righe del diario).
- **Percorsi degli script.** `${CLAUDE_PLUGIN_ROOT}` non esiste nella shell del modello: viene sostituito nel testo delle skill da Claude Code e in `WATSON.md` da `contesto.sh`.
- **Permessi in headless.** In modalità `-p` ciò che non è permesso viene negato. Il guard concede esplicitamente (`allow`) le scritture ammesse e gli script del plugin; le impostazioni di `221b` permettono lettura, skill e agenti e negano git, web e le cartelle protette.
- **Lint dopo la scrittura.** Un hook PostToolUse non può annullare la scrittura: restituisce l'errore al modello, che corregge. La consistenza è garantita dal fatto che l'unico commit possibile passa da `azione.sh`, e che lo stop hook non lascia modifiche a metà.
- **Plugin dell'utente.** I plugin installati a livello utente si caricano anche nelle sessioni Watson; il plugin non può escluderli.

### Assunzioni sul modello dati

- Campi obbligatori di una nota: `titolo`, `tipo`, `quando`, `todo`. `chi`, `progetto`, `tags`, `segue`, `blocca` sono facoltativi ma validati se presenti: una nota sulla roadmap non ha persone.
- `quando` è `AAAA-MM-GG HH:MM` (ammesso anche `AAAA-MM-GG`); la nota sta in `note/AAAA-MM/` del mese di `quando`.
- `scadenza` è facoltativa (un todo delegato senza scadenza si salva comunque); se `todo: false` non ci sono `owner`, `stato`, `scadenza`; `tipo: todo` richiede `todo: true`.
- I link nel frontmatter vanno tra virgolette (`"[[luca]]"`): senza virgolette YAML li leggerebbe come liste annidate, e Obsidian non li riconoscerebbe.
- Nomi e alias sono unici su persone e progetti insieme, senza distinzione tra maiuscole e minuscole. Una nota si collega con il nome del file senza `.md`.
- Anche i `[[link]]` nel corpo delle note e dei nodi devono risolversi.
- `progetti/watson.md` fa parte del template di `221b`, per le idee su Watson stesso.

### Assunzioni su consistenza e git

- **Quando `azione.sh` rifiuta.** Rifiuta se le violazioni dopo l'azione non sono un sottoinsieme di quelle dell'ultimo commit. Con un grafo pulito equivale a "nessuna violazione"; dopo una modifica a mano che rompe qualcosa, permette le azioni che non peggiorano e le correzioni, come dice la specifica ("nessuna nuova azione può aggiungerne altre").
- **Il primo commit di 221b** è un'azione `init` con la sua riga nel diario, così l'invariante "ogni azione ha commit e riga nel diario, e viceversa" vale dall'inizio. L'invariante si verifica confrontando gli id del diario con le righe `azione:` dei commit.
- **Tipi riservati.** `manuale` e `init` si possono usare solo dagli script (variabile d'ambiente interna); il guard impedisce al modello di impostarla, perché accetta solo comandi che iniziano con uno script del plugin.
- **Frase originale.** L'hook di invio salva l'ultimo messaggio in `221b/.watson/ultimo-messaggio`; `azione.sh` e `bozza.sh` lo usano se il modello non passa `--frase`.
- **Comandi git negli script**, oltre a quelli della specifica: `init`, `rev-parse`, `archive` (per verificare l'ultimo commit), `show HEAD:<file>` (per riportare un file all'ultimo commit quando le modifiche vanno in bozza). Nessuno riscrive la cronologia.
- **Bozze.** `bozza.sh` salva in un unico file di `inbox/` il messaggio, l'eventuale domanda e il contenuto o le differenze di ogni modifica non registrata, poi riporta il grafo all'ultimo commit e registra l'azione `bozza`.
- **Errori di Claude Code.** Se la sessione headless fallisce (per esempio per un limite d'uso), il wrapper salva la frase in bozza: nessuna nota persa.
- **Formato di `azione.sh`.** Argomenti nominati (`--tipo`, `--scope`, `--sommario`, `--dettaglio`, `--frase`) invece che posizionali: con Haiku l'ordine posizionale si è rivelato fragile.
- **Il guard** rifiuta nei comandi `$`, backtick, a capo e operatori di shell, anche tra virgolette: meglio un rifiuto in più che una scorciatoia.
- **Servizi esterni.** Il guard nega in 221b gli strumenti MCP e il web: `221b` contiene dati personali.

### Divergenze note tra README e comportamento

- `watson nuovo progetto alpha: …` (README, primo avvio) viene letto come `watson nuovo` + frase: parte una sessione nuova con il messaggio "progetto alpha: …", che Watson riconosce comunque come creazione di un progetto. Lasciato così su indicazione dell'utente.

## Esempi

Le prove di accettazione sono in `tests/test_script.sh` (senza modello) e, per il riconoscimento delle intenzioni, in `esempi.md`.

## Cosa non deve cambiare

I sette principi e le invarianti della specifica.
