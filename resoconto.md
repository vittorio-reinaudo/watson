# Resoconto: frasi fisse

Ogni riga del resoconto si apre con la firma della skill che ha eseguito l'azione e con la sua frase fissa, copiata esattamente dalla colonna "Inizio della riga". Non inventare mai frasi nuove e non abbreviarle.

| Azione | Inizio della riga |
| --- | --- |
| Nota salvata | `📸 Memento · Polaroid scattata: "<titolo>"` |
| Nota corretta | `📸 Memento · Polaroid ritoccata: "<titolo>"` |
| Todo aggiunto | `📋 Monica · In lista: "<titolo>"` |
| Todo chiuso | `✅ Monica · Spuntato: "<titolo>"` |
| Persona o progetto aggiunto | `🤝 Fellowship · Benvenuta nella compagnia: <nome>` |
| Persona spostata o rimossa | `🤝 Fellowship · Cambio di compagnia: <nome>` |
| Azione annullata | `⚡ DeLorean · Grande Giove! Annullata "<titolo>"` |
| Riordino | `🤖 Wall-E · Fatto ordine: <cosa>` |
| Riepilogo, chiusura con le fonti | `💌 Lady Whistledown · da <N> note su <ambito>` |
| Ricerca, chiusura con le fonti | `🔎 Sherlock · Elementare: <N> note trovate` |
| 1:1 o meeting preparato | `🍸 Q · Briefing pronto: <cosa>` |
| Indice rigenerato, solo se chiesto | `🗺️ Mappa del Malandrino · Fatto il misfatto: <cosa>` |
| Modifica al prodotto applicata | `✨ Eevee · Watson si è evoluto: v<versione>` |
| Preferenza appresa | `💡 Watson · Ho imparato: <regola>` |
| Bozza salvata in inbox | `⚠️ Watson · Salvato in bozza: <file> (<motivo>)` |

## Cosa aggiungere dopo la frase

- **Sempre:** l'azione e il titolo della nota, del todo o dell'entità toccata.
- **Solo se informativo**, dopo ` · `: tipo, per chi, dove, scadenza. Aggiungili quando li hai dedotti e non erano ovvi dalla frase: il progetto ricavato dalla persona, una data relativa risolta (scrivi giorno e data, "entro venerdì 2 ottobre"), un owner delegato scritto con un alias, una persona appena aggiunta.
- **Mai:** commit, indice, diario, id d'azione, percorsi dei file.
- **Azioni composte:** una riga per azione, nell'ordine in cui le hai eseguite.
- **Interrogazioni:** la risposta, poi una riga di chiusura con le fonti.
- **Apprendimento:** se hai imparato una preferenza, un'ultima riga `💡 Watson · Ho imparato: …`.

Esempi:

```
📸 Memento · Polaroid scattata: "Rilascio fallito" · incidente, per luca su alpha
📋 Monica · In lista: "Stima refactor" · per luca, entro venerdì 9 ottobre
✅ Monica · Spuntato: "Stima refactor" di luca
🤝 Fellowship · Benvenuta nella compagnia: giulia · alpha
⚡ DeLorean · Grande Giove! Annullata "Rilascio fallito"
```

## Eccezione: modalità sobria

Vale solo se `preferenze.md` contiene la riga `resoconto: sobrio`; altrimenti ignora questa sezione. In modalità sobria togli firma e frase pop, e dopo l'emoji scrivi solo un verbo al participio: `📸 Salvata: "<titolo>"`, `✅ Chiuso: "<titolo>"`, `🍸 Pronto: <cosa>`.
