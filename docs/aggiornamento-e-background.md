# Quanto è fresco il dato, e perché

Il vincolo di questo progetto non è la sorgente dei dati: è quanto spesso i due
sistemi operativi ci lasciano girare. Questo documento dice cosa è raggiungibile
e cosa no, così nessuna milestone futura viene progettata su un presupposto falso.

## Il Watch non dipende dall'app iPhone

La prima versione instradava tutto attraverso l'iPhone:

```
Dexcom ──→ app iPhone ──WatchConnectivity──→ Watch
```

Sbagliato. Con quella catena, ogni volta che iOS sospende l'app iPhone il polso
resta fermo, e l'utente deve tirare fuori il telefono e aprire l'app — a quel
punto tanto vale aprire direttamente Dexcom.

L'accesso di rete del Watch è instradato dal sistema operativo attraverso
l'iPhone accoppiato. **Non richiede che la nostra app iPhone sia sveglia**,
richiede solo che il telefono sia in portata. Quindi il Watch interroga Dexcom
da sé:

```
Dexcom ──→ Watch          (percorso principale)
Dexcom ──→ app iPhone ──→ Watch   (quando l'app iPhone è comunque attiva)
```

Le credenziali arrivano al Watch via `transferUserInfo`, che è accodato e
consegnato anche se il Watch sta dormendo, e finiscono nel portachiavi
dell'orologio.

Chi arriva secondo con la stessa lettura non azzera l'età: vince il timestamp
più recente, non l'ordine di arrivo.

## Cosa è realmente ottenibile

| Situazione | Freschezza |
|---|---|
| App aperta sul Watch | immediata, interrogazione diretta |
| Alzata del polso sull'app | immediata |
| App iPhone in primo piano | ogni 5 minuti |
| Complicazione sul quadrante | 15-30 minuti, **non garantiti** |
| iPhone fuori portata | ultimo valore, marcato come vecchio |

Sotto i 4 minuti di età il Watch non interroga la rete: su un Series 3 il costo
in batteria supera il beneficio, e il sensore comunque non ha pubblicato nulla di
nuovo.

## Perché la complicazione non può essere viva

Il sensore pubblica 288 valori al giorno. watchOS concede circa 50 aggiornamenti
prioritari di complicazione al giorno via `transferCurrentComplicationUserInfo`,
più un budget di risvegli in background che si restringe se l'app non viene
usata. Nessuna architettura aggira questo: è una scelta di watchOS sulla durata
della batteria.

Per questo la complicazione è arrivata insieme al background e non dopo: la sua
presenza sul quadrante **aumenta** il budget di risvegli concesso all'app. È il
meccanismo, non la decorazione.

## Il vicolo del calendario

Idea: scrivere il valore come evento di calendario e lasciare che sia la
complicazione Calendario, nativa, a mostrarlo — aggirando il tetto dei 50
aggiornamenti.

Aggira quel tetto davvero. Non aggira l'altro: su watchOS la scrittura degli
eventi è vietata dal sistema, verificato nell'SDK —

```
- (BOOL)saveEvent:(EKEvent *)event span:(EKSpan)span error:(NSError **)error
    NS_AVAILABLE(10_14, 4_0) __WATCHOS_PROHIBITED;
```

`saveEvent`, `removeEvent` e `saveCalendar` sono tutti `__WATCHOS_PROHIBITED`.
Gli eventi li può scrivere solo l'iPhone, quindi il quadrante resta fresco quanto
l'ultima esecuzione in background dell'app iPhone: senza qualcosa che la svegli,
non si guadagna niente.

Ha senso solo in coppia con un servizio esterno che svegli l'iPhone di frequente.

## Il ruolo di un eventuale server

Un servizio che interroga Dexcom e manda una push all'iPhone sposterebbe la
freschezza sull'iPhone da ~20 minuti a ~5. Sul Watch cambierebbe poco da solo,
ma renderebbe utile il vicolo del calendario.

Da mettere in conto: le credenziali Dexcom finirebbero su un server invece che
solo nel portachiavi dei dispositivi, e le push silenziose smettono di arrivare
se l'utente chiude l'app con lo swipe. Prima di scrivere codice conviene
guardare Nightscout, che è esattamente questo ed è già esistente.

## Allarmi

Fuori ambito, per decisione di progetto. Gli allarmi restano all'app Dexcom, che
è certificata per farlo. Questa app mostra un numero; non avvisa, non sveglia e
non deve essere usata come se lo facesse.
