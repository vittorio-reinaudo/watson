# Prompt per Claude Code: costruisci Watson

Copia questa cartella (`PROMPT.md`, `SPEC.md`, `README.md`) in una directory vuota chiamata `watson`, apri Claude Code lì dentro e incolla il testo qui sotto.

---

Costruisci **Watson**, un assistente da terminale per tech lead, sotto forma di **plugin di Claude Code**. La specifica completa è in `SPEC.md`: leggila tutta prima di iniziare. È la fonte di verità: se questo prompt e la specifica divergono, vince la specifica e mi segnali la differenza.

`README.md` descrive già come l'utente clona, installa e usa Watson: l'implementazione deve rispettarlo alla lettera (comandi, percorsi, variabili, comportamento di `install.sh`). Se qualcosa del README non è realizzabile, dimmelo invece di cambiarlo in silenzio.

Lavora per fasi. Alla fine di ogni fase fai commit, tag e aggiornamento del changelog, poi fermati e dammi un resoconto prima di passare alla successiva.

## Prima di scrivere codice

1. **Verifica le funzionalità di Claude Code** su cui si basa l'architettura, leggendo la documentazione aggiornata e `claude --help`: struttura dei plugin e dei marketplace, installazione e aggiornamento di un plugin da un marketplace locale, abilitazione di un plugin nelle impostazioni di progetto, formato di skill e agenti, eventi degli hook (avvio della sessione, invio del messaggio, prima e dopo uno strumento, fine della risposta), come un hook aggiunge contesto e come blocca un'azione restituendo l'errore al modello, regole di permesso in `settings.json`, impostazione che disattiva l'attribuzione a Claude nei commit, modalità headless con output JSON e ripresa della sessione.
2. **Se qualcosa non esiste o funziona diversamente** da come lo descrivono specifica e prompt, fermati, spiegami la differenza e proponi l'alternativa più vicina. Non improvvisare.
3. **Disattiva l'attribuzione a Claude** nel `.claude/settings.json` di questo repository, prima del tuo primo commit.

## Principio di progetto

Ogni responsabilità sta dove può essere garantita:

- **il modello** decide il contenuto: intenzione, testo delle note, risposte;
- **gli script** fanno la contabilità: id d'azione, diario, indice, verifica, commit, revert, bozze;
- **gli hook** fanno rispettare le regole: contesto, permessi, lint, nessuna modifica lasciata a metà;
- **il wrapper** gestisce solo l'esperienza da terminale.

La consistenza dei dati è una regola ferrea (sezione "Consistenza dei dati" della specifica): nessun commit può violare un'invariante, e nessun controllo di consistenza può dipendere dal modello.

## Due repository

Stai lavorando in **`watson`**, il prodotto, che è insieme plugin e marketplace di se stesso. Il repository dati **`221b`** viene creato da `install.sh` in `$WATSON_BRAIN`, default `~/221b`. `221b` non contiene mai codice del prodotto; `watson` non contiene mai nomi reali o dati personali.

Struttura di `watson`:

```
watson/
├── .claude-plugin/
│   ├── plugin.json            # nome, versione, descrizione
│   └── marketplace.json       # marketplace che contiene questo plugin
├── .claude/settings.json      # attribuzione a Claude disattivata per i tuoi commit di costruzione
├── WATSON.md                  # identità e regole, iniettate dall'hook di avvio
├── resoconto.md               # frasi fisse del resoconto
├── SPEC.md  README.md  CHANGELOG.md
├── esempi.md                  # frasi generiche → intenzione attesa
├── evoluzioni/
│   └── 0000-baseline.md       # stato iniziale e assunzioni prese
├── skills/
│   ├── memento/SKILL.md
│   ├── monica/SKILL.md
│   ├── fellowship/SKILL.md
│   └── delorean/SKILL.md
├── agents/
│   ├── sherlock.md  whistledown.md  q.md  wall-e.md  eevee.md
├── hooks/
│   └── hooks.json
├── scripts/
│   ├── contesto.sh            # hook avvio e invio messaggio
│   ├── guard.py               # hook prima di ogni strumento
│   ├── lint_nota.py           # hook dopo ogni scrittura
│   ├── stop.sh                # hook fine risposta
│   ├── azione.sh              # chiude ogni scrittura: verifica, indice, diario, commit
│   ├── marauders_map.py       # indice + verifica delle invarianti
│   ├── delorean.sh            # annulla tramite id azione
│   ├── eevee_applica.sh       # unica strada per modificare il prodotto
│   ├── bozza.sh               # salva in inbox
│   └── test_routing.sh
├── bin/watson                 # wrapper da terminale
├── install.sh
├── templates/221b/            # struttura iniziale del repository dati
└── tests/fixture/             # un 221b finto con Alpha e Beta, nomi generici
```

