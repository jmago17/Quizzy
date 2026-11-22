#if os(iOS)
//
//  PZRules.swift — News Raider
//  Per-game rules, shown on first launch of each game and from the toolbar.
//

import SwiftUI

extension PuzzleKind {
    var rules: [String] {
        switch self {
        case .quartiles:
            return [AppLanguage.text("Cada ficha es un fragmento de palabra. Combina de 1 a 4 fichas para formar palabras válidas.", "Each tile is a word fragment. Combine 1 to 4 tiles to form valid words."),
                    AppLanguage.text("Hay 5 palabras que usan exactamente 4 fichas: son las joyas. Valen 8 puntos más 10 de bonus.", "There are 5 words using exactly 4 tiles: the gems. Each earns 8 points plus a 10-point bonus."),
                    AppLanguage.text("Las combinaciones más cortas puntúan 1, 2 o 4 puntos según usen 1, 2 o 3 fichas.", "Shorter combinations score 1, 2 or 4 points when using 1, 2 or 3 tiles."),
                    AppLanguage.text("Ayuda de color: al encontrar palabras que no sean joya se colorean dos fichas de una misma joya que van seguidas en la palabra (el principio o el final, no las cuatro). Cada ayuda cuesta más palabras que la anterior —3, 4, 5, 6 y 7— y hay como mucho una por joya.", "Colour hint: finding non-gem words colours two tiles of the same gem that sit next to each other in the word (its start or its end, not all four). Each hint costs more words than the last — 3, 4, 5, 6 and 7 — and there is at most one per gem."),
                    AppLanguage.text("Para ganar hay que encontrar las 5 joyas y llegar a 100 puntos.", "To win, find all 5 gems and reach 100 points.")]
        case .wordsearch:
            return [AppLanguage.text("Arrastra el dedo sobre la rejilla para unir letras contiguas.", "Drag across the grid to connect adjacent letters."),
                    AppLanguage.text("Las palabras pueden ir en horizontal, vertical o diagonal, y también al revés.", "Words can run horizontally, vertically or diagonally, in either direction."),
                    AppLanguage.text("Al acertar, la palabra queda marcada en la lista inferior.", "Found words are marked in the list below."),
                    AppLanguage.text("Encuentra todas las palabras para completar la sopa.", "Find every word to complete the word search.")]
        case .crossword:
            return [AppLanguage.text("Toca una casilla para seleccionar su definición.", "Tap a square to select its clue."),
                    AppLanguage.text("Escribe la respuesta con el teclado; al completarla se salta a la siguiente.", "Type the answer using the keyboard; completing it moves to the next clue."),
                    AppLanguage.text("Usa las flechas de la barra para moverte entre definiciones.", "Use the arrows to move between clues."),
                    AppLanguage.text("Las palabras se cruzan: una letra acertada ayuda en la definición perpendicular.", "Words cross: a correct letter helps solve the perpendicular clue.")]
        case .maze:
            return [AppLanguage.text("Usa el mando para moverte desde la flecha de entrada hasta la estrella de salida.", "Use the directional control to move from the entrance arrow to the exit star."),
                    AppLanguage.text("No puedes atravesar las paredes del laberinto.", "You cannot pass through maze walls."),
                    AppLanguage.text("Puedes retroceder sobre tu propio camino sin reiniciar.", "You can retrace your path without restarting."),
                    AppLanguage.text("Solo hay una ruta válida entre la entrada y la salida.", "There is only one route between the entrance and the exit.")]
        case .wordle:
            return [AppLanguage.text("Adivina la palabra de 5 letras en 6 intentos.", "Guess the 5-letter word in 6 attempts."),
                    AppLanguage.text("Verde: letra correcta en la posición correcta.", "Green: the correct letter in the correct position."),
                    AppLanguage.text("Ámbar: la letra está en la palabra, pero en otra posición.", "Amber: the letter is in the word, but in a different position."),
                    AppLanguage.text("Gris: la letra no aparece en la palabra.", "Gray: the letter is not in the word."),
                    AppLanguage.text("Solo se aceptan palabras del diccionario.", "Only words in the game dictionary are accepted.")]
        case .trivia:
            return [AppLanguage.text("Responde 10 preguntas antes de que termine el minuto.", "Answer 10 questions before the minute ends."), AppLanguage.text("Hay preguntas de opción múltiple, verdadero/falso, intruso y ordenar.", "Questions include multiple choice, true or false, odd one out and ordering."), AppLanguage.text("La racha y la rapidez dan bonus.", "Streaks and speed earn bonuses.")]
        case .anygram:
            return [
                AppLanguage.text("Las respuestas tienen 3 o más letras y se forman con las letras disponibles en la rueda.", "Answers have 3 or more letters and use the available letters in the wheel."),
                AppLanguage.text("No necesitas usar todas las letras, pero debes respetar sus multiplicidades: una ficha solo puede usarse una vez en cada palabra.", "You do not have to use every letter, but each tile may only be used once in a word."),
                AppLanguage.text("Desliza el dedo de una letra a otra para formar una palabra. El trazo muestra el recorrido y las letras seleccionadas.", "Slide from letter to letter to form a word. The trace shows your path and selected letters."),
                AppLanguage.text("Al soltar, una respuesta del tablero se revela completa. Las palabras válidas que no estén en el tablero se guardan en Otras palabras.", "Release to reveal a matching board answer. Other valid words are saved under Other words."),
                AppLanguage.text("Cada 3 palabras extra se revela gratis una letra del tablero.", "Every 3 extra words reveal a free letter on the board."),
                AppLanguage.text("Puedes revelar una letra con 30 segundos de penalización o una palabra completa con 90 segundos.", "Reveal a letter for a 30-second penalty or a whole word for 90 seconds."),
                AppLanguage.text("Encuentra todas las palabras cruzadas para completar el puzzle.", "Find every crossing word to complete the puzzle.")
            ]
        case .hashtag:
            return [
                AppLanguage.text("Las dos palabras horizontales y las dos verticales se cruzan físicamente formando un símbolo #.", "Two horizontal words and two vertical words physically cross in a # shape."),
                AppLanguage.text("Toca una casilla y después otra para intercambiar sus letras.", "Tap one square, then another, to swap their letters."),
                AppLanguage.text("Verde indica una letra exacta. Amarillo respeta el número de veces que esa letra aparece en cada palabra, después de contar primero las verdes.", "Green marks an exact letter. Yellow respects how often a letter occurs in each word, after counting green letters first."),
                AppLanguage.text("Una casilla blanca o neutra contiene una letra que no pertenece a la palabra correspondiente.", "A white or neutral square has a letter that does not belong in that word."),
                AppLanguage.text("Reconstruye las cuatro palabras para completar el puzzle.", "Rebuild all four words to complete the puzzle.")
            ]
        case .numbers:
            return [AppLanguage.text("Usa los 6 números para acercarte al objetivo.", "Use the 6 numbers to get close to the target."), AppLanguage.text("Combina dos números con +, −, × o ÷. Cada resultado vuelve a la mesa.", "Combine two numbers using +, −, × or ÷. Each result returns to the table."), AppLanguage.text("Las divisiones deben ser exactas y cada número solo se usa una vez.", "Division must be exact and each number can only be used once."), AppLanguage.text("Exacto gana; si no, cuenta la menor distancia.", "An exact answer wins; otherwise the smallest distance counts.")]
        case .minicross:
            return [AppLanguage.text("Crucigrama compacto donde cada letra pertenece a la vez a una palabra horizontal y a una vertical.", "A compact crossword in which each letter belongs to a horizontal and a vertical word."),
                    AppLanguage.text("Toca una casilla para escribir; tócala otra vez para cambiar entre horizontal y vertical.", "Tap a square to type; tap again to switch between across and down."),
                    AppLanguage.text("Cada letra que aciertes te ayuda en la palabra perpendicular.", "Every correct letter helps with the perpendicular word."),
                    AppLanguage.text("Completa todas las definiciones para terminar.", "Complete all the clues to finish.")]
        case .murdle:
            return [AppLanguage.text("Cada sospechoso se relaciona con un lugar y un objeto distintos.", "Each suspect is linked to a different place and item."), AppLanguage.text("Usa las pistas para relacionar sospechosos, lugares y objetos.", "Use the clues to connect suspects, places and objects."), AppLanguage.text("Toca una casilla una vez para descartarla, dos veces para confirmarla y tres para limpiarla.", "Tap a square once to rule it out, twice to confirm it, and three times to clear it."), AppLanguage.text("Lee el informe del caso: puede tratarse de un asesinato o de un robo. Deduce la persona, el lugar y el objeto.", "Read the case report: it may concern a murder or a theft. Deduce the person, place and item."), AppLanguage.text("Elige las tres respuestas y pulsa Resolver el caso.", "Choose all three answers and tap Solve the case.")]
        case .murdoku:
            return [AppLanguage.text("Sitúa a los cinco sospechosos en el plano: debe haber exactamente uno en cada fila y en cada columna.", "Place the five suspects on the map: exactly one must be in each row and each column."),
                    AppLanguage.text("Los colores y los bordes gruesos separan las estancias, con su nombre superpuesto. El mobiliario (mesa, silla, sofá, estatua, alfombra, lámpara) ocupa su casilla; solo silla, sofá y alfombra dejan colocar a alguien encima — el resto la bloquea, igual que la víctima (V).", "Colors and thick borders separate named rooms. Furniture occupies its square; only chairs, sofas and rugs allow a suspect on top. Other furniture and the victim (V) block placement."),
                    AppLanguage.text("Selecciona un sospechoso: toca una casilla para anotar que podría estar ahí, mantén pulsado para colocarlo.", "Select a suspect: tap a square to note a possible position, or press and hold to place them."),
                    AppLanguage.text("Marcar pone o quita una × en una casilla, indicando que ahí no hay nadie — no es una sospecha de una persona en concreto, es un hecho del tablero. Borrar limpia una casilla del todo. Deshacer revierte el último cambio.", "Mark toggles an × in a square to indicate nobody is there. Clear removes everything from a square. Undo reverses the last change."),
                    AppLanguage.text("Todas las pistas son ciertas. No se refieren todas a lo mismo:", "Every clue is true, but clues describe different relationships:"),
                    AppLanguage.text("«En la estancia X» / «no estaba en la estancia X» / «fue la única persona en la estancia X»: hablan de la estancia entera, no de una casilla concreta.", "“In room X”, “not in room X” and “the only person in room X” refer to the whole room, not one square."),
                    AppLanguage.text("«Al norte de Y» / «a la izquierda de Y»: comparan solo la fila o solo la columna en todo el tablero — no implica estar cerca ni en la misma estancia.", "“North of Y” and “left of Y” compare only rows or columns across the entire board; they do not imply proximity or sharing a room."),
                    AppLanguage.text("«Junto a [mueble]»: una casilla justo al lado (arriba, abajo, izquierda o derecha) Y dentro de la misma estancia que ese mueble.", "“Next to [furniture]” means a directly adjacent square (up, down, left or right) within the same room as that furniture."),
                    AppLanguage.text("«Al norte/sur/este/oeste de [mueble]»: solo compara fila o columna con la casilla de ese mueble, sin importar la distancia ni la estancia — no es lo mismo que «junto a».", "“North/south/east/west of [furniture]” compares rows or columns with the furniture square, regardless of distance or room. It is different from “next to”."),
                    AppLanguage.text("El asesino es la única persona que quedó a solas con la víctima en su estancia.", "The murderer is the only suspect alone with the victim in the same room.")]
        case .ladder:
            return [AppLanguage.text("Parte de la palabra inicial y llega a la palabra final.", "Go from the starting word to the final word."),
                    AppLanguage.text("En cada peldaño cambia exactamente una letra; no se puede añadir, quitar ni reordenar letras.", "Change exactly one letter per step; do not add, remove or rearrange letters."),
                    AppLanguage.text("Cada palabra debe estar en el diccionario del juego y no puedes repetir ninguna.", "Every word must be in the game dictionary and no word can be repeated."),
                    AppLanguage.text("Completa la escalera en el número mínimo de pasos indicado.", "Complete the ladder in the stated minimum number of steps.")]
        case .decoder:
            return [AppLanguage.text("Hay un código oculto de 4 casillas con 4 colores DISTINTOS. En Diario y Práctica se eligen entre 6 colores; en Infinito, entre 4, 5 o 6 según el nivel. Cada color tiene nombre y número; el número se muestra en las teclas si activas «Diferenciar sin color» en Accesibilidad.", "A hidden code fills 4 slots with 4 DIFFERENT colours. Daily and Practice use 6 colours; Infinite uses 4, 5 or 6 depending on the level. Every colour has a name and a number; the number appears on the keys if you turn on Differentiate Without Color in Accessibility."),
                    AppLanguage.text("Los colores NO se repiten: ni en el código secreto ni en tus intentos. Si eliges un color que ya está en otra casilla, el dispositivo lo rechaza y te dice dónde está.", "Colours NEVER repeat: not in the secret code and not in your attempts. If you pick a colour already used in another slot, the device refuses it and tells you where it is."),
                    AppLanguage.text("Las antenas eligen el modo: toca la roja para Diario/Práctica o la verde para Infinito. Solo la del modo activo está encendida.", "The antennas choose the mode: tap the red one for Daily/Practice or the green one for Infinite. Only the active mode's antenna is lit."),
                    AppLanguage.text("Todo lo demás se hace con el mando naranja. Toca una tecla de la fila en curso para seleccionar su casilla. GIRA el mando: el color se ve en esa misma tecla, como vista previa (atenuado y tachado si ya está en otra casilla). TOCA el mando para colocarlo y pasar a la siguiente casilla vacía. Para cambiar una casilla, selecciónala y coloca otro color.", "Everything else is done with the orange knob. Tap a key in the current row to select its slot. TURN the knob: the colour shows in that very key as a preview (dimmed and struck through if it is already in another slot). TAP the knob to place it and move to the next empty slot. To change a slot, select it and place another colour."),
                    AppLanguage.text("Con las 4 casillas llenas, MANTÉN pulsado el mando medio segundo, sin girarlo, para enviar el intento. Si falta alguna casilla, el dispositivo avisa y no gasta intento. No hay botones de Enviar ni de Borrar. Tienes 7 intentos (en Infinito, menos en los niveles altos).", "With all 4 slots filled, HOLD the knob for half a second, without turning it, to submit the attempt. If a slot is missing the device warns you and no attempt is used. There are no Submit or Clear buttons. You have 7 attempts (fewer on high Infinite levels)."),
                    AppLanguage.text("Tras cada intento, los cuatro pilotos de la derecha dicen cuántos colores están en su casilla (verdes), cuántos en otra (blancos) y cuántos no están (apagados). La barrita bajo cada tecla va APAGADA; pulsa el botón PISTA (la bombilla) para encender la del último intento enviado: VERDE = ese color está en su casilla; BLANCA = ese color está en el código, pero en otra casilla; APAGADA = ese color no está en el código. La pista se queda encendida en ese intento.", "After each attempt the four lights on the right say how many colours are in their slot (green), how many in another slot (white) and how many are not in the code (off). The small bar under each key stays OFF; press the HINT button (the bulb) to light the bars of the last submitted attempt: GREEN = that colour is in its slot; WHITE = that colour is in the code, but in another slot; OFF = that colour is not in the code. The hint stays on for that attempt."),
                    AppLanguage.text("La franja negra bajo el tablero muestra los colores activos en la partida. Si aciertas, ganas; si agotas los intentos, pierdes y la franja muestra la solución, en orden. Una partida terminada ya no se puede cambiar.", "The black band under the board shows the colours in play in the game. Crack the code to win; use all attempts and you lose, and the band shows the solution, in order. A finished game cannot be changed."),
                    AppLanguage.text("Diario es el mismo en todos tus dispositivos; Práctica es una partida suelta. Infinito es aparte: niveles 1–10 con 4 colores, 11–20 con 5 y desde el 21 con 6; hasta el 30 tienes 7 intentos, del 31 al 40 tienes 6 y desde el 41 tienes 5 (las filas que no puedes usar se ven apagadas). Ganar tu nivel más alto desbloquea el siguiente; si pierdes, tu máximo NO baja. Cuando no hay partida en marcha, el mando es el selector de nivel: gíralo para ver en el contador rojo cualquier nivel desbloqueado y tócalo para empezarlo con un código nuevo. Repetir un nivel inferior no sube ni baja tu máximo. Infinito guarda tu progreso y la ronda en curso en este dispositivo (no se sincroniza) y no cuenta para el puzle diario, rachas ni estadísticas.", "Daily is the same on all your devices; Practice is a loose game. Infinite is separate: levels 1–10 use 4 colours, 11–20 use 5 and 21 onward use 6; up to level 30 you get 7 attempts, 31–40 give 6 and 41 onward give 5 (rows you cannot use are shown off). Winning your highest level unlocks the next one; if you lose, your highest does NOT go down. When no game is in progress, the knob is the level selector: turn it to see any unlocked level on the red counter and tap it to start it with a new code. Replaying a lower level neither raises nor lowers your highest. Infinite saves your progress and the round in progress on this device (it does not sync) and does not count towards the daily puzzle, streaks or statistics."),
                    AppLanguage.text("Los hápticos y las luces HDR se pueden desactivar solo para este juego desde el menú de la barra. HDR solo se nota en pantallas compatibles.", "Haptics and HDR lights can be turned off for this game only from the toolbar menu. HDR only shows on capable displays.")]
        }
    }
}

