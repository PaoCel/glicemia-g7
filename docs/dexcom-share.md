# Integrazione Dexcom Share

Dexcom non pubblica un SDK per Share: gli endpoint qui sotto sono quelli che usa
l'app Follow, ricavati dal traffico reale e usati da anni dai progetti della
comunità. Possono cambiare senza preavviso, quindi il codice tratta ogni
risposta inattesa come un errore recuperabile e non come un crash.

## Endpoint

Base: `https://<host>/ShareWebServices/Services`

| Regione | Host |
|---|---|
| Europa e resto del mondo | `shareous1.dexcom.com` |
| Stati Uniti | `share2.dexcom.com` |

Sbagliare regione produce lo stesso errore di una password sbagliata, per questo
la scelta è esposta nell'interfaccia invece di essere indovinata.

| Passo | Endpoint | Risposta |
|---|---|---|
| 1 | `POST General/AuthenticatePublisherAccount` | account id, come stringa JSON |
| 2 | `POST General/LoginPublisherAccountById` | session id, come stringa JSON |
| 3 | `POST Publisher/ReadPublisherLatestGlucoseValues?sessionId=…&minutes=1440&maxCount=1` | array di letture |

Il GUID di soli zeri al posto di un id significa credenziali rifiutate.
Il servizio richiede uno `User-Agent` in stile Follow, altrimenti rifiuta.

## Forme che cambiano

`Trend` arriva come numero (`4`) su alcuni deployment e come nome (`"Flat"`) su
altri: il decoder accetta entrambi. I timestamp arrivano come `Date(1615229400000)`
oppure `/Date(1615229400000+0000)/`, quindi vengono estratte le cifre invece di
affidarsi a un formato fisso. Fra `WT` e `ST` si usa `WT`, che è l'ora del
sensore e non quella del telefono che ha caricato il dato.

## Errori e cosa ne fa l'app

| `Code` dal servizio | Interpretazione | Comportamento |
|---|---|---|
| `SessionIdNotFound`, `SessionNotValid` | sessione scaduta | nuovo login, una volta sola, in silenzio |
| `SSO_Authenticate*`, `AccountPasswordInvalid` | credenziali rifiutate | **polling fermato** |
| `MonitoringSessionNotActive`, `MonitorSessionNotFound` | account valido, non pubblica | messaggio di configurazione |
| altro | errore del servizio | backoff |

Il polling si ferma sulle credenziali rifiutate di proposito: ritentare una
password sbagliata blocca l'account Dexcom. Riparte solo quando l'utente salva
nuove credenziali.

## Cadenza

Il G7 pubblica ogni cinque minuti. Dopo una lettura il poll successivo viene
programmato poco dopo quello atteso, non a intervallo fisso, con un minimo di 45
secondi fra due richieste. Sugli errori di rete il backoff è 30s, 60s, 120s,
240s e poi si assesta a cinque minuti.

## Requisiti lato Dexcom

Il server non pubblica nulla se nell'app Dexcom la Condivisione è spenta o se non
c'è almeno un follower invitato. Durante il riscaldamento del sensore non
arrivano valori. Sono i tre casi elencati nella schermata dell'account, perché
sono indistinguibili da un problema dell'app se non vengono spiegati.

## Credenziali

Servono quelle dell'account Dexcom di chi indossa il sensore, non quelle di un
account follower. La password sta nel portachiavi con accessibilità
`afterFirstUnlock`, così un aggiornamento in background può leggerla a telefono
bloccato. Nome utente e regione stanno in `UserDefaults`: non sono segreti.
