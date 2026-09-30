---
name: memento
description: Crea o corregge una nota nel grafo di 221b e la collega a persone e progetti. Usala per ogni fatto, osservazione, decisione, feedback, incidente, meeting, 1:1 o idea che l'utente vuole ricordare, e per correggere una nota già salvata. Esempi - "su alpha oggi luca ha sbagliato un rilascio", "decidiamo di mettere la cache sulle API con anna", "la demo di marco su beta è andata benissimo", "idea per watson - un riepilogo il venerdì", "correggi l'ultima nota - era beta". Non usarla per i compiti da fare o delegati (monica), per aggiungere o modificare persone e progetti (fellowship), né per domande sulle note già scritte.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# Memento: le polaroid per ricordare

1. **Risolvi le entità** con l'indice delle entità nel contesto. Ogni persona e progetto nella frase deve esistere: usa il nome canonico, mai l'alias. Se una persona è in un solo progetto e la frase non ne nomina un altro, il progetto è quello. Se un nome non esiste, non scrivere niente e fai la domanda chiusa secondo il protocollo domanda, con un'opzione per ogni progetto e una per salvare senza collegarla:

   ```
   ? giulia non è ancora nel grafo: chi è?
     1. nuova su alpha (la aggiungo e salvo la nota)
     2. nuova su beta (la aggiungo e salvo la nota)
     3. salva la nota senza collegarla a una persona
   ```

   Con la risposta, fellowship aggiunge il nodo e poi salvi la nota: due azioni, due righe di resoconto.
2. **Scegli il tipo**: nota, decisione, feedback, incidente, meeting, 1:1, idea. Rilascio fallito, bug in produzione, disservizio → incidente. Le preferenze in `preferenze.md` vincono. Un'idea su Watson stesso ha `progetto: "[[watson]]"` e `tipo: idea`.
3. **Scrivi la nota** con Write in `note/AAAA-MM/AAAA-MM-GG_HHMM_slug.md`, dove data, ora e mese sono quelli di `quando` e lo slug è il titolo in minuscolo con trattini. Titolo breve (2–5 parole) che descrive il fatto. Nel corpo le parole dell'utente, ripulite, senza aggiungere fatti.

   ```yaml
   ---
   titolo: Rilascio fallito
   chi: ["[[luca]]"]
   progetto: "[[alpha]]"
   tipo: incidente
   quando: 2026-10-02 15:04
   tags: [rilascio]
   todo: false
   ---

   Luca ha sbagliato un rilascio.
   ```

4. **Correggere una nota** ("era beta", "non era luca ma anna"): trova la nota (di solito l'ultima scritta: vedi il diario nel contesto e `indice/note-AAAA-MM.md`), modificala con Edit; se cambia il mese di `quando`, riscrivila nella cartella giusta. Chiudi con `--tipo aggiorna --dettaglio "nota corretta"`.
5. **Chiudi l'azione**, sempre:

   ```
   ${CLAUDE_PLUGIN_ROOT}/scripts/azione.sh --tipo cattura --scope "alpha/luca" --sommario "incidente sul rilascio" --dettaglio "incidente"
   ```

6. **Resoconto**: `📸 Memento · Polaroid scattata: "<titolo>"` (o `Polaroid ritoccata:` per una correzione), seguito da ` · tipo, per chi su dove` solo se l'hai dedotto.
