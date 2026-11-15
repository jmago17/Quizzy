# Quizzy

Juegos de Kaffa (Murdoku, Decoder, Wordle...) como app iOS/iPadOS independiente. Uso personal.
Origen del código: `Shared/Games` de Kaffa (repo `Siftly`, commit `944663d`).

## Diseño

Diseño «Noche»: una sola apariencia, oscura, en la línea de Murdoku. Especificación en `docs/DISENO.md`.
Tokens en `Quizzy/Games/PuzzleDesignSystem.swift` (`PZColor`, `PZFont`, `PZRadius`) y fondo/cabecera en
`Quizzy/Support/HostDesign.swift`. No reintroducir serif, filetes de color ni colores de sistema.

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
- 2026-11-15 (tarde): `main` = diseño «Noche» (`diseno/noche-20261115`) + fix Anygram, sin conflictos. Build subido a 22;
  archivo OK pero export FALLA (llavero bloqueado: "Cloud signing permission error"); falta `Run` manual desde Xcode y repetir `ship.sh`.
- 2026-11-15 (tarde) — revisión del diccionario y de los generadores (todo verificado con el harness salvo lo dicho):
  - **Ñ:** los JSON no tenían NINGUNA Ñ (SEÑOR era SENOR; el teclado tenía tecla Ñ inútil). Restaurada con frecuencias
    de subtítulos (`Tools/lexicon/enie.py`); sustitución en el sitio. El relleno de la sopa en español lleva Ñ.
  - **Crucigramas no deterministas en español:** `PuzzleGenerator.swift` (autodefinido) y `MiniCrossword.swift`
    recorrían Dictionary/Set sin ordenar (solo el inglés ordenaba): misma semilla → otro tablero en otro proceso.
    Ordenado. Nuevo modo `--mode fingerprint` (dos procesos); comprobado que FALLA con el código viejo.
  - **Anygram:** el léxico (bases jugables) se recalculaba en cada puzzle (29 M comparaciones, ~10 s). Ahora
    `AnygramLexicon.shared` (0,13 s una vez). Comprobado IGUAL al viejo en 8 semillas con los datos de entonces.
    Además tope de búsqueda determinista `searchStepLimit = 20_000`: máx. 7 s → 0,9 s (Mac, -O, 100 semillas);
    cambia el tablero del 27 % de semillas, calidad igual (10,74 vs 10,84 palabras de media).
  - **"Jugar otro" seguía pareciendo no hacer nada** cuando no había precalculado: la partida terminada seguía en
    pantalla sin señal mientras se generaba. El UI test daba FALSO POSITIVO (esperaba un texto que también está en la
    partida vieja); ahora exige que cambien las letras de la rueda (`accessibilityValue` de la rueda). Añadido aviso
    "Preparando otro …" (`preparingKind` en `PuzzlesScreen`). Release en simulador: 3,0 s sin precalculado, 2,9 s con
    él, desde el toque (incluye cierre de hoja). Debug: 13–21 s (no representativo).
  - **Escalera de palabras:** eliminada (ya no se ofrecía; era código muerto). Queda el `case .ladder` para decodificar.
  - **Listas:** `common_words` sin 162 nombres propios/inglés/regionalismos; nuevo `answer_words.json` (sin
    conjugaciones) para soluciones de Quartiles y Sopa; Wordle: 162 respuestas sustituidas en el sitio (conjugaciones,
    nombres, inglés, palabrotas) + ÑANDU; el Wordle de hoy y los 3 siguientes no cambian. Pistas: 146 reescritas a mano,
    MARICA y 7 rarezas fuera, 86 palabras cortas nuevas. Hashtag: 4 → 124 plantillas.
  - **Autodefinido:** con el banco nuevo 1/40 semillas no llegaba a la densidad mínima y caía al fijo de puzzles.json
    (hipótesis "es el orden fijo" DESCARTADA: con solo el orden fijo pasa; con solo las pistas nuevas falla). Ahora
    reintenta con semillas derivadas (el intento 0 es el de siempre).
  - Efecto en partidas empezadas: sopa/quartiles/crucigramas/anygram de hoy están en snapshot → no cambian. Hashtag
    de hoy SÍ puede cambiar (no tiene snapshot y cambió el número de plantillas).
  - Fuentes y límites: `Tools/lexicon/README.md`. Quedan conjugaciones que el etiquetador no ve (RUEGA, COMPRENDIO) y
    ~1.400 pistas sin revisar una a una. Nada de esto probado en iPhone real.
- Pendiente: la copia `verify/` (en `Quizzy-20261114/`) difiere en `MurdleGame.swift`; no tiene este arreglo.
- 2026-11-15: rama `diseno/noche-20261115` — especificación `docs/DISENO.md` y su aplicación a tokens,
  portada y ajustes. Compilado en el Mac (Xcode 27.3, simulador): BUILD SUCCEEDED; tests Decoder y
  GamesLanguage PASS. Capturas de portada (iPhone/iPad) y de seis juegos revisadas. Arreglo tras verlas:
  el resalte de cursor/palabra del Autodefinido va sobre el papel claro (antes dejaba la casilla oscura).
  Sin probar tocando; sin mirar ajustes, hojas de resultado, Decoder, Anygram, Hashtag ni Murdle.
