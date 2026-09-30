---
name: fellowship
description: Gestisce i nodi del grafo in 221b - persone, progetti, alias, appartenenze e ruoli. Usala quando l'utente presenta un progetto o una persona, dice chi lavora dove, dà un soprannome, cambia un ruolo, sposta o rimuove qualcuno, o quando conferma di aggiungere una persona sconosciuta. Esempi - "nuovo progetto alpha - il backend dei pagamenti", "in alpha lavorano anna, luca, sara e davide, che tutti chiamano dave", "giulia è entrata in alpha", "luca è il backend lead di alpha", "paolo passa da beta ad alpha". Non usarla per note sui fatti (memento) né per i compiti (monica).
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# Fellowship: la compagnia

1. **Controlla l'indice delle entità** nel contesto: nomi e alias sono unici su tutto il grafo. Un alias già usato da un altro nodo non si aggiunge: chiedi quale dei due intende l'utente.
2. **Nome canonico**: minuscolo, di solito il nome proprio (`davide`). I soprannomi vanno in `alias`. Il file si chiama come il nome.
3. **Persona** in `persone/<nome>.md`:

   ```yaml
   ---
   nome: davide
   alias: [dave]
   progetti: ["[[alpha]]"]
   ruolo: backend
   ---

   Profilo scritto con le parole dell'utente.
   ```

4. **Progetto** in `progetti/<nome>.md`:

   ```yaml
   ---
   nome: alpha
   alias: []
   descrizione: il backend dei pagamenti
   ---
   ```

   Se l'utente nomina persone in un progetto che non esiste ancora, crea prima il progetto, poi le persone, in un'unica azione.
5. **Spostare o rimuovere**: modifica `progetti` della persona. Non si cancellano file: una persona che lascia tutti i progetti resta con `progetti: []`, così le note vecchie restano collegate.
6. **Stato attuale**: la sezione `## Stato attuale` si aggiorna solo se l'utente lo chiede.
7. **Chiudi** con una sola azione per frase: `${CLAUDE_PLUGIN_ROOT}/scripts/azione.sh --tipo cattura --scope "alpha" --sommario "persone di alpha" --dettaglio "persone aggiunte"` (tipo `aggiorna` per modifiche a nodi esistenti).
8. **Resoconto**: `🤝 Fellowship · Benvenuta nella compagnia: <nome> · <progetto>` per ogni nodo aggiunto, `🤝 Fellowship · Cambio di compagnia: <nome> · <da> → <a>` per spostamenti e rimozioni.
