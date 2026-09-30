---
name: delorean
description: Annulla un'azione di Watson in 221b (una nota, un todo, una correzione, una preferenza appresa, persino un altro annullamento) o consulta lo storico delle azioni. Usala quando l'utente vuole tornare indietro. Esempi - "annulla", "annulla l'ultima nota su luca", "no, togli quel todo che hai appena creato", "annulla l'annullamento", "cosa hai fatto oggi?". Non usarla per correggere il contenuto di una nota (memento) né per annullare una modifica a Watson stesso (quella passa da eevee_applica.sh --annulla).
allowed-tools: Read, Grep, Glob, Bash
---

# DeLorean: Grande Giove!

## Annullare

1. **Trova l'azione.** "annulla" da solo è l'ultima azione: usa `--ultima`. Altrimenti cerca l'id nelle ultime righe del diario (nel contesto, o in `diario-di-bordo/` della settimana corrente: una riga per azione, `id · tipo · dettaglio · scope · "frase"`) e scegli quella che corrisponde alla descrizione. Se due azioni corrispondono, domanda chiusa con le opzioni.
2. **Annulla** con un solo comando:

   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/delorean.sh --ultima
   ${CLAUDE_PLUGIN_ROOT}/scripts/delorean.sh a-20261002-1504
   ```

   Lo script fa il revert e lo chiude come azione `annulla`: non serve `azione.sh`, e non devi toccare i file.
3. **Esiti.**
   - Uscita 0: l'azione è annullata.
   - Uscita 2, conflitto: azioni successive hanno toccato gli stessi file. Non procedere da solo: mostra i file e fai la domanda chiusa, per esempio `? L'azione è stata modificata dopo da altre azioni: cosa faccio?` con le opzioni `1. annulla prima le azioni successive su quei file` e `2. lascia tutto com'è`.
   - Uscita 1 con "lascerebbe il grafo incoerente": spiega in una riga cosa si romperebbe (per esempio una nota che cita la persona che vorresti togliere) e proponi cosa fare prima.
4. **Resoconto**: `⚡ DeLorean · Grande Giove! Annullata "<titolo della nota o dell'azione>"`. Se era una preferenza appresa, aggiungi ` · preferenza tolta`.

## Consultare lo storico

"cosa hai fatto oggi?", "le ultime azioni": leggi `diario-di-bordo/` della settimana corrente e rispondi con una riga per azione (ora, cosa, frase). Non scrive nulla.
