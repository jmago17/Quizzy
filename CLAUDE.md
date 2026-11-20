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

- **Desde 2026-11-15 (noche): app propia "Kuizzy"** (ASC app 6835185679, bundle ID `com.maromeapps.quizzies`,
  equipo `ES2766ARHJ`). "Quizzy" está cogido por otra cuenta. En el iPhone se ve "Quizzy" (`CFBundleDisplayName`).
  Es OTRA app en el dispositivo: el progreso de la instalación vieja no pasa.
- Antes (builds 20–22): bundle ID prestado `com.maromeapps.quotamini` (app QuotaMini 6822259409, abandonada;
  grupo "Personal"). Ya no se usa; queda por limpiar.
- **Xcode Cloud** (producto "Quizzy", repo `jmago17/Quizzy`): workflow "Default" (build en cada push a `main`) e
  "Internal TestFlight Build" (archive → TestFlight interno, solo manual). Xcode Cloud pone su propio número de build;
  subir solo desde ahí (si se sube a mano un número mayor, ajustar el "next build number" del producto).
- TestFlight: grupo interno "Internal" con dos testers (correos fuera del repo).
- La 1.ª archive de Xcode Cloud (run 2) falló en "Preparing build for App Store Connect" porque el proyecto aún tenía
  el bundle ID de QuotaMini (visto en el log de exportación). Con `com.maromeapps.quizzies` la run 4 (2026-11-16,
  lanzada por API: POST `/v1/ciBuildRuns`) subió el build 4 → VALID en TestFlight. En la app también hay un build 22.
  Ojo: Xcode Cloud numera 4, 5… por debajo de ese 22.

## Subir a TestFlight a mano

Archivar con `-configuration Release -destination 'generic/platform=iOS'` y exportar con
`method=app-store-connect`, `destination=upload`, `-allowProvisioningUpdates` (sin `-authenticationKey*`).
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
  → Tras el `Run` manual: **build 22 subido** (commit `5609022`, incluye la revisión del diccionario). Funcionó con solo
  `-allowProvisioningUpdates` (sesión Apple ID de Xcode), SIN los flags `-authenticationKey*` (con ellos fue el fallo de
  "Cloud signing"; no se ha probado si con llavero abierto también fallaría).
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
- 2026-11-16 — Anygram: lag al deslizar que crece con las palabras encontradas (reportado en iPhone):
  - Hipótesis principal (NO medida en dispositivo): cada chip de palabra (`PZDefinableWord`) llamaba a
    `UIReferenceLibraryViewController.dictionaryHasDefinition` (síncrona, lenta) sin caché, y todo `AnygramGame` se
    re-evaluaba en cada letra seleccionada y cada segundo (timer). Coste ∝ palabras encontradas → encaja con el síntoma.
  - Arreglo: caché en `PZDictionary` (también la usan Sopa, Wordle, Quartiles); tablero y tira de palabras pasan a
    `AnygramBoard`/`AnygramFoundStrip` (`Equatable` + `.equatable()`), que no se recalculan con letras ni segundero.
  - Descartado: `PuzzleProgress` (solo escribe al enviar palabra y cada 5 s, no durante el deslizamiento).
  - Verificado: build + UI tests Anygram en simulador (Release). El lag en sí NO se ha reproducido ni medido: confirmar en iPhone.
  - Scripts `anygram_flow*.sh` actualizados al bundle ID nuevo.
- 2026-11-16 — Anygram con "carisma" (prueba solo en este juego, a petición de Josu: "parece una hoja de Excel"):
  fondo `AnygramBackdrop` (resplandores del color del juego sobre el marino), casillas `AnygramTile` con volumen
  (degradado, brillo arriba, sombra; al descubrirse se llenan de rosa y la letra entra con rebote en ola por fila/columna),
  rueda con disco radial y fichas `AnygramWheelLetter` en relieve. **Rompe a propósito "sin sombras" de `docs/DISENO.md`**:
  si gusta, extender al resto y actualizar la especificación. Capturas en `Quizzy-20261114/shots-anygram/carisma/`
  (fuera del repo). Gancho DEBUG `NR_ANYFOUND=n` (con `NR_GAME=anygram`) descubre n palabras para capturas.
  Sin ver en iPhone real ni comprobar fluidez de las sombras con muchas casillas.
