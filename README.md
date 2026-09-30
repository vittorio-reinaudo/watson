# Watson

Watson è un assistente da terminale per tech lead, costruito come plugin di Claude Code. Scrivi un appunto in linguaggio naturale e Watson capisce da solo se è una nota, un compito, una domanda o una correzione, lo collega alle persone e ai progetti giusti e te lo fa ritrovare quando serve.

Il nome viene dal dottor Watson, che tiene i taccuini di Sherlock Holmes e ricorda ogni dettaglio dei casi.

```
$ watson su alpha oggi luca ha sbagliato un rilascio
📸 Memento · Polaroid scattata: "Rilascio fallito" · incidente, per luca su alpha

$ watson ho assegnato a dave il fix del login entro venerdì
📋 Monica · In lista: "Fix del login" · per davide su alpha, entro venerdì 9 ottobre

$ watson prepara il mio 1:1 con luca
🍸 Q · Briefing pronto: 1:1 con luca
...
```

## Come funziona

Watson è fatto di due repository separati:

| Repository | Cosa contiene | Visibilità |
| --- | --- | --- |
| `watson` (questo) | il prodotto: un plugin di Claude Code con skill, agenti, hook e script | condivisibile |
| `221b` | i tuoi dati: note, persone, progetti, indice, diario | privato, solo sul tuo computer salvo tua scelta |

`221b` prende il nome dall'indirizzo di Baker Street dove Holmes e Watson custodiscono i loro casi.

Quando scrivi `watson <frase>`, il comando apre Claude Code nella cartella `221b` con il plugin attivo. Watson riconosce cosa vuoi fare, scrive o legge le note e chiude con una riga di resoconto. Le operazioni veloci, come catturare una nota, le fa direttamente; quelle pesanti, come un riepilogo del mese o il briefing per un 1:1, le affida ad agenti dedicati.

Le note formano un grafo: una nota può riguardare una persona, un progetto o entrambi, senza dover scegliere una cartella. I file sono markdown semplici, compatibili con Obsidian.

Due garanzie valgono sempre:

- **Nessuna nota va persa.** Se Watson non capisce o viene interrotto, la frase finisce comunque in `inbox/`.
- **I dati restano consistenti.** Ogni nota viene verificata prima di entrare nel grafo: nomi, collegamenti e campi devono essere validi, altrimenti Watson corregge o ti chiede. Ogni azione diventa un commit git a tuo nome, quindi tutto si può annullare.

I dettagli completi sono in [`SPEC.md`](SPEC.md).

## Stato

Versione **v0.2**: catturare, interrogare e annullare. Funzionano note, todo, persone e progetti, ricerche, riepiloghi e briefing per 1:1 e meeting, `watson annulla`, la continuità tra comandi entro 10 minuti, le domande chiuse in caso di dubbio e le bozze in `inbox/` quando interrompi. Arriva nella prossima versione Eevee, per far evolvere Watson. Le novità di ogni versione sono in [`CHANGELOG.md`](CHANGELOG.md).

## Requisiti

