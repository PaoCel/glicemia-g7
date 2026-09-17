# Compatibilità watchOS 8 / Apple Watch Series 3 con Xcode 26.4

Verifica richiesta prima di adottare TestFlight come canale unico di distribuzione.
Aggiornata al 29 agosto 2026.

## Esito: la toolchain supporta ancora Series 3

Nessun blocco a livello di SDK. Le verifiche sono state fatte sulla macchina di
sviluppo, non dedotte dalla documentazione.

| Verifica | Comando | Esito |
|---|---|---|
| Deployment target watchOS 8.0 valido | `SDKSettings.plist` → `ValidDeploymentTargets` | contiene `8.0` … `8.7` |
| Slice armv7k compilabile | `swiftc -target armv7k-apple-watchos8.0` | binario `armv7k` prodotto, `minos 8.0`, `sdk 26.4` |
| Interfacce Swift per armv7k | `WatchOS.sdk/usr/lib/swift` | `armv7k-apple-watchos.swiftinterface` presente per Swift, SwiftUI, WatchKit, ClockKit, Combine, Foundation |
| Concorrenza Swift retrocompatibile | `SwiftConcurrencyMinimumDeploymentTarget` | `8.0` — `async`/`await` utilizzabili |
| Build reale del target Watch | `xcodebuild -target GlicemiaWatch -sdk watchos26.4` | compila per **armv7k e arm64_32** |

### Perché serve `ARCHS` esplicito

`SDKSettings.plist` dichiara `Archs = [arm64, arm64e, arm64_32]`: armv7k **non**
è più nell'insieme di default. Senza intervento Xcode produce un binario che il
Series 3 non può eseguire, e l'errore si manifesta solo al momento
dell'installazione sul dispositivo.

Il target Watch imposta quindi in `project.yml`:

```yaml
"ARCHS[sdk=watchos*]": "armv7k arm64_32"
```

Ogni script di build stampa `lipo -info` sui due eseguibili proprio per rendere
impossibile una regressione silenziosa su questo punto.

## Limite trovato: `actool` richiede il runtime del simulatore watchOS

Compilare l'asset catalog di un target watchOS fallisce se la piattaforma watchOS
non è installata, anche per una build destinata solo a dispositivo reale:

```
error: No available simulator runtimes for platform watchsimulator.
```

Non è aggirabile rimuovendo l'icona: `actool` fallisce comunque. La piattaforma
watchOS (~4 GB di download) è quindi un prerequisito non negoziabile della
macchina di build.

Il runtime deve stare in `/Library/Developer/CoreSimulator` su volume APFS: non
può essere spostato su un disco esterno exFAT.

## App Store Connect accetta armv7k, ma pretende anche arm64

Verificato con un upload reale il 29 agosto 2026. Il primo tentativo, con il
Watch compilato per `armv7k arm64_32`, è stato respinto:

```
Missing architecture. The "Glicemia.app/Watch/Glicemia.app" bundle is missing
the [arm64] architecture(s). The arm64 architecture is required for all
watchOS apps and app extensions.
```

Lo slice rifiutato non era `armv7k`: mancava `arm64`, che App Store Connect
richiede per gli Apple Watch recenti. Le due esigenze convivono senza conflitto,
perché il compilatore vincola da solo il minimo di deployment di ogni slice:

| Slice | `minos` | Dispositivi |
|---|---|---|
| `armv7k` | 8.0 | Series 3 |
| `arm64_32` | 8.0 | Series 4 … Series 9 |
| `arm64` | 26.0 | Apple Watch recenti |

Con `ARCHS[sdk=watchos*] = armv7k arm64_32 arm64` l'upload è andato a buon fine
(build 0.1.0 (2)). Chiedere `arm64-apple-watchos8.0` non è un errore: la
toolchain lo riporta silenziosamente a `watchos26.0` e lascia gli altri due
slice a 8.0.

**Conclusione: TestFlight è utilizzabile come canale di distribuzione verso il
Series 3.** Il fallback dell'installazione diretta da Xcode resta disponibile ma
non è necessario.
