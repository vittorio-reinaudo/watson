# Esempi di instradamento

Frasi generiche con l'intenzione attesa, verificate in dry-run da `scripts/test_routing.sh` sulla fixture (progetti alpha e beta) dopo ogni modifica a Watson. Gli esempi personali, con nomi reali, stanno in `esempi-personali.md` nel repository 221b, nello stesso formato.

- `famiglia`: catturare, interrogare, aggiornare, mantenere.
- `componente`: memento, monica, fellowship, delorean, sherlock, whistledown, q, wall-e, eevee, watson (risponde l'orchestratore).
- `tipo`: tipo atteso della nota o del todo; `—` se non conta.
- `ambigua`: `sì` se Watson deve chiedere un chiarimento.
- Frasi composte: un valore per azione, separati da ` + `, nell'ordine. Più valori accettabili: separati da `/`.

| frase | famiglia | componente | tipo | ambigua |
| --- | --- | --- | --- | --- |
| su alpha oggi luca ha sbagliato un rilascio | catturare | memento | incidente | no |
| su beta la demo di marco è andata benissimo | catturare | memento | — | no |
| decidiamo con anna di mettere la cache sulle API di alpha | catturare | memento | decisione | no |
| oggi 1:1 con elena, vuole crescere sul backend | catturare | memento | 1:1 | no |
| idea per watson: un riepilogo il venerdì | catturare | memento | idea | no |
| ho assegnato a dave il fix del login entro venerdì | catturare | monica | todo | no |
| ricordami di rivedere la roadmap lunedì | catturare | monica | todo | no |
| todo: chiamare elena per la stima | catturare | monica | todo | no |
| nuovo progetto gamma: la piattaforma dati | catturare/aggiornare | fellowship | — | no |
| luca ha sbagliato il rilascio, gli ho chiesto di sistemarlo entro venerdì | catturare + catturare | memento + monica | incidente + todo | no |
| fatto la stima di luca | aggiornare | monica | — | no |
| chiudi il todo sulla stima di luca e ricordami di dargli feedback sul rilascio | aggiornare + catturare | monica + monica | — | no |
| sara passa da alpha a beta | aggiornare | fellowship | — | no |
| correggi l'ultima nota: era beta | aggiornare | memento | — | no |
| annulla | aggiornare | delorean | — | no |
| quella decisione con luca sul caching | interrogare | sherlock | — | no |
| cerca: rilascio fallito | interrogare | sherlock | — | no |
| cosa è successo su alpha questa settimana | interrogare | whistledown | — | no |
| prepara il mio 1:1 con marco | interrogare | q | — | no |
| quali todo ho aperti? | interrogare | monica | — | no |
| con chi non faccio un 1:1 da tre settimane? | interrogare | watson | — | no |
| riordina l'inbox | mantenere | wall-e | — | no |
| vorrei un riepilogo automatico ogni venerdì | mantenere | eevee | — | no |
| cambia la frase del resoconto per i todo | mantenere | eevee | — | no |
| annulla l'ultima modifica a watson | aggiornare/mantenere | delorean/eevee | — | no |
| luca rilascio di ieri | catturare/interrogare | memento/sherlock | — | sì |