- 2026-11-17 — Diseño con volumen en toda la app + celebración Metal (versión 0.1.1, para que TestFlight la muestre arriba):
  - Base en `PuzzleDesignSystem.swift` (sección "Volumen"): `PZGameBackdrop(color:)` (resplandor del color del juego) y
    `.pzVolume(...)` (ficha con degradado, brillo arriba y sombra). Sustituye a "sin sombras" de `docs/DISENO.md` en los
    tableros (portada y tarjetas siguen planas). Anygram pasa a TURQUESA (`PZ.anygram` 3FD3C6) a petición de Josu.
  - Aplicado: Wordle, Quartiles, Sopa (versión ligera: sin sombra por casilla), Autodefinido/Mini (papel claro intacto;
    volumen en teclado y marco), Laberinto (marco, bola de jugador, meta con halo), Hashtag, Murdle (casillas de la
    rejilla lógica), Decoder (solo fondo: ya tenía relieve propio). Trivia/Números retocados pero NO se ofrecen.
  - **Murdoku, con cuidado:** solo fondo, una sombra bajo el tablero, bisel fino en cada casilla y ficha de sospechoso
    seleccionada con volumen. Sin tocar lógica, tamaños, colores de estancias ni retratos. Revisado en captura.
  - Celebración (`PZResultSheet.swift` + `PZShaders.metal`, `ShaderLibrary`): insignia con volumen y brillo metálico
    (`pzShine`), onda expansiva sobre la hoja (`pzShockwave`, no verificable en capturas fijas), partículas del color
    del juego + oro + blanco, mezcla aditiva y escamas metálicas que destellan. **Bug viejo arreglado:** la simulación
    iba en píxeles sin escala → en @3x el confeti salía a 1/3 de tamaño y velocidad ("polvo").
  - Hecho con 3 subagentes en worktrees (ficheros disjuntos) + Murdoku a mano. Verificado: build, UI tests Anygram
    (Release), capturas de los 11 juegos y de la celebración. Sin ver en iPhone: fluidez de sombras (Hashtag, Sopa).
- 2026-11-18 — Quartiles → **Trocitos** (es) / Snippets (en); las palabras de 4 fichas son "joyas". Motivo: nombre y
  juego venían de Apple News+. El enum interno sigue siendo `.quartiles` (ids, progreso y semillas no cambian).
  - **Bug de victoria arreglado:** ganaba al encontrar las 5 joyas sin mirar puntos (5 × 18 = 90 → "conseguido con 98"
    fue suerte). Ahora `isComplete` = 5 joyas Y `score >= goalScore`; `goalScore = min(100, maxScore)` para no pedir
    algo imposible si un tablero no da 100. Tras la 5ª joya sin llegar, aviso "te faltan X puntos". Sin test unitario.
  - Celebración: el confeti dentro de la hoja pasa a **fuegos artificiales a pantalla completa** (`PZFireworks.launch`):
    UIWindow propia transparente, sin toques (`hitTest` → nil), nivel `.alert + 1`, con MTKView; ~10 cohetes con estela
    que estallan en esfera, anillo o sauce dorado; se quita sola a los 4,6 s. También en Murdoku (`MurdokuClosedSheet`).
    `PZCelebrationView` eliminado. Verificado grabando vídeo del simulador (`simctl io recordVideo` + extraer fotogramas
    con AVAssetImageGenerator; las capturas sueltas engañan porque el simulador renderiza lento). Sin ver en iPhone.
  - Mismo motivo (marcas de NYT y de G.T. Karber): Wordle → **Palabro**, Murdle → **Elemental** (solo el nombre
    visible y el texto de compartir; el enum sigue `.wordle`/`.murdle`). Josu descartó antes "Cinco"/"Coartada" (sonaban mal).
  - Murdoku → **Sabueso** (en: Sleuth), por la posible marca de unos libros de puzles (sin comprobar). Tipos y
    ficheros internos siguen llamándose Murdoku.
- 2026-11-20 — Anygram: **cada 3 palabras extra se revela gratis una letra** (sin penalización; `AnygramGame.extrasPerFreeLetter`).
  Se concede solo al llegar a 3, 6, 9… extras en `submit()`; la casilla se guarda en `fill` como las pistas pagadas, así que
  al reabrir no se regala otra vez. Contador `· n/3` junto a OTRAS y línea nueva en las reglas. Verificado: build iOS. Sin
  probar jugando (ni simulador ni iPhone).