- [Claude Code](https://docs.claude.com/en/docs/claude-code) installato e con l'accesso già configurato (`claude` deve funzionare nel terminale)
- git, configurato con il tuo nome ed email: tutti i commit di Watson sono a tuo nome
- python3
- bash, su macOS o Linux

## Installazione

**1. Clona il repository** nella cartella che preferisci.

```bash
git clone https://github.com/<tuo-utente>/watson.git
cd watson
```

Lascialo in quella cartella: il plugin viene installato a partire da qui, ed è qui che Watson applica le proprie evoluzioni.

**2. Controlla la tua identità git.** Watson firma ogni commit con il tuo nome, mai con quello di Claude:

```bash
git config --global user.name
git config --global user.email
```

Se uno dei due è vuoto, impostalo:

```bash
git config --global user.name "Nome Cognome"
git config --global user.email "tu@esempio.com"
```

**3. Esegui l'installazione.**

```bash
./install.sh
```

Lo script si può rilanciare senza problemi, e fa quattro cose:

- controlla che la tua identità git sia configurata;
- registra questo clone come marketplace e installa da qui il plugin Watson in Claude Code;
- collega il comando `watson` in `~/.local/bin/`;
- crea il tuo `221b` in `~/221b`, con `git init` e un primo commit. Se esiste già, non lo tocca.

Per usare una cartella diversa per i dati, imposta la variabile prima di installare e aggiungila al tuo `~/.zshrc` o `~/.bashrc`:

```bash
export WATSON_BRAIN=~/percorso/che/preferisci
```

**4. Controlla che `~/.local/bin` sia nel PATH.**

```bash
which watson
```

Se non trova nulla, aggiungi al tuo `~/.zshrc` o `~/.bashrc` la riga seguente e apri un nuovo terminale:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Se usi zsh, aggiungi anche questa riga al tuo `~/.zshrc`: senza, zsh prova a interpretare `?` e `*` come nomi di file e un comando come `watson e su beta?` si ferma con "no matches found".

```bash
alias watson='noglob watson'
```

## Primo avvio

Presenta a Watson i tuoi progetti e il tuo team con frasi normali:

```bash
watson nuovo progetto alpha: il backend dei pagamenti
watson in alpha lavorano anna, luca, sara e davide, che tutti chiamano dave
watson luca è il backend lead di alpha
```

Da quel momento Watson riconosce nomi e soprannomi. Se incontra una persona che non conosce, te lo chiede prima di aggiungerla: non inventa mai un nome.

## Uso quotidiano

Un solo comando, in linguaggio naturale:

| Vuoi... | Scrivi per esempio |
| --- | --- |
| prendere una nota | `watson su beta la demo di marco è andata benissimo` |
| assegnare un compito | `watson ho chiesto a elena la stima entro giovedì` |
| ricordarti qualcosa | `watson ricordami di rivedere la roadmap lunedì` |
| chiudere un compito | `watson fatto la stima di elena` |
| cercare | `watson quella decisione con luca sul caching` |
| un riepilogo | `watson cosa è successo su alpha questa settimana` |
| preparare un 1:1 | `watson prepara il mio 1:1 con marco` |
| annullare | `watson annulla` |

Qualche dettaglio utile:

- Un comando lanciato entro 10 minuti dal precedente continua la stessa conversazione: dopo un riepilogo su Alpha puoi scrivere `watson e su beta?`. `watson nuovo` riparte da zero.
- Se una frase è ambigua, Watson fa una domanda con opzioni numerate. Se non rispondi, la frase viene salvata comunque in `inbox/`.
- `watson` senza argomenti apre una sessione, comoda per le attività lunghe: la revisione della settimana, preparare più 1:1, riordinare.
- Se vuoi forzare un'intenzione: `watson nota: ...`, `watson todo: ...`, `watson cerca: ...`.
- Puoi modificare le note anche a mano. Alla sessione successiva Watson registra le tue modifiche e, se qualcosa non torna, te lo segnala e propone come sistemarlo.

## Far evolvere Watson

Per cambiare Watson stesso non serve un comando dedicato: parlagliene come faresti per una nota.

```
$ watson vorrei un riepilogo automatico ogni venerdì
Sembra una modifica a Watson stesso. Cosa preferisci?
  1. lavoriamoci ora con Eevee
  2. annotala come idea per dopo
  3. no, era una nota normale
```

Se scegli di lavorarci subito, Eevee, l'agente di evoluzione, ti aiuta a definire la modifica e propone alternative e casi limite. Prima di applicare ti mostra le differenze e aspetta la tua conferma. Le modifiche passano sempre da uno script che esegue i test e si rifiuta di applicare qualcosa che romperebbe il comportamento esistente. Ogni modifica applicata aggiorna `SPEC.md`, viene registrata in `CHANGELOG.md` con un tag di versione, e il plugin installato si aggiorna da solo.

Se cambi idea:

```bash
watson annulla l'ultima modifica a watson
```

Durante il lavoro puoi anche solo annotare un'idea, scegliendo "annotala come idea per dopo": Eevee la ritroverà nella revisione settimanale.

## Aggiornare e tornare indietro

Per aggiornare Watson all'ultima versione pubblicata, dalla cartella del clone:

```bash
git pull
./install.sh
```

Per tornare a una versione precedente, se una modifica non ti convince:

```bash
git checkout watson-v0.3
./install.sh
```

Le tue note in `221b` non vengono toccate in nessuno dei due casi.

## Backup e privacy

`221b` contiene informazioni personali sul tuo team: feedback, 1:1, carriera. Per questo di default resta solo sul tuo computer. Se vuoi un backup, aggiungi un remoto **privato**:

```bash
cd ~/221b
git remote add origin <url-di-un-repository-privato>
git push -u origin main
```

Da quel momento Watson fa il push dopo ogni azione, e se sei offline riprova più tardi.

Non mettere mai note o nomi reali nel repository `watson`: è pensato per essere condiviso.

## Disinstallare

Disinstalla il plugin Watson dal gestore dei plugin di Claude Code, poi rimuovi il comando:

```bash
rm ~/.local/bin/watson
```

La cartella `221b` resta intatta: sono i tuoi dati, e restano leggibili anche senza Watson.

## Struttura del repository

```
watson/
├── .claude-plugin/  # definizione del plugin e del marketplace
├── WATSON.md        # identità e regole di Watson
├── SPEC.md          # come funziona Watson oggi
├── CHANGELOG.md     # versioni e modifiche applicate
├── resoconto.md     # le frasi fisse del resoconto
├── esempi.md        # frasi di test per il riconoscimento delle intenzioni
├── evoluzioni/      # proposte di modifica, una per file
├── skills/          # operazioni rapide: memento, monica, fellowship, delorean
├── agents/          # operazioni pesanti: sherlock, whistledown, q, wall-e, eevee
├── hooks/           # quando scattano i controlli
├── scripts/         # indice, verifica, commit, annulla, controlli
├── bin/watson       # il comando
├── install.sh
├── templates/       # struttura iniziale di 221b
└── tests/           # un 221b finto per i test
```