struct PZRulesSheet: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let kind: PuzzleKind
    /// Optional live context ("Ahora"), shown above the rules. Empty for every
    /// game that does not pass it, so their sheet is unchanged.
    var now: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: PZSpace.xl) {
                HStack(spacing: PZSpace.md) {
                    PZWashBadge(color: PZ.color(kind), size: 56) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 24, weight: .bold))
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: PZSpace.xxs) {
                        Text(AppLanguage.text("Cómo se juega", "How to play")).pzEyebrowStyle(PZ.color(kind))
                        Text(kind.title).font(PZFont.title).foregroundStyle(PZColor.ink)
                    }
                }

                if !now.isEmpty { nowSection }

                VStack(alignment: .leading, spacing: PZSpace.lg) {
                    ForEach(Array(kind.rules.enumerated()), id: \.offset) { i, rule in
                        HStack(alignment: .top, spacing: PZSpace.md) {
                            PZWashBadge(color: PZ.color(kind), size: 26) {
                                Text("\(i + 1)").font(PZFont.label)
                            }
                            Text(rule)
                                .font(PZFont.body)
                                .foregroundStyle(PZColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Button { dismiss() } label: {
                    Text(AppLanguage.text("Entendido", "Got it")).pzPill(PZ.color(kind), wide: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("rules.done")
            }
            .padding(PZSpace.xl)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Text(AppLanguage.text("Cerrar", "Close")).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("rules.close")
            }
            .padding(.horizontal, PZSpace.xl)
        }
        }
        .accessibilityIdentifier("rules.sheet")
        .accessibilityAction(.escape) { dismiss() }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(PZRadius.sheet)
        .presentationDragIndicator(.visible)
        .presentationBackground { LiquidCanvasBackground() }
    }

    /// "Ahora / Right now": what the game screen no longer prints (current mode,
    /// level, colours, attempts...). One combined VoiceOver element.
    private var nowSection: some View {
        VStack(alignment: .leading, spacing: PZSpace.xs) {
            Text(AppLanguage.text("Ahora", "Right now")).pzEyebrowStyle(PZ.color(kind))
            ForEach(Array(now.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(PZFont.body)
                    .foregroundStyle(PZColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PZSpace.md)
        .background(PZ.color(kind).opacity(0.10), in: RoundedRectangle(cornerRadius: PZRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rules.now")
    }
}

/// Adds a "?" toolbar button and auto-presents the rules the first time.
struct PZRulesModifier: ViewModifier {
    let kind: PuzzleKind
    var now: [String] = []
    @State private var showRules = false
    @AccessibilityFocusState private var helpFocused: Bool
    @AppStorage private var seen: Bool

    init(kind: PuzzleKind, now: [String] = []) {
        self.kind = kind
        self.now = now
        _seen = AppStorage(wrappedValue: false, AppLanguage.current == .spanish ? "nr.seenRules.\(kind.rawValue)" : "nr.seenRules.en.\(kind.rawValue)")
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showRules = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(AppLanguage.text("Cómo se juega", "How to play"))
                    .accessibilityIdentifier("rules.replay")
                    .accessibilityFocused($helpFocused)
                }
            }
            .sheet(isPresented: $showRules, onDismiss: {
                seen = true
                helpFocused = true
            }) { PZRulesSheet(kind: kind, now: now) }
            .task {
                // A completed guide stays completed when the UI language changes.
                // Keep both legacy keys; do not reset existing user preferences.
                let completed = seen
                    || UserDefaults.standard.bool(forKey: "nr.seenRules.\(kind.rawValue)")
                    || UserDefaults.standard.bool(forKey: "nr.seenRules.en.\(kind.rawValue)")
                guard !completed else { return }
                do { try await Task.sleep(nanoseconds: 450_000_000) }
                catch { return }
                guard !Task.isCancelled else { return }
                showRules = true
            }
    }
}

extension View {
    func pzRules(_ kind: PuzzleKind) -> some View { modifier(PZRulesModifier(kind: kind)) }
    /// Same "?" button and sheet, plus an "Ahora" section with live context.
    func pzRules(_ kind: PuzzleKind, now: [String]) -> some View { modifier(PZRulesModifier(kind: kind, now: now)) }
}
#endif