- 2026-11-20 — **App de Apple Watch** (target `QuizzyWatch`, bundle `com.maromeapps.quizzies.watchkitapp`, watchOS 26.0,
  embebida en la de iOS → llega por el mismo TestFlight). Juegos: Palabro, Anygram, Trocitos, Laberinto y Decoder.
  - **Modelos compartidos, no copiados:** los ficheros Foundation puros pasan a `#if os(iOS) || os(watchOS)` y entran en
    el target del reloj por ruta (lista en `project.yml`). `WordlePuzzle`/`LetterResult`/`WordleOutcome` y `MazePuzzle` se
    movieron TAL CUAL a `WordleModel.swift` y `MazeModel.swift` (estaban en ficheros de vista con UIKit); se añade
    `WordlePuzzle.evaluate`. Solo 5 JSON van al reloj (sin `puzzles`, `trivia_questions`, `natural_clues`).
  - Vistas en `QuizzyWatch/` (todas nuevas). Diarios con las MISMAS semillas que el iPhone (`PuzzleSeed`); Anygram y
    Trocitos se generan en segundo plano y se congelan en `PuzzleSnapshotStore`, como en iOS. Laberinto del reloj 8×10
    con id `w-m-gen-…` (el del iPhone es 12×16). **Progreso local al reloj: NO se sincroniza con el iPhone.**
  - Palabro: entrada de texto del sistema (teclado/garabato/dictado), normaliza tildes y conserva la Ñ. Anygram: rueda
    para deslizar + tablero en Canvas (tocar = tablero grande con palabras); misma letra gratis cada 3 extras
    (`AnygramRules.extrasPerFreeLetter`, duplicado del valor iOS). Laberinto: deslizar = corre hasta el cruce.
  - **Decoder:** juego de Kaffa (`DecoderCore.swift`, idéntico al de Siftly). La vista de Kaffa (`Watch/WatchDecoderView.swift`,
    un "aparato" con antenas, 7 segmentos y pomo) NO se trajo: Josu pidió quitar el diseño de trasto físico. Vista nueva:
    7 filas limpias, la Corona elige color, tocar casilla/muestra = colocar, ✓ = probar, bombilla = pista de la última fila.
  - Gancho DEBUG: `QW_GAME=wordle|anygram|quartiles|maze|decoder` abre ese juego al lanzar (capturas sin tocar).
  - Verificado: build iOS con el Watch embebido y build watchOS (simulador); capturas en un Watch Series 12 42 mm temporal
    (ya borrado) de portada y los 5 juegos, con 3 ajustes de maquetación tras verlas. **NO verificado:** jugar tocando
    (el simulador es headless), Corona real, tiempos de generación de Anygram en un reloj de verdad (en el simulador
    corre con la CPU del Mac), y la firma/archive en Xcode Cloud con el App ID nuevo del reloj (puede pedir
    registrarlo en el portal la primera vez).
  - TestFlight: la 1.ª archive con el reloj (run 16) falló al exportar: `Automatic signing cannot register bundle
    identifier "com.maromeapps.quizzies.watchkitapp"` (Xcode Cloud no da de alta App IDs). Registrado por API con la clave
    `AW7HJ2N6AV` (`asc bundle-ids create`, id `7P838AFK7A`; esa clave SÍ puede crear bundle IDs aunque no certificados).
    Run 17 → **build 17 VALID en TestFlight** (2026-11-20). Recordatorio: el workflow de TestFlight es manual; el push
    solo lanza "Default" (compila, no sube). Lanzar con `asc xcode-cloud run --app 6835185679 --workflow "Internal
    TestFlight Build" --branch main`.
- Pendiente: "next build number" de Xcode Cloud a 23 — no está en la API pública; hacerlo en la web de ASC.
- Pendiente: la copia `verify/` (en `Quizzy-20261114/`) difiere en `MurdleGame.swift`; no tiene este arreglo.
- 2026-11-15: rama `diseno/noche-20261115` — especificación `docs/DISENO.md` y su aplicación a tokens,
  portada y ajustes. Compilado en el Mac (Xcode 27.3, simulador): BUILD SUCCEEDED; tests Decoder y
  GamesLanguage PASS. Capturas de portada (iPhone/iPad) y de seis juegos revisadas. Arreglo tras verlas:
  el resalte de cursor/palabra del Autodefinido va sobre el papel claro (antes dejaba la casilla oscura).
  Sin probar tocando; sin mirar ajustes, hojas de resultado, Decoder, Anygram, Hashtag ni Murdle.
