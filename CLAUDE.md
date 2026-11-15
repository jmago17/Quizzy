# Quizzy

Juegos de Kaffa (Murdoku, Decoder, Wordle...) como app iOS/iPadOS independiente. Uso personal.
Origen del código: `Shared/Games` de Kaffa (repo `Siftly`, commit `944663d`).

## Compilar

    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
    xcodebuild build -project Quizzy.xcodeproj -scheme Quizzy -configuration Debug \
      -destination 'generic/platform=iOS Simulator' CODE_SIGN_IDENTITY=-

`Quizzy.xcodeproj` está versionado y se genera con XcodeGen (`xcodegen generate` desde `project.yml`).
Regenerar solo al añadir/quitar ficheros o cambiar `project.yml`.

## Identidad en App Store Connect (IMPORTANTE)

- **Bundle ID: `com.maromeapps.quotamini`** — PRESTADO del registro de QuotaMini (proyecto abandonado,
  app 6822259409, equipo `ES2766ARHJ`). En ASC la app sigue llamándose "QuotaMini": "Quizzy" está cogido
  por otra cuenta (409 al renombrar). En el iPhone se ve "Quizzy" (`CFBundleDisplayName`).
- Si Quizzy se publica de verdad: crear app nueva con bundle ID propio y limpiar esto.
- Builds: `CURRENT_PROJECT_VERSION` debe superar el último subido (QuotaMini llegó a 8; Quizzy: 20, 21...).
- TestFlight: grupo interno "Personal" de esa app.

## Subir a TestFlight a mano

Archivar con `-configuration Release -destination 'generic/platform=iOS'` y exportar con
`method=app-store-connect`, `destination=upload`, `-allowProvisioningUpdates`.
- Con la sesión de Apple ID de Xcode funciona SOLO si el llavero está desbloqueado (por SSH da
  `User interaction is not allowed` / "Failed to Use Accounts"; se arregla con un `Run` manual desde Xcode).
- La clave API `AW7HJ2N6AV` (`~/.appstoreconnect`, issuer en `issuer_id`) NO puede crear certificados de
  distribución ("Cloud signing permission error"): su rol no es Admin. Sirve para consultas y TestFlight.

## Bitácora

- 2026-11-14: icono (AppIcon 1024, recortado de un original con esquinas blancas), bundle ID prestado,
  build 20 en TestFlight. Murdoku: tocar casilla ocupada quita al sospechoso; el seleccionado ya colocado
  se mueve al tocar otra casilla. Build 21 archivado pero no subido (llavero bloqueado).
- 2026-11-15 — Anygram lento + flujo de fin de partida:
  - **Lentitud (causa probable, sin medir en dispositivo):** `dragLocation` era `@State` de todo `AnygramGame`;
    cada evento del dedo reconstruía tablero, lista de palabras y fondo, y `puzzle.boardCells` recreaba el
    diccionario en cada acceso. Ahora la rueda es `AnygramWheel` (estado del dedo local), `boardCells` se calcula
    una vez en `init` y las casillas reveladas se calculan como `Set` una vez por render.
  - **"Siguiente" / "Jugar otro" (causa probable):** la hoja de resultado cerraba y a los 250 ms (fijo) mandaba una
    notificación que cambiaba `route` del hub; si la hoja aún se descartaba (más lento en dispositivo, con el confeti
    Metal) la navegación se perdía o dejaba pantalla vacía. Ahora `PZPendingNav` guarda la acción y la lanza en el
    `onDisappear` de la hoja (red de seguridad a los 2 s); "otro del mismo tipo" ya no pasa por `route = nil` (el
    pop+push seguidos) sino que cambia `route` a la partida nueva directamente, y el destino lleva `.id(item.id)`
    para no heredar el estado de la partida anterior. Afecta a todos los juegos con `PZResultSheet` y a Murdoku.
  - **No reproducido en simulador antes del arreglo:** en el simulador el flujo ya funcionaba con 250 ms, así que
    el arreglo se basa en análisis de código, NO en un fallo reproducido. No verificado en iPhone real.
  - Verificación en simulador: `anygram_flow.sh <tag>` (en `Quizzy-20261114/`, fuera del repo) + UI tests en
    `rotador/UITests/AnygramFlowUITests.swift`. Gancho DEBUG: `NR_AUTOWIN=1` termina el primer Anygram al abrirlo.
  - Descartado: el flujo "Siguiente" falla por `puzzle(kind)` nil (en el simulador sí había partida generada).
- 2026-11-15 — Anygram: precalculado (el arranque ya no genera nada de Anygram):
  - **Medido** (simulador, `PZGEN` en el log solo DEBUG): `AnygramPuzzle.generate` en español tarda **~10 s en Release**
    (~24 s Debug); todos los demás juegos <0,4 s. Antes se regeneraba en cada arranque: la tarjeta no aparecía hasta
    terminar y "Jugar otro Anygram" esperaba igual. El inglés es una lista fija (instantáneo).
  - Ahora: (1) el Anygram diario se guarda en `PuzzleSnapshotStore` (`Grid.anygram`; `AnygramPuzzle` es Codable,
    letras como String); (2) `AnygramPrefetch.ensureReady` (en segundo plano, prioridad utility, de uno en uno)
    precalcula el diario de mañana (semilla determinista por fecha → mismo puzzle que se generaría mañana) y deja
    un aleatorio listo para "Jugar otro"/"Generar otro" (`take` lo consume y se rellena); (3) si hoy no hay
    snapshot (primera apertura o día sin precalcular) se usa `AnygramDefault` (`AnygramDefaultData.swift`, JSON
    embebido, id `any-2654206256`) como "el de hoy" mientras no esté completado; si ya está completado y no hay
    snapshot, se genera el real (≈10 s, caso raro).
  - Efecto en medida: instalación limpia → 11 tarjetas a los 4 s sin generar Anygram; en 2º plano quedan guardados
    el snapshot de mañana y el aleatorio; "Jugar otro Anygram" con precalculado: 3,5 s hasta ver el juego nuevo
    (incluye cierre de hoja; sin precalculado eran ~24 s en Debug).
  - Límite: el primer día el "de hoy" es el embebido, no el diario por fecha (a partir de mañana vuelve a coincidir
    entre dispositivos). El generador en sí NO se ha optimizado (cambiaría los puzzles por semilla); 10 s de CPU
    al día en segundo plano. No medido en iPhone real. Otros juegos no necesitan esto (<0,4 s).
  - Al añadir ficheros hay que `xcodegen generate` (el .xcodeproj está versionado): falló el build hasta hacerlo.
- Pendiente: la copia `verify/` (en `Quizzy-20261114/`) difiere en `MurdleGame.swift`; no tiene este arreglo.
