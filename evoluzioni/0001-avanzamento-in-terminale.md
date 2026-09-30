---
id: 0001
titolo: Avanzamento in terminale durante l'elaborazione
stato: applicata
percorso: normale
idee: []
versione: watson-v0.4
---

## Problema

`watson <frase>` non stampa nulla finché non ha finito: il wrapper esegue `claude -p` con `--output-format json` e cattura tutto l'output in una variabile. Quando Watson delega a un agente (riepilogo, briefing, ricerca) l'attesa può durare decine di secondi e sembra un blocco.

## Comportamento atteso

- Mentre Watson lavora, il terminale mostra una riga per passo: all'avvio, quando parte una skill o un agente, quando legge gli appunti, scrive, chiude l'azione o salva una bozza.
- Le righe sono fisse, firmate come il resoconto, in grigio, su stderr e solo se stderr è un terminale. Con l'output rediretto o in una pipe non cambia nulla: il resoconto su stdout è identico a prima.
- Il resoconto resta l'ultima risposta e non cambia. Le righe di avanzamento non dichiarano azioni eseguite (verbi al presente con i puntini, non al participio), non mostrano commit, indice, diario, percorsi.
- Una riga non si ripete due volte di seguito; i passi interni a un agente non compaiono.
- Con `resoconto: sobrio` in `preferenze.md` le righe diventano emoji e verbo.
- Meccanismo: il wrapper passa a `claude -p` `--output-format stream-json --verbose` e filtra il flusso con il nuovo `scripts/progresso.py`, che lascia su stdout solo l'evento finale. Nessun token in più, nessun hook, nessuna istruzione al modello.

## Esempi

Con la fixture (alpha, beta, luca, anna):

```
$ watson su alpha oggi luca ha sbagliato un rilascio
💭 Watson · Ci penso…
📸 Memento · Preparo la polaroid…
💾 Watson · Chiudo l'azione…
📸 Memento · Polaroid scattata: "Rilascio fallito" · incidente, per luca su alpha

$ watson cosa è successo su alpha questa settimana
💭 Watson · Ci penso…
💌 Lady Whistledown · Raccolgo le voci…
<riepilogo>
💌 Lady Whistledown · da 4 note su alpha
```

Sobrio: `📸 Salvo…`, `💾 Chiudo l'azione…`. Con `watson … | cat`: solo il resoconto.

Casi limite:

- Domanda di chiarimento ("luca rilascio di ieri"): le righe di avanzamento compaiono prima della domanda, non dentro; dopo la risposta ne compaiono di nuove per il nuovo turno.
- Frase composta ("chiudi il todo sulla stima di luca e ricordami di dargli feedback"): più passi `Monica` e `Chiudo l'azione` in sequenza; la dedup toglie solo le ripetizioni immediate.
- Ctrl-C durante l'elaborazione: invariato, il wrapper salva la bozza; le righe già stampate restano a schermo.
- Claude Code non risponde o fallisce: nessuna riga oltre la prima, poi la bozza come oggi; se il flusso non contiene l'evento finale il wrapper ripiega sull'errore letto da stderr, come prima.
- Uno strumento senza riga dedicata (per esempio un comando non previsto) non stampa nulla: meglio silenzio che una frase sbagliata.

## Cosa non deve cambiare

- Principio 4: l'ultima risposta di ogni esecuzione è solo il resoconto, con le frasi fisse di `resoconto.md`. `WATSON.md` e `resoconto.md` non si toccano: il modello non sa nulla dell'avanzamento e non ne scrive.
- Principio 1: nessuna nota persa. Il filtro non può far fallire un comando: righe non JSON passano su stdout come prima e l'errore su stderr è ancora il ripiego.
- I test di routing e `esempi.md` restano validi: l'instradamento delle frasi non cambia, quindi non si aggiungono frasi d'esempio.
- La sessione interattiva (`watson` senza argomenti) e `watson nuovo` restano come sono.

## Piano

File da cambiare:

- `scripts/progresso.py` (nuovo): filtro stdin → stdout/stderr, tabella fissa dei passi (skill, agenti, Read/Glob/Grep, Write/Edit, `azione.sh`, `bozza.sh`, `cerca.sh`, `eevee_applica.sh`).
- `bin/watson`: in `chiedi()` passa a `stream-json --verbose`, collega `progresso.py` con una pipe, `--mostra` solo se stderr è un terminale, `--sobrio` se `preferenze.md` contiene `resoconto: sobrio`. Il resto (sessioni, domande, bozze) è invariato.
- `tests/test_script.sh`: il claude finto continua a stampare una sola riga `result` (il filtro la lascia passare); aggiunte prove sul flusso richiesto e su `progresso.py` (ordine delle righe, sobrio, silenzio fuori da un terminale, stdout uguale all'evento finale).
- `SPEC.md`: paragrafo "Avanzamento" in Interfaccia e una frase nel paragrafo Wrapper dell'architettura.

Non toccati: `WATSON.md`, `resoconto.md`, skill, agenti, hook, `guard.py` (il wrapper gira fuori dalla sessione del modello), `esempi.md`.

Da verificare a mano dopo l'applicazione, perché i test usano un claude finto: `claude -p "ciao" --output-format stream-json --verbose` produce righe JSON con eventi `assistant` (blocchi `tool_use`) e un evento finale `result`, e un `watson <frase>` reale in un terminale mostra le righe.
