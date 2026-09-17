# Glicemia

Lettura glicemica sul polso. iPhone come unica sorgente dati, Apple Watch come
schermo di consultazione.

Dispositivo di riferimento per il layout: **Apple Watch Series 3, watchOS 8.x**.
Il resto viene dopo.

## Stato

| Milestone | Contenuto | Stato |
|---|---|---|
| 0 | Build iPhone + Watch | fatta: `armv7k arm64_32 arm64` |
| 1 | WatchConnectivity + `MockGlucoseSource` | verificata su Series 3 reale |
| 1.5 | Prima passata UI/UX sul dispositivo reale | in attesa del riscontro della tester |
| 2 | Dexcom Share reale | verificata su account e sensore reali |
| 2.5 | Prima build TestFlight per la tester | fatta, verificata sul Series 3 |
| 3 | Watch client autonomo, background refresh, complicazione ClockKit | implementata, da provare |
| 4 | ClockKit | assorbita nella 3: è il meccanismo del background, non un extra |

## App Store Connect

| | |
|---|---|
| App | Glicemia G7 — ID 6806663984 |
| Bundle ID | `com.paolocelestini.glicemia` (Watch: `.watchkitapp`) |
| Gruppo di test | "Tester Series 3", interno, distribuzione automatica attiva |

La distribuzione automatica significa che ogni build caricata da qui in avanti
raggiunge i tester del gruppo senza passaggi manuali su App Store Connect.

## Struttura

```
Sources/Shared/   modello, formattazione, protocollo WatchConnectivity, componenti SwiftUI comuni
Sources/iOS/      app iPhone: sorgente dati + mirroring verso il Watch
Sources/Shared/Dexcom/  client Dexcom Share, polling, credenziali — compilato per iPhone e Watch
Sources/Watch/    app Watch: sola lettura, nessuna rete
scripts/          build, archive, upload TestFlight, gestione versioni
docs/             verifiche di compatibilità
```

Il progetto Xcode è generato: `project.yml` è la fonte di verità, `Glicemia.xcodeproj`
è un artefatto. Dopo ogni modifica ai file sorgente o alla configurazione:

```bash
xcodegen generate
```

## Screenshot

L'app si prova sul Series 3 reale via TestFlight: il simulatore watchOS 26 non ha
un modello da 38 mm e la build richiede il runtime watchOS installato. Nel repo
non ci sono screenshot del Watch; l'interfaccia è descritta nell'ultima sezione.

## Comandi

```bash
./scripts/build.sh
```

Build Debug di entrambi i target per dispositivo reale, senza firma. Stampa le
architetture prodotte: il Watch **deve** contenere `armv7k` (Series 3) oltre a
`arm64_32`.

```bash
swift test
```

I test della logica condivisa girano sul Mac come pacchetto SwiftPM, senza
simulatore: qualche secondo invece di diversi minuti e alcuni gigabyte. Coprono
il parsing delle risposte Dexcom, le soglie di freschezza e il protocollo verso
il Watch — cioè i punti dove un errore non fa crashare l'app ma le fa mostrare un
numero sbagliato.

```bash
./scripts/version.sh bump
```

Incrementa il build number. Da eseguire prima di ogni archive destinato a TestFlight.

```bash
./scripts/archive.sh
```

Archive Release firmato per App Store e export dell'`.ipa`.

```bash
./scripts/upload.sh
```

Upload su App Store Connect. Richiede una API key App Store Connect:

```bash
export ASC_KEY_PATH=/percorso/AuthKey_XXXXXXXX.p8
export ASC_KEY_ID=XXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## Vincoli di progetto

- Il volume del progetto è exFAT. Gli artefatti di build vanno in
  `~/Library/Developer/Glicemia` perché firma e `.xcarchive` richiedono permessi
  POSIX ed extended attributes che exFAT non conserva.
- La freschezza del dato è limitata dai sistemi operativi, non dalla sorgente. Vedi [docs/aggiornamento-e-background.md](docs/aggiornamento-e-background.md).
- Dexcom Share non ha un SDK pubblico. Vedi [docs/dexcom-share.md](docs/dexcom-share.md).
- Series 3 richiede lo slice `armv7k`, che non è più nelle architetture di default
  del SDK watchOS 26. Vedi [docs/compatibilita-watchos8.md](docs/compatibilita-watchos8.md).

## Principio dell'interfaccia Watch

Un secondo di sguardo deve bastare per leggere valore, direzione e quanto è
recente il dato. Il numero domina, la freccia è immediatamente riconoscibile,
l'età è leggibile ma secondaria. Tutto ciò che è tecnico (sorgente, stato del
collegamento, errori) sta nella seconda pagina.

Nessuno stato è comunicato dal solo colore: lo schermo del Series 3 è piccolo e
spesso guardato in condizioni di luce cattive. Ogni stato porta anche un glifo,
una parola o un cambio di peso tipografico.
