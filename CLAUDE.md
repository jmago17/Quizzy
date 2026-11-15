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
- Pendiente: la copia `verify/` (en `Quizzy-20261114/`) difiere en `MurdleGame.swift`; no tiene este arreglo.
- 2026-11-15: rama `diseno/noche-20261115` — especificación `docs/DISENO.md` y su aplicación a tokens,
  portada y ajustes. Escrito SIN compilar ni ejecutar (sin Mac): compilar y mirar antes de fusionar.