Struttura iniziale di `221b`:

```
221b/
├── .claude/settings.json      # plugin watson attivo, permessi, attribuzione a Claude disattivata
├── .gitignore                 # .watson/ (stato di sessione)
├── persone/  progetti/  note/  inbox/
├── indice/                    # generato
├── diario-di-bordo/           # solo aggiunte, tramite script
├── preferenze.md
└── esempi-personali.md
```

## Componenti

**`WATSON.md`.** Identità, principi (sette, nell'ordine della specifica), modello dati, regole di conversazione e resoconto con riferimento a `resoconto.md`. Deve definire anche:

- il protocollo domanda: una sola domanda chiusa, prima riga che inizia con `? `, opzioni numerate già interpretate;
- l'obbligo di chiudere ogni azione che scrive con `azione.sh`;
- la regola per gli agenti: non parlano mai con l'utente, restituiscono eventuali domande all'orchestratore;
- il riconoscimento delle richieste su Watson stesso: non procede mai da solo, ma pone la domanda a tre opzioni della specifica (lavorarci ora con Eevee, annotarla come idea, era una nota normale) e prima di applicare mostra le differenze e chiede conferma;
- la modalità dry-run: se il messaggio inizia con `[dry-run]`, Watson non scrive nulla e risponde solo con `{"intenzioni": [{"famiglia", "componente", "tipo", "persone", "progetto"}], "ambigua": bool}`.

**Skill** (`memento`, `monica`, `fellowship`, `delorean`) e **agenti** (`sherlock`, `whistledown`, `q`, `wall-e`, `eevee`), come nella tabella "Skill e agenti" della specifica. Le skill sono invocabili dal modello. La `description` di ogni skill e agente è la parte più importante: dice quando usarlo, con 3–5 frasi d'esempio realistiche, e quando non usarlo. Strumenti minimi per ciascuno; gli agenti di sola lettura non hanno strumenti di scrittura. Modelli: sessione principale Haiku, `sherlock` Haiku, gli altri agenti il modello predefinito.

**Hook** (`hooks/hooks.json`, script referenziati tramite la variabile del percorso del plugin):

- **Avvio della sessione** → `contesto.sh`: se `221b` ha modifiche non registrate le committa come `manuale: modifiche a mano` con riga nel diario, rigenera l'indice, esegue la verifica e, se trova incoerenze, le mette in cima al contesto. Poi inietta `WATSON.md`, `indice/entita.md`, `preferenze.md` e le ultime 5 righe del diario.
- **Invio di ogni messaggio** → `contesto.sh`: aggiunge `[adesso: <giorno> AAAA-MM-GG HH:MM]`.
- **Prima di ogni strumento** → `guard.py`: in `221b` scritture permesse solo in `note/`, `persone/`, `progetti/`, `inbox/`, `preferenze.md`, `esempi-personali.md`, più l'area di lavoro di Eevee `~/.watson/lavori/`; mai in `indice/`, `diario-di-bordo/`, `.claude/`. Nessuna scrittura diretta nel clone di `watson`, da nessun componente. Nessun comando di shell tranne gli script del plugin. Nessun `git` diretto.
- **Dopo una scrittura** → `lint_nota.py`: valida il file scritto (frontmatter completo, `tipo` ammesso, date valide, campi del todo coerenti, ogni `[[link]]` risolto su un nodo esistente in forma canonica). In caso di errore **blocca**: restituisce al modello un messaggio che dice esattamente cosa correggere; per un alias indica la forma canonica, per un nome sconosciuto dice di chiedere all'utente.
- **Fine della risposta** → `stop.sh`: se restano modifiche non registrate, blocca e chiede al modello di chiudere l'azione con `azione.sh`. Se succede di nuovo nello stesso giro, sposta le modifiche in `inbox/` come bozza con `bozza.sh`, fa il commit e lascia al modello un avviso da riportare nel resoconto.

**`scripts/marauders_map.py`.** Solo libreria standard, con un parser minimo per il sottoinsieme YAML della specifica. Due modalità:

- **indice:** scrive `indice/entita.md` e `indice/note-AAAA-MM.md`, in ordine deterministico, stesso input stesso output byte per byte;
- **verifica:** controlla tutte le invarianti della specifica sull'intero grafo, `inbox/` esclusa, e restituisce un elenco di violazioni leggibili con codice di uscita diverso da zero se ce ne sono.

**`scripts/azione.sh`.** Riceve tipo, scope, sommario, dettaglio e frase originale. Genera l'id d'azione (`a-AAAAMMGG-HHMM`, con suffisso se già usato), rigenera l'indice, esegue la verifica e **si rifiuta di fare il commit** se una invariante è violata, stampando le violazioni. Se tutto è valido aggiunge la riga al diario della settimana ISO corrente, fa `git add -A` e il commit nel formato della specifica con l'identità git dell'utente, poi il push se c'è un remoto (un errore di push non blocca l'azione). Stampa l'id.

**`scripts/delorean.sh`.** `delorean.sh <id>` oppure `--ultima`. Trova il commit tramite `git log --grep`, ne fa il revert senza commit. Se c'è un conflitto annulla il revert, esce con codice 2 ed elenca i file coinvolti. Altrimenti chiude con `azione.sh` come azione `annulla` che punta all'id annullato; se il revert produrrebbe un'incoerenza, `azione.sh` lo rifiuta e Watson lo spiega.

**`scripts/eevee_applica.sh`.** Unica strada per modificare il prodotto. Riceve una cartella dell'area di lavoro preparata da Eevee: mostra le differenze rispetto al clone di `watson` (`$WATSON_HOME`), applica le modifiche a una copia temporanea ed esegue `test_routing.sh`, e si rifiuta di procedere se i test falliscono. Se passano, copia le modifiche nel clone, fa commit e tag `watson-v0.N` con l'identità git dell'utente, aggiorna il plugin installato e stampa la nuova versione. Con `--annulla` fa il revert dell'ultima modifica applicata, con un nuovo commit e tag, e aggiorna il plugin.

**`scripts/bozza.sh`.** Salva in `inbox/` il messaggio originale, l'eventuale domanda rimasta aperta e ogni modifica non registrata, con commit e riga nel diario.

**`bin/watson`** (bash, JSON letto con `python3`):

- `watson <frase>`: modalità headless nella cartella `221b`, stampa solo il resoconto;
- `watson`: sessione interattiva in `221b`;
- `watson nuovo [frase]`: scarta la sessione precedente;
- continuità: id e orario dell'ultima sessione in `221b/.watson/session`; entro 10 minuti riprende quella sessione;
- protocollo domanda: se la risposta inizia con `? `, mostra domanda e opzioni, legge la risposta e la invia nella stessa sessione, finché non arriva un resoconto;
- se l'utente interrompe con Ctrl-C, EOF o risposta vuota mentre c'è una domanda aperta, chiama `bozza.sh`.

Permessi, contesto e controlli non stanno nel wrapper: li gestiscono impostazioni e hook.

**`install.sh`.** Idempotente, in quest'ordine:

1. verifica che `git config user.name` e `user.email` siano impostati, altrimenti si ferma e spiega come farlo;
2. registra il clone corrente come marketplace locale e installa il plugin da lì;
3. collega `bin/watson` in `~/.local/bin/` e salva il percorso del clone per `WATSON_HOME`;
4. se `$WATSON_BRAIN` non esiste, lo crea dal template con `git init` e primo commit; se esiste, non lo sovrascrive mai.

**`scripts/test_routing.sh`.** Copia `tests/fixture/` in una directory temporanea, esegue ogni frase di `esempi.md` in dry-run e confronta componente e intenzione con quelle attese. Esce con codice diverso da zero se ci sono differenze. Opzione per usare anche `esempi-personali.md`.

## Fasi

**Fase 1 — v0.1, catturare con dati consistenti.** Scheletro del plugin e del marketplace, `install.sh`, template di `221b` con impostazioni, fixture, `WATSON.md`, `resoconto.md`, tutti gli hook (`contesto.sh`, `guard.py`, `lint_nota.py`, `stop.sh`), `marauders_map.py` con indice e verifica, `azione.sh`, `bin/watson` in modalità one-shot, skill `memento`, `monica`, `fellowship`.

**Fase 2 — v0.2, interrogare e annullare.** Agenti `sherlock`, `whistledown`, `q`. Skill `delorean` e `delorean.sh`. Nel wrapper: continuità di sessione, protocollo domanda, `bozza.sh` su interruzione.

**Fase 3 — v0.3, evolvere.** Agenti `wall-e` ed `eevee`, riconoscimento delle richieste su Watson con la domanda a tre opzioni, area di lavoro, `eevee_applica.sh` con `--annulla`, preferenze apprese, `esempi.md`, `test_routing.sh`, `evoluzioni/` con il formato di proposta della specifica.

A ogni fase: commit, tag `watson-v0.N`, voce in `CHANGELOG.md`, `README.md` allineato a ciò che funziona davvero, resoconto per me con cosa funziona, cosa no e le assunzioni prese.

## Criteri di accettazione

Prova sempre su una copia temporanea di `tests/fixture/`, **mai** sul `221b` reale. La fixture ha due progetti, `alpha` (anna, luca, davide con alias dave, sara) e `beta` (marco, elena, paolo, chiara), e qualche nota di esempio.

| # | Prova | Esito atteso | Fase |
| --- | --- | --- | --- |
| 1 | `watson su alpha oggi luca ha sbagliato un rilascio` | nota di tipo incidente collegata a luca e alpha; resoconto firmato Memento; un solo commit con nota, indice e diario | 1 |
| 2 | `watson ho assegnato a dave il fix del login entro venerdì` | todo con `owner: [[davide]]` (alias risolto dal lint, mai `[[dave]]` nel commit), scadenza come data, progetto dedotto; resoconto firmato Monica | 1 |
| 3 | `watson fatto il fix del login` | il todo passa a `stato: fatto` | 1 |
| 4 | `watson nota su marta` (sconosciuta) | domanda chiusa, nessun nodo creato senza conferma, nessun `[[marta]]` nel grafo | 1 |
| 5 | scrittura diretta in `indice/` o `diario-di-bordo/`, o un `git commit` diretto | bloccati dal guard | 1 |
| 6 | nota con `tipo` non ammesso o link a un nodo inesistente | il lint blocca; il modello corregge o chiede; nessun commit con errori | 1 |
| 7 | alias duplicato tra due persone introdotto in un'azione | `azione.sh` rifiuta il commit ed elenca la violazione | 1 |
| 8 | modifica non registrata a fine risposta | lo stop hook fa chiudere l'azione; al secondo tentativo fallito finisce in inbox con avviso | 1 |
| 9 | modifica a mano che rompe un link, poi qualsiasi comando | commit `manuale` all'avvio, incoerenza segnalata nella prima riga, nessuna nuova azione può aggiungerne altre | 1 |
| 10 | installazione da zero seguendo il README in una home temporanea (`HOME=$(mktemp -d)`) | plugin installato e attivo in `221b`, `watson` disponibile, `221b` creato; seconda esecuzione senza effetti | 1 |
| 11 | `git log --format='%an <%ae> · %cn <%ce>%n%b'` in `watson` e nella sandbox di `221b` | solo l'identità dell'utente, nessuna riga che citi Claude come autore o co-autore | ogni fase |
| 12 | `watson luca rilascio di ieri`, poi Ctrl-C | domanda chiusa; la frase finisce in `inbox/` | 2 |
| 13 | `watson cosa è successo su alpha questa settimana`, poi `watson e su beta?` | riepilogo di Whistledown con fonti; la seconda riprende la sessione | 2 |
| 14 | `watson prepara il mio 1:1 con luca` | briefing di Q che include il todo delegato ancora aperto | 2 |
| 15 | `watson annulla` | revert dell'ultima azione, riga `annulla` nel diario, invarianti rispettate | 2 |
| 16 | tentativo di scrivere direttamente nel clone di `watson`, da qualunque skill o agente | bloccato dal guard; l'unica strada è `eevee_applica.sh` | 3 |
| 17 | `./scripts/test_routing.sh` | tutti gli esempi instradati come atteso | 3 |
| 18 | `watson vorrei un riepilogo automatico ogni venerdì` | domanda a tre opzioni; con "lavoriamoci ora" Eevee prepara la proposta nell'area di lavoro con i suoi suggerimenti; nulla applicato senza conferma | 3 |
| 19 | modifica preparata da Eevee che rompe un esempio di routing | `eevee_applica.sh` rifiuta di applicarla | 3 |
| 20 | `watson annulla l'ultima modifica a watson` | revert con nuovo tag, plugin aggiornato, note intatte | 3 |

Inoltre `marauders_map.py` produce output identici su due esecuzioni con lo stesso input.

## Vincoli

- **Tutti i commit sono a nome dell'utente.** In entrambi i repository, compresi quelli che fai tu costruendo Watson, autore e committer sono l'identità git dell'utente. Mai `--author` o variabili `GIT_AUTHOR_*`/`GIT_COMMITTER_*`, mai righe `Co-Authored-By`, "Generated with Claude Code" o simili.
- **Consistenza prima di tutto.** Nessuna scorciatoia che permetta un commit con invarianti violate, nemmeno nei test o negli script di manutenzione.
- Dipendenze: bash, git, python3 (libreria standard) e Claude Code. Funziona su macOS e Linux: per le date usa python.
- Mai riscrivere la cronologia git: niente `reset`, `rebase`, push forzati.
- Nessun nome reale in `watson`: fixture, esempi e documentazione usano solo nomi generici.
- Tutto il testo rivolto all'utente è in italiano.
- Dove la specifica lascia una decisione aperta, usa il default indicato e annotalo in `evoluzioni/0000-baseline.md`.
