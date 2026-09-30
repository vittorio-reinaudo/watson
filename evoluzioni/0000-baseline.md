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

### Assunzioni della fase 2

- **Modello "predefinito" degli agenti.** Un agente senza `model` eredita il modello della sessione (Haiku). Per distinguere, come chiede la specifica, `whistledown`, `q` (e in seguito `wall-e` ed `eevee`) usano `model: sonnet`; `sherlock` usa `model: haiku`.
- **Contesto negli agenti.** Gli agenti non ricevono il contesto di avvio: leggono da soli `indice/entita.md`, e l'orchestratore passa loro nomi già risolti e la data di oggi.
- **Sessioni.** Il wrapper assegna l'id della sessione (`--session-id`) e lo salva con l'orario in `221b/.watson/session`; entro 10 minuti usa `--resume`. Se la sessione da riprendere non esiste più, riparte da una nuova. Anche `watson` senza argomenti segue la stessa regola. In una sessione ripresa `WATSON.md` e `resoconto.md` non vengono re-iniettati (sono già nella conversazione); la parte dati sì.
- **Risposte alle domande.** L'hook di invio riconosce dalla trascrizione che l'ultimo messaggio di Watson era una domanda (`? `) e registra la frase come `messaggio originale → risposta`, senza dipendere dal modello.
- **Interruzioni.** Oltre al caso della domanda aperta, un Ctrl-C mentre Claude Code sta lavorando manda in bozza il messaggio e le eventuali modifiche non registrate, salvo che l'azione sia già stata registrata. Le risposte alle domande si leggono dall'input standard.
- **Annullare.** `delorean.sh --ultima` annulla l'ultima azione registrata, anche se è un annullamento (così si annulla un annullamento); la creazione di `221b` (`init`) non si annulla. Prima di annullare servono zero modifiche non registrate. Un revert lascia sempre il diario com'era: l'annullamento è una riga nuova.
- **zsh.** `?` e `*` nelle frasi vengono espansi da zsh, che si ferma se non trova file corrispondenti; il README suggerisce `alias watson='noglob watson'`.

### Assunzioni della fase 3

- **Glob e Grep non sempre esistono.** In alcune sessioni di Claude Code gli strumenti Glob e Grep non sono disponibili ("find files with `find` via the Bash tool instead"). Il guard vieta `find` e `grep` come ogni comando che non sia uno script del plugin, quindi l'alternativa è lo script di sola lettura `cerca.sh` (file per nome, righe per testo), limitato a `221b`, al prodotto e all'area di lavoro.
- **Lettura fuori da 221b.** In headless Claude Code nega le letture fuori dalla cartella del progetto nonostante la regola `Read`: il guard concede esplicitamente la lettura del prodotto e di `~/.watson/lavori/`.
- **Permessi per agente.** Il guard riconosce l'agente dal campo `agent_type` dell'hook. Sherlock, Whistledown, Q e qualsiasi agente non elencato possono solo leggere e usare `cerca.sh`; Wall-E può anche scrivere in 221b e chiudere con `azione.sh`; Eevee scrive solo in `~/.watson/lavori/`. Solo l'orchestratore esegue `eevee_applica.sh` e `delorean.sh`.
- **Niente agenti in background.** Con agenti in background l'orchestratore rispondeva da solo alle loro domande e le notifiche finivano come messaggi dell'utente. Le impostazioni di `221b` impostano `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, e l'hook d'invio ignora le notifiche dei task.
- **Dry-run garantito dal guard.** Se l'ultimo messaggio inizia con `[dry-run]`, il guard nega ogni strumento tranne la lettura.
- **`test_routing.sh`.** Confronta famiglia, componente, tipo e ambiguità di ogni intenzione, nell'ordine. Normalizza il prefisso del plugin (`watson:sherlock`) e le forme verbali delle famiglie (`aggiorna` è `aggiornare`). Una frase che sbaglia al primo tentativo e torna giusta al secondo è segnalata come instabile ma non fa fallire il test: un instradamento davvero cambiato sbaglia entrambe le volte. In `esempi.md` più valori accettabili si separano con `/`.
- **Contabilità di `eevee_applica.sh`.** Versione (minore successiva a quella del plugin e a ogni tag), voce del `CHANGELOG.md`, `stato: applicata` e `versione:` della proposta li scrive lo script, non Eevee. Le prove prima di applicare sono `tests/test_script.sh` e `test_routing.sh` (con `esempi-personali.md` se esiste) su una copia del clone. Rifiuta se il clone ha modifiche non registrate o non è su un ramo (per esempio dopo `git checkout watson-v0.3`). Non gestisce la cancellazione di file.
- **`--annulla`.** Revert dell'ultimo commit `eevee:` con una nuova versione e un nuovo tag; `CHANGELOG.md` e le proposte restano come storia, con una voce che dice cosa è stato annullato. Prima del commit girano i test degli script.
- **Annullare una modifica a Watson** passa dalla skill `delorean` (è un annullamento), che esegue `eevee_applica.sh --annulla`.
- **Wall-E in due tempi.** Piano senza scrivere, poi esecuzione del piano approvato; una bozza ripresa esce da `inbox/` con `azione.sh --rimuovi`, nello stesso commit in cui il suo contenuto entra nel grafo.
- **Più domande di Eevee.** Eevee prepara sempre la proposta completa con dei default e fa al massimo una domanda; l'orchestratore le pone una alla volta. Il wrapper riconosce una domanda anche se la riga `? ` non è la prima.
- **Preferenze apprese.** Una riga in fondo a `preferenze.md` nel formato `- <regola>. (AAAA-MM-GG, da: "<frase>")`, chiusa come azione `impara`: `watson annulla` la toglie come qualsiasi altra azione.

### Divergenze note tra README e comportamento

- `watson nuovo progetto alpha: …` (README, primo avvio) viene letto come `watson nuovo` + frase: parte una sessione nuova con il messaggio "progetto alpha: …", che Watson riconosce comunque come creazione di un progetto. Lasciato così su indicazione dell'utente.

## Esempi

Le prove di accettazione sono in `tests/test_script.sh` (senza modello) e, per il riconoscimento delle intenzioni, in `esempi.md`.

## Cosa non deve cambiare

I sette principi e le invarianti della specifica.
