#if os(iOS)
//
//  CasualPuzzleGames.swift — News Raider
//  Hashtag y Anygram. (Trivial 10 en 60 y Cifras retirados el 2026-11-23.)
//

import SwiftUI
import Combine
import UIKit

// MARK: - Hashtag

/// Four five-letter words arranged as a physical hashtag. Intersections are
/// represented by one shared cell.
struct HashtagPuzzle: Identifiable, Sendable, Hashable {
    struct Word: Identifiable, Sendable, Hashable {
        enum Direction: Sendable, Hashable { case horizontal, vertical }
        let id: Int
        let answer: String
        let row: Int
        let col: Int
        let direction: Direction

        var cells: [GridCell] {
            answer.indices.enumerated().map { offset, _ in
                direction == .horizontal
                    ? GridCell(row: row, col: col + offset)
                    : GridCell(row: row + offset, col: col)
            }
        }
    }

    let id: String
    let words: [Word]
    let cells: [GridCell]
    let letters: [Character]

    var solution: [GridCell: Character] {
        var result: [GridCell: Character] = [:]
        for word in words {
            for (index, cell) in word.cells.enumerated() {
                result[cell] = Array(word.answer)[index]
            }
        }
        return result
    }

    static func generate(seed: UInt64, language: PuzzleLanguage = .spanish) -> HashtagPuzzle {
        var rng = SeededGenerator(seed: seed)
        let templates = language == .english ? HashtagBank.englishTemplates : HashtagBank.templates
        let template = templates[rng.int(templates.count)]
        let words = [
            Word(id: 0, answer: template.horizontalTop, row: 1, col: 0, direction: .horizontal),
            Word(id: 1, answer: template.horizontalBottom, row: 3, col: 0, direction: .horizontal),
            Word(id: 2, answer: template.verticalLeft, row: 0, col: 1, direction: .vertical),
            Word(id: 3, answer: template.verticalRight, row: 0, col: 3, direction: .vertical)
        ]
        let cells = Array(Set(words.flatMap(\.cells))).sorted {
            $0.row == $1.row ? $0.col < $1.col : $0.row < $1.row
        }
        var solution: [GridCell: Character] = [:]
        for word in words {
            for (index, cell) in word.cells.enumerated() {
                solution[cell] = Array(word.answer)[index]
            }
        }
        let letters = rng.shuffled(cells.compactMap { solution[$0] })
        return .init(id: "\(language == .english ? "en-" : "")hash-\(seed)", words: words, cells: cells, letters: letters)
    }
}

private enum HashtagBank {
    struct Template {
        let horizontalTop: String
        let horizontalBottom: String
        let verticalLeft: String
        let verticalRight: String
    }

    static let englishTemplates: [Template] = [
        .init(horizontalTop: "BEACH", horizontalBottom: "BREAD", verticalLeft: "HEART", verticalRight: "OCEAN"),
        .init(horizontalTop: "BREAD", horizontalBottom: "APPLE", verticalLeft: "GRAPE", verticalRight: "TABLE"),
        .init(horizontalTop: "BREAD", horizontalBottom: "FIELD", verticalLeft: "TRAIN", verticalRight: "TABLE"),
        .init(horizontalTop: "BREAD", horizontalBottom: "RIVER", verticalLeft: "TRAIN", verticalRight: "WATER")
    ]
    static let templates: [Template] = [
        .init(horizontalTop: "CASAS", horizontalBottom: "PERRO",
              verticalLeft: "PARED", verticalRight: "MADRE"),
        .init(horizontalTop: "LUNES", horizontalBottom: "SALTO",
              verticalLeft: "JUGAR", verticalRight: "MENTA"),
        .init(horizontalTop: "GATOS", horizontalBottom: "NUBES",
              verticalLeft: "SALUD", verticalRight: "PODER"),
        .init(horizontalTop: "MESAS", horizontalBottom: "COLOR",
              verticalLeft: "MENOR", verticalRight: "CALOR"),
        // Generadas 2026-11-15 con Tools/lexicon/hashtag.py desde wordle_answers (sin palabras repetidas).
        .init(horizontalTop: "HUEVO", horizontalBottom: "PERSA", verticalLeft: "TUNEL", verticalRight: "AVISO"),
        .init(horizontalTop: "DUNAS", horizontalBottom: "IDEAL", verticalLeft: "HUIDA", verticalRight: "CANAL"),
        .init(horizontalTop: "HINDU", horizontalBottom: "GNOMO", verticalLeft: "PIANO", verticalRight: "EDEMA"),
        .init(horizontalTop: "AEREA", horizontalBottom: "ANGEL", verticalLeft: "PERNO", verticalRight: "VEJEZ"),
        .init(horizontalTop: "JAMON", horizontalBottom: "PALOS", verticalLeft: "CAPAZ", verticalRight: "MODOS"),
        .init(horizontalTop: "GANSO", horizontalBottom: "COLON", verticalLeft: "CANOA", verticalRight: "ASNOS"),
        .init(horizontalTop: "PECHO", horizontalBottom: "MOSCA", verticalLeft: "CEROS", verticalRight: "CHICA"),
        .init(horizontalTop: "CALIZ", horizontalBottom: "ISLAM", verticalLeft: "SALSA", verticalRight: "RIVAL"),
        .init(horizontalTop: "PLEBE", horizontalBottom: "OVNIS", verticalLeft: "LLAVE", verticalRight: "ABRIL"),
        .init(horizontalTop: "NATAL", horizontalBottom: "IDOLO", verticalLeft: "ÑANDU", verticalRight: "CALLE"),
        .init(horizontalTop: "SEDAL", horizontalBottom: "MACHO", verticalLeft: "RENAL", verticalRight: "BACHE"),
        .init(horizontalTop: "LOGRO", horizontalBottom: "LINCE", verticalLeft: "COPIA", verticalRight: "TRECE"),
        .init(horizontalTop: "LIDER", horizontalBottom: "AGUDA", verticalLeft: "BINGO", verticalRight: "CELDA"),
        .init(horizontalTop: "TIESO", horizontalBottom: "ATLAS", verticalLeft: "NIETO", verticalRight: "USUAL"),
        .init(horizontalTop: "BRAZO", horizontalBottom: "MAGNO", verticalLeft: "ORCAS", verticalRight: "OZONO"),
        .init(horizontalTop: "DALIA", horizontalBottom: "CIELO", verticalLeft: "MATIZ", verticalRight: "RIFLE"),
        .init(horizontalTop: "GORRA", horizontalBottom: "AMIGO", verticalLeft: "NORMA", verticalRight: "TRIGO"),
        .init(horizontalTop: "NECIO", horizontalBottom: "GALOS", verticalLeft: "SEÑAS", verticalRight: "LICOR"),
        .init(horizontalTop: "MONJE", horizontalBottom: "GRAVE", verticalLeft: "TORRE", verticalRight: "OJIVA"),
        .init(horizontalTop: "FEROZ", horizontalBottom: "HELIO", verticalLeft: "RESES", verticalRight: "FOBIA"),
        .init(horizontalTop: "MITIN", horizontalBottom: "AMADA", verticalLeft: "RITMO", verticalRight: "HINDI"),
        .init(horizontalTop: "TIMON", horizontalBottom: "CRETA", verticalLeft: "LIBRE", verticalRight: "AORTA"),
        .init(horizontalTop: "VIGAS", horizontalBottom: "OMEGA", verticalLeft: "FIRME", verticalRight: "RANGO"),
        .init(horizontalTop: "PAÑOS", horizontalBottom: "SOCIO", verticalLeft: "CAJON", verticalRight: "COJIN"),
        .init(horizontalTop: "POLLO", horizontalBottom: "LLENO", verticalLeft: "COPLA", verticalRight: "PLENA"),
        .init(horizontalTop: "BAYAS", horizontalBottom: "HOGAR", verticalLeft: "TALON", verticalRight: "RAMAS"),
        .init(horizontalTop: "TRIBU", horizontalBottom: "DEBIL", verticalLeft: "ARTES", verticalRight: "EBRIO"),
        .init(horizontalTop: "LAPIZ", horizontalBottom: "ELFOS", verticalLeft: "GALLO", verticalRight: "BIDON"),
        .init(horizontalTop: "BOXEO", horizontalBottom: "INDIO", verticalLeft: "HORNO", verticalRight: "GENIO"),
        .init(horizontalTop: "CARTA", horizontalBottom: "ALMAS", verticalLeft: "SABLE", verticalRight: "ATRAS"),
        .init(horizontalTop: "ROLLO", horizontalBottom: "AVARO", verticalLeft: "POLVO", verticalRight: "CLERO"),
        .init(horizontalTop: "ZORRA", horizontalBottom: "GAITA", verticalLeft: "LOCAL", verticalRight: "FRUTA"),
        .init(horizontalTop: "TENUE", horizontalBottom: "PLANO", verticalLeft: "VELLO", verticalRight: "BUENA"),
        .init(horizontalTop: "PARED", horizontalBottom: "JEREZ", verticalLeft: "CAFES", verticalRight: "GENES"),
        .init(horizontalTop: "CAQUI", horizontalBottom: "LEJIA", verticalLeft: "PANES", verticalRight: "LUCIO"),
        .init(horizontalTop: "BUDIN", horizontalBottom: "MITAD", verticalLeft: "FURIA", verticalRight: "VIRAL"),
        .init(horizontalTop: "GRITO", horizontalBottom: "COFRE", verticalLeft: "PRIOR", verticalRight: "UTERO"),
        .init(horizontalTop: "SESOS", horizontalBottom: "ACTAS", verticalLeft: "PESCA", verticalRight: "SOGAS"),
        .init(horizontalTop: "SELVA", horizontalBottom: "QUEJA", verticalLeft: "FEMUR", verticalRight: "OVEJA"),
        .init(horizontalTop: "TUTOR", horizontalBottom: "GALAN", verticalLeft: "AULAS", verticalRight: "LOCAS"),
        .init(horizontalTop: "MAMUT", horizontalBottom: "MOTIN", verticalLeft: "MAYOR", verticalRight: "PUDIN"),
        .init(horizontalTop: "BANAL", horizontalBottom: "ASTRO", verticalLeft: "PAUSA", verticalRight: "SABRE"),
        .init(horizontalTop: "METAL", horizontalBottom: "ENANO", verticalLeft: "REINA", verticalRight: "FAUNA"),
        .init(horizontalTop: "HUECA", horizontalBottom: "ATROZ", verticalLeft: "CULTA", verticalRight: "OCHOS"),
        .init(horizontalTop: "SERIO", horizontalBottom: "POMPA", verticalLeft: "HEROE", verticalRight: "MIOPE"),
        .init(horizontalTop: "CHATO", horizontalBottom: "PLACA", verticalLeft: "CHELO", verticalRight: "ETICA"),
        .init(horizontalTop: "NUEVE", horizontalBottom: "JABON", verticalLeft: "RURAL", verticalRight: "AVION"),
        .init(horizontalTop: "LISTO", horizontalBottom: "DULCE", verticalLeft: "TIFUS", verticalRight: "ATICO"),
        .init(horizontalTop: "CAÑON", horizontalBottom: "CINTA", verticalLeft: "SABIO", verticalRight: "MONTE"),
        .init(horizontalTop: "NOVIO", horizontalBottom: "ATAUD", verticalLeft: "TONTO", verticalRight: "VIRUS"),
        .init(horizontalTop: "GATAS", horizontalBottom: "ISLAS", verticalLeft: "CAUSA", verticalRight: "PAPAL"),
        .init(horizontalTop: "LUCHA", horizontalBottom: "NOBLE", verticalLeft: "BUZON", verticalRight: "CHULO"),
        .init(horizontalTop: "TABLA", horizontalBottom: "ETICO", verticalLeft: "VASTO", verticalRight: "FLACO"),
        .init(horizontalTop: "FRESA", horizontalBottom: "VERDE", verticalLeft: "ORDEN", verticalRight: "OSADA"),
        .init(horizontalTop: "LUPUS", horizontalBottom: "BAJON", verticalLeft: "PURAS", verticalRight: "BUHOS"),
        .init(horizontalTop: "NIÑOS", horizontalBottom: "TOTEM", verticalLeft: "VISOR", verticalRight: "GOLES"),
        .init(horizontalTop: "GASES", horizontalBottom: "UNION", verticalLeft: "VAINA", verticalRight: "HEDOR"),
        .init(horizontalTop: "LANCE", horizontalBottom: "TRONO", verticalLeft: "BAGRE", verticalRight: "ICONO"),
        .init(horizontalTop: "BUSES", horizontalBottom: "TONTA", verticalLeft: "HUNOS", verticalRight: "DELTA"),
        .init(horizontalTop: "MALTA", horizontalBottom: "TRIPA", verticalLeft: "TAURO", verticalRight: "ETAPA"),
        .init(horizontalTop: "SOFAS", horizontalBottom: "ACTOS", verticalLeft: "HORCA", verticalRight: "RAROS"),
        .init(horizontalTop: "ROBOT", horizontalBottom: "OBESO", verticalLeft: "BOMBO", verticalRight: "BOLSO"),
        .init(horizontalTop: "RIGOR", horizontalBottom: "OGROS", verticalLeft: "RIEGO", verticalRight: "FOTOS"),
        .init(horizontalTop: "VALOR", horizontalBottom: "MISMO", verticalLeft: "PATIN", verticalRight: "FORMA"),
        .init(horizontalTop: "PARTO", horizontalBottom: "ARAÑA", verticalLeft: "CATRE", verticalRight: "OTOÑO"),
        .init(horizontalTop: "PAVOR", horizontalBottom: "ACRES", verticalLeft: "BARCO", verticalRight: "JOVEN"),
        .init(horizontalTop: "CORAL", horizontalBottom: "TAREA", verticalLeft: "ROPAS", verticalRight: "NAVES"),
        .init(horizontalTop: "FLECO", horizontalBottom: "ARROZ", verticalLeft: "FLORA", verticalRight: "ACTOR"),
        .init(horizontalTop: "NIDOS", horizontalBottom: "FENIX", verticalLeft: "FIDEO", verticalRight: "PODIO"),
        .init(horizontalTop: "ROQUE", horizontalBottom: "DEUDA", verticalLeft: "MOTEL", verticalRight: "RUEDO"),
        .init(horizontalTop: "TENAZ", horizontalBottom: "ARABE", verticalLeft: "METRO", verticalRight: "CAOBA"),
        .init(horizontalTop: "SIMIO", horizontalBottom: "TOSCO", verticalLeft: "MITOS", verticalRight: "CINCO"),
        .init(horizontalTop: "CURVA", horizontalBottom: "HIMNO", verticalLeft: "SUCIO", verticalRight: "AVENA"),
        .init(horizontalTop: "FACIL", horizontalBottom: "RATOS", verticalLeft: "NASAL", verticalRight: "PITON"),
        .init(horizontalTop: "HUECO", horizontalBottom: "GRASA", verticalLeft: "MUGRE", verticalRight: "OCASO"),
        .init(horizontalTop: "CASPA", horizontalBottom: "TOSCA", verticalLeft: "TAPON", verticalRight: "EPICO"),
        .init(horizontalTop: "REINO", horizontalBottom: "DOGMA", verticalLeft: "MELON", verticalRight: "ANIMO"),
        .init(horizontalTop: "DOCIL", horizontalBottom: "IGUAL", verticalLeft: "BONGO", verticalRight: "FINAL"),
        .init(horizontalTop: "FALSO", horizontalBottom: "OPERA", verticalLeft: "CAMPO", verticalRight: "OSTRA"),
        .init(horizontalTop: "TORNO", horizontalBottom: "VITAL", verticalLeft: "MOMIA", verticalRight: "ANUAL"),
        .init(horizontalTop: "MILES", horizontalBottom: "HAYAS", verticalLeft: "LILAS", verticalRight: "NENAS"),
        .init(horizontalTop: "TECHO", horizontalBottom: "BRUTA", verticalLeft: "NEGRA", verticalRight: "CHATA"),
        .init(horizontalTop: "BUCAL", horizontalBottom: "LUNAR", verticalLeft: "DUQUE", verticalRight: "CACAO"),
        .init(horizontalTop: "RUINA", horizontalBottom: "CLARO", verticalLeft: "MUSLO", verticalRight: "ENERO"),
        .init(horizontalTop: "MEJOR", horizontalBottom: "OREJA", verticalLeft: "LEPRA", verticalRight: "MONJA"),
        .init(horizontalTop: "PUÑAL", horizontalBottom: "POLIO", verticalLeft: "RUDOS", verticalRight: "LABIO"),
        .init(horizontalTop: "HORAS", horizontalBottom: "BILIS", verticalLeft: "NORIA", verticalRight: "MAFIA"),
        .init(horizontalTop: "LORES", horizontalBottom: "MISMA", verticalLeft: "BOTIN", verticalRight: "REUMA"),
        .init(horizontalTop: "RAZON", horizontalBottom: "CRUDA", verticalLeft: "PADRE", verticalRight: "BORDE"),
        .init(horizontalTop: "GALAS", horizontalBottom: "SETAS", verticalLeft: "MAREA", verticalRight: "DAGAS"),
        .init(horizontalTop: "RUMBO", horizontalBottom: "MORSA", verticalLeft: "HUMOR", verticalRight: "ABUSO"),
        .init(horizontalTop: "HIELO", horizontalBottom: "URNAS", verticalLeft: "LIBRO", verticalRight: "ALTAR"),
        .init(horizontalTop: "LOTES", horizontalBottom: "ARPIA", verticalLeft: "HONRA", verticalRight: "REDIL"),
        .init(horizontalTop: "VUELO", horizontalBottom: "DIQUE", verticalLeft: "JULIO", verticalRight: "ALBUM"),
        .init(horizontalTop: "SIGLO", horizontalBottom: "AGUJA", verticalLeft: "CIEGO", verticalRight: "FLOJO"),
        .init(horizontalTop: "MANIA", horizontalBottom: "FRENO", verticalLeft: "CABRA", verticalRight: "HIENA"),
        .init(horizontalTop: "LETRA", horizontalBottom: "CORTO", verticalLeft: "TEMOR", verticalRight: "GRUTA"),
        .init(horizontalTop: "BRASA", horizontalBottom: "CONDE", verticalLeft: "ARDOR", verticalRight: "ASADA"),
        .init(horizontalTop: "CARGO", horizontalBottom: "SENDA", verticalLeft: "BARES", verticalRight: "AGUDO"),
        .init(horizontalTop: "MUSEO", horizontalBottom: "HONGO", verticalLeft: "FUROR", verticalRight: "BEIGE"),
        .init(horizontalTop: "TAPIZ", horizontalBottom: "MEDIO", verticalLeft: "LATEX", verticalRight: "LITIO"),
        .init(horizontalTop: "FOCAS", horizontalBottom: "ESQUI", verticalLeft: "TORSO", verticalRight: "SAQUE"),
        .init(horizontalTop: "SEÑOR", horizontalBottom: "FALDA", verticalLeft: "SEÑAL", verticalRight: "HORDA"),
        .init(horizontalTop: "ARDUO", horizontalBottom: "BELLO", verticalLeft: "CRUEL", verticalRight: "SUELA"),
        .init(horizontalTop: "RIÑON", horizontalBottom: "ZONAS", verticalLeft: "HIJOS", verticalRight: "GOTAS"),
        .init(horizontalTop: "CISNE", horizontalBottom: "TRUCO", verticalLeft: "SIDRA", verticalRight: "UNICO"),
        .init(horizontalTop: "TAZON", horizontalBottom: "TEMPO", verticalLeft: "CAREY", verticalRight: "GOLPE"),
        .init(horizontalTop: "PELEA", horizontalBottom: "INCAS", verticalLeft: "LEONA", verticalRight: "YEMAS"),
        .init(horizontalTop: "RICAS", horizontalBottom: "CHICO", verticalLeft: "BICHO", verticalRight: "VASCO"),
        .init(horizontalTop: "COÑAC", horizontalBottom: "COSTO", verticalLeft: "COLOR", verticalRight: "PARTE"),
        .init(horizontalTop: "TORAX", horizontalBottom: "FRIOS", verticalLeft: "POTRO", verticalRight: "VAPOR"),
        .init(horizontalTop: "SAPOS", horizontalBottom: "FOCOS", verticalLeft: "CAROS", verticalRight: "BOTON"),
        .init(horizontalTop: "PANEL", horizontalBottom: "FLOTA", verticalLeft: "CABLE", verticalRight: "OESTE"),
        .init(horizontalTop: "JUNIO", horizontalBottom: "MANTA", verticalLeft: "FUGAZ", verticalRight: "VISTO"),
        .init(horizontalTop: "RUSOS", horizontalBottom: "OIDOS", verticalLeft: "FUSIL", verticalRight: "POCOS"),
        .init(horizontalTop: "LABOR", horizontalBottom: "VIRGO", verticalLeft: "LATIN", verticalRight: "CONGA"),
        .init(horizontalTop: "MILLA", horizontalBottom: "POEMA", verticalLeft: "TIFON", verticalRight: "PLUMA"),
        .init(horizontalTop: "RUBOR", horizontalBottom: "POLEA", verticalLeft: "TUMOR", verticalRight: "HOTEL"),
        .init(horizontalTop: "SITIO", horizontalBottom: "CERDO", verticalLeft: "LICEO", verticalRight: "MIEDO"),
        .init(horizontalTop: "LLANO", horizontalBottom: "ONDAS", verticalLeft: "LLENA", verticalRight: "ONZAS")
    ]
}


// MARK: - Hashtag game

struct HashtagGame: View {
    let puzzle: HashtagPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var letters: [Character]
    @State private var selected: Int?
    @State private var elapsed = 0
    @State private var finished = false
    @State private var result: PZResult?
    @State private var toast: PZToast?
    @State private var keyboardCursor: GridCell?
    @FocusState private var hardwareKeyboardFocused: Bool
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(puzzle: HashtagPuzzle) {
        self.puzzle = puzzle
        _letters = State(initialValue: puzzle.letters)
    }

    private var solvedCount: Int {
        puzzle.words.filter { word in
            word.cells.enumerated().allSatisfy { index, cell in
                guard let boardIndex = puzzle.cells.firstIndex(of: cell) else { return false }
                return letters[boardIndex] == Array(word.answer)[index]
            }
        }.count
    }

    var body: some View {
        VStack(spacing: PZSpace.lg) {
            HStack {
                PZStat(label: AppLanguage.text("PALABRAS", "WORDS"), value: "\(solvedCount)/4")
                Spacer()
                PZStat(label: AppLanguage.text("TIEMPO", "TIME"), value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
            }

            Text(AppLanguage.text("Intercambia letras para reconstruir el #", "Swap letters to rebuild the #"))
                .font(PZFont.summary)
                .foregroundStyle(PZColor.inkSecondary)
                .multilineTextAlignment(.center)

            board

            HStack(spacing: PZSpace.md) {
                Label(AppLanguage.text("Exacta", "Exact"), systemImage: "square.fill").foregroundStyle(PZColor.success)
                Label(AppLanguage.text("En la palabra", "In the word"), systemImage: "square.fill").foregroundStyle(.yellow)
                Label(AppLanguage.text("No pertenece", "Not in the word"), systemImage: "square").foregroundStyle(PZColor.inkSecondary)
            }
            .font(PZFont.caption)
        }
        .padding(PZSpace.screenH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PZGameBackdrop(color: PZ.hashtag))
        .navigationTitle("Hashtag")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            let saved = progress.fill(puzzle.id)
            if saved.count == puzzle.cells.count {
                letters = puzzle.cells.enumerated().compactMap { index, _ in
                    saved[String(index)]?.first
                }
            }
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .pzToast($toast)
        .pzRules(.hashtag)
        // Hardware keyboard: arrows walk the board, space/return picks up and
        // drops a letter, so the whole puzzle is playable from an iPad keyboard
        // without reaching for the screen.
        .focusable(interactions: .activate)
        .focused($hardwareKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handleHardwareKey($0) }
        .onAppear { claimHardwareKeyboardFocus() }
        // Tapping a letter or a cell moves focus to that button; without this
        // the hardware keyboard stops responding after the first touch.
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
    }

    /// Index of the board cell the keyboard cursor sits on.
    private func cellIndex(row: Int, col: Int) -> Int? {
        puzzle.cells.firstIndex(of: GridCell(row: row, col: col))
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        let cursor = keyboardCursor ?? puzzle.cells.first.map { $0 } ?? GridCell(row: 0, col: 0)

        func step(_ dr: Int, _ dc: Int) -> KeyPress.Result {
            var r = cursor.row, c = cursor.col
            for _ in 0..<5 {
                r += dr; c += dc
                guard (0..<5).contains(r), (0..<5).contains(c) else { break }
                if cellIndex(row: r, col: c) != nil {
                    keyboardCursor = GridCell(row: r, col: c)
                    PZHaptics.tick()
                    return .handled
                }
            }
            return .handled
        }

        switch press.key {
        case .upArrow:    return step(-1, 0)
        case .downArrow:  return step(1, 0)
        case .leftArrow:  return step(0, -1)
        case .rightArrow: return step(0, 1)
        case .space, .return:
            guard let index = cellIndex(row: cursor.row, col: cursor.col) else { return .handled }
            if feedback(at: index) == .exact {
                toast = PZToast(text: AppLanguage.text("Esa letra ya está en su sitio", "That letter is already in place"), kind: .info)
                return .handled
            }
            if let source = selected {
                if source != index {
                    withAnimation(PZAnim.shuffle) { letters.swapAt(source, index) }
                    persist()
                    if solvedCount == puzzle.words.count { finish() }
                }
                selected = nil
            } else {
                selected = index
            }
            PZHaptics.tick()
            return .handled
        case .escape:
            selected = nil
            return .handled
        default:
            return .ignored
        }
    }

    /// Reclaim focus after SwiftUI has finished focusing a tapped board cell.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    private var board: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 5
            let side = min(geometry.size.width, 330)
            let tileSide = (side - spacing * 4) / 5
            VStack(spacing: spacing) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<5, id: \.self) { col in
                            let cell = GridCell(row: row, col: col)
                            if let index = puzzle.cells.firstIndex(of: cell) {
                                cellButton(index: index, side: tileSide)
                            } else {
                                Color.clear.frame(width: tileSide, height: tileSide)
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 330)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppLanguage.text("Tablero con forma de almohadilla", "Hash-shaped board"))
    }

    private func cellButton(index: Int, side: CGFloat) -> some View {
        let state = feedback(at: index)
        let isSelected = selected == index
        // A letter already in its correct square is settled: swapping it away
        // would undo progress the player has earned. It stays visible and
        // legible, just no longer draggable.
        let isLocked = state == .exact
        return Button {
            guard !isLocked else {
                toast = PZToast(text: AppLanguage.text("Esa letra ya está en su sitio", "That letter is already in place"), kind: .info)
                return
            }
            if let source = selected {
                if source == index {
                    selected = nil
                } else {
                    withAnimation(PZAnim.shuffle) {
                        letters.swapAt(source, index)
                        selected = nil
                    }
                    persist()
                    PZHaptics.tick()
                    if solvedCount == puzzle.words.count { finish() }
                }
            } else {
                selected = index
                PZHaptics.tick()
            }
        } label: {
            Text(String(letters[index]))
                .font(.system(size: min(27, side * 0.45), weight: .heavy, design: .rounded))
                .foregroundStyle(state == .neutral ? PZColor.ink : .white)
                .shadow(color: .black.opacity(state == .neutral ? 0 : 0.3), radius: 0, y: 1)
                .frame(width: side, height: side)
                // Casilla con volumen: neutra apagada; exacta/presente encendida con su color (la exacta con halo).
                .pzVolume(volumeFill(state), glow: state == .exact)
                .overlay {
                    // Solo selección y cursor de teclado: el brillo del volumen sustituye al filete fino.
                    PZRadius.rect(PZRadius.tile)
                        .stroke(isSelected ? PZ.hashtag
                                : keyboardCursor == puzzle.cells[index] ? PZ.hashtag.opacity(0.55)
                                : Color.clear,
                                lineWidth: isSelected ? 3
                                : keyboardCursor == puzzle.cells[index] ? 2 : 1)
                }
                .scaleEffect(isSelected ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: state)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(AppLanguage.text("Letra \(String(letters[index]))", "Letter \(String(letters[index]))"))
        .accessibilityValue(isLocked ? AppLanguage.text("fijada, posición correcta", "locked, correct position")
                            : isSelected ? AppLanguage.text("seleccionada", "selected") : feedbackLabel(state))
        .accessibilityHint(isLocked ? AppLanguage.text("Ya no se puede mover", "This letter cannot be moved")
                           : isSelected ? AppLanguage.text("Toca otra casilla para intercambiar", "Tap another square to swap")
                           : AppLanguage.text("Toca para seleccionar", "Tap to select"))
    }

    private enum CellFeedback { case exact, present, neutral }

    private func feedback(at index: Int) -> CellFeedback {
        let cell = puzzle.cells[index]
        let letter = letters[index]
        guard puzzle.solution[cell] != letter else { return .exact }
        for word in puzzle.words where legitimateYellows(in: word).contains(cell) {
            return .present
        }
        return .neutral
    }

    /// Wordle-style duplicate accounting for one word: exact positions are
    /// consumed first, then misplaced letters consume the remaining counts
    /// from left to right.
    private func legitimateYellows(in word: HashtagPuzzle.Word) -> Set<GridCell> {
        let answer = Array(word.answer)
        let placed = word.cells.map { cell -> Character? in
            guard let index = puzzle.cells.firstIndex(of: cell) else { return nil }
            return letters[index]
        }
        var remaining: [Character: Int] = [:]

        for offset in answer.indices where placed[offset] != answer[offset] {
            remaining[answer[offset], default: 0] += 1
        }

        var yellow = Set<GridCell>()
        for offset in answer.indices {
            guard let letter = placed[offset], letter != answer[offset],
                  remaining[letter, default: 0] > 0 else { continue }
            yellow.insert(word.cells[offset])
            remaining[letter, default: 0] -= 1
        }
        return yellow
    }

    /// Color de la casilla encendida; nil = casilla apagada (neutra).
    private func volumeFill(_ state: CellFeedback) -> Color? {
        switch state {
        case .exact: return PZColor.success
        case .present: return .yellow
        case .neutral: return nil
        }
    }

    private func feedbackLabel(_ state: CellFeedback) -> String {
        switch state {
        case .exact: return AppLanguage.text("posición correcta", "correct position")
        case .present: return AppLanguage.text("pertenece a una palabra de esta casilla", "belongs to a word through this square")
        case .neutral: return AppLanguage.text("no pertenece a la palabra", "does not belong to the word")
        }
    }

    private func persist() {
        progress.setFill(puzzle.id, Dictionary(uniqueKeysWithValues:
            letters.enumerated().map { (String($0.offset), String($0.element)) }))
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .hashtag, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        PZHaptics.success()
        result = PZResult(
            kind: .hashtag,
            didWin: true,
            headline: AppLanguage.text("¡Hashtag completo!", "Hashtag complete!"),
            detail: AppLanguage.text("Has reconstruido las cuatro palabras cruzadas", "You rebuilt all four crossing words"),
            metrics: [(AppLanguage.text("Palabras", "Words"), "4"),
                      (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed)))],
            shareText: AppLanguage.text("NewsRaider Hashtag · 4 palabras · \(PuzzleTiming.clock(TimeInterval(elapsed)))", "NewsRaider Hashtag · 4 words · \(PuzzleTiming.clock(TimeInterval(elapsed)))"))
    }
}



// MARK: - Anygram crossed-word game

/// Rueda de letras. Vive aparte para que la posición del dedo (`dragLocation`, que cambia
/// en cada evento táctil) solo reconstruya la rueda y no todo el juego: antes cada
/// movimiento rehacía el tablero, la lista de palabras y el fondo, y el trazo iba con retraso.
#if DEBUG
private enum AnygramAutoWin { static var used = false }
#endif

private struct AnygramWheel: View {
    let letters: [Character]
    let side: CGFloat
    @Binding var selected: [Int]
    let onSubmit: () -> Void
    @State private var dragLocation: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, side)
            let center = CGPoint(x: side / 2, y: side / 2)
            let radius = side * 0.34
            let positions = letters.indices.map { index in
                let angle = (Double(index) / Double(letters.count)) * Double.pi * 2 - Double.pi / 2
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }

            ZStack {
                // Disco con volumen: degradado radial del color del juego, borde con brillo arriba y sombra.
                Circle()
                    .fill(RadialGradient(colors: [PZ.anygram.opacity(0.30), PZColor.surface],
                                         center: .center, startRadius: 0, endRadius: side * 0.55))
                    .overlay {
                        Circle().stroke(LinearGradient(colors: [.white.opacity(0.18), PZ.anygram.opacity(0.15)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 14, y: 8)

                Path { path in
                    guard let first = selected.first else { return }
                    path.move(to: positions[first])
                    for index in selected.dropFirst() { path.addLine(to: positions[index]) }
                    if let dragLocation { path.addLine(to: dragLocation) }
                }
                .stroke(PZ.anygram, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .opacity(selected.isEmpty ? 0 : 0.65)

                ForEach(letters.indices, id: \.self) { index in
                    let isSelected = selected.contains(index)
                    AnygramWheelLetter(letter: letters[index], selected: isSelected)
                        .position(positions[index])
                        .accessibilityLabel(AppLanguage.text("Letra \(String(letters[index]))", "Letter \(String(letters[index]))"))
                        .accessibilityValue(isSelected ? AppLanguage.text("seleccionada", "selected") : "")
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        guard let index = positions.indices.min(by: {
                            hypot(positions[$0].x - value.location.x, positions[$0].y - value.location.y)
                                < hypot(positions[$1].x - value.location.x, positions[$1].y - value.location.y)
                        }), hypot(positions[index].x - value.location.x, positions[index].y - value.location.y) < 30,
                              !selected.contains(index) else { return }
                        selected.append(index)
                        PZHaptics.tick()
                    }
                    .onEnded { _ in
                        onSubmit()
                        dragLocation = nil
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(AppLanguage.text("Rueda de letras", "Letter wheel"))
            .accessibilityValue(letters.map(String.init).joined(separator: ", "))
        }
        .frame(height: side)
    }
}

/// Casilla del tablero con volumen (ficha): degradado vertical, brillo arriba y sombra. Al descubrirse se llena
/// con el color del juego y la letra entra con un rebote; `delay` hace una ola por filas/columnas.
private struct AnygramTile: View {
    let letter: Character
    let shown: Bool
    let size: CGFloat
    let delay: Double

    var body: some View {
        let shape = PZRadius.rect(PZRadius.tile)
        ZStack {
            shape.fill(LinearGradient(
                colors: shown ? [PZ.anygram.mix(with: .white, by: 0.25), PZ.anygram.mix(with: .black, by: 0.25)]
                              : [Color(light: "2A3350", dark: "2A3350"), Color(light: "1A2031", dark: "1A2031")],
                startPoint: .top, endPoint: .bottom))
            shape.stroke(LinearGradient(colors: [.white.opacity(shown ? 0.45 : 0.14), .clear],
                                        startPoint: .top, endPoint: .bottom), lineWidth: 1)
            Text(shown ? String(letter) : "")
                .font(.system(size: min(22, size * 0.52), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 0, y: 1)
                .scaleEffect(shown ? 1 : 0.4)
                .opacity(shown ? 1 : 0)
        }
        .frame(width: size, height: size)
        .shadow(color: shown ? PZ.anygram.opacity(0.45) : .black.opacity(0.4), radius: shown ? 6 : 2, y: shown ? 0 : 2)
        .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(delay), value: shown)
    }
}

/// Letra de la rueda como ficha en relieve; seleccionada se enciende y crece un poco.
private struct AnygramWheelLetter: View {
    let letter: Character
    let selected: Bool

    var body: some View {
        Text(String(letter))
            .font(.system(size: 23, weight: .heavy, design: .rounded))
            .foregroundStyle(selected ? .white : PZ.anygram.mix(with: .white, by: 0.35))
            .frame(width: 44, height: 44)
            .background {
                Circle().fill(LinearGradient(
                    colors: selected ? [PZ.anygram.mix(with: .white, by: 0.2), PZ.anygram.mix(with: .black, by: 0.2)]
                                     : [Color(light: "323B58", dark: "323B58"), Color(light: "1E2538", dark: "1E2538")],
                    startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                Circle().stroke(LinearGradient(colors: [.white.opacity(selected ? 0.5 : 0.2), .clear],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            }
            .shadow(color: selected ? PZ.anygram.opacity(0.6) : .black.opacity(0.45), radius: selected ? 8 : 3, y: selected ? 0 : 3)
            .scaleEffect(selected ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selected)
    }
}

/// Tablero de Anygram. `Equatable` + `.equatable()`: no se recalcula al seleccionar letras ni con el segundero
/// (antes todo `AnygramGame` se re-evaluaba en cada letra y cada segundo).
private struct AnygramBoard: View, Equatable {
    let rows: Int
    let cols: Int
    let english: Bool
    let maxHeight: CGFloat
    let cells: [GridCell: Character]
    let shown: Set<GridCell>
    let found: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let available = min(geo.size.width, 300)
            let widthTile = min(44, (available - spacing * CGFloat(cols - 1)) / CGFloat(cols))
            let tile = english
                ? min(widthTile, (maxHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows))
                : widthTile
            let width = tile * CGFloat(cols) + spacing * CGFloat(cols - 1)
            let height = tile * CGFloat(rows) + spacing * CGFloat(rows - 1)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<cols, id: \.self) { col in
                            let cell = GridCell(row: row, col: col)
                            if let letter = cells[cell] {
                                AnygramTile(letter: letter, shown: shown.contains(cell), size: tile,
                                            delay: Double(row + col) * 0.045)
                            } else {
                                Color.clear.frame(width: tile, height: tile)
                            }
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: maxHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLanguage.text("Tablero de palabras cruzadas", "Crossed-word board"))
        .accessibilityValue(AppLanguage.text("\(found) de \(total) palabras reveladas", "\(found) of \(total) words revealed"))
    }
}

/// Tira de palabras encontradas: igual que el tablero, solo se recalcula cuando cambian las palabras.
private struct AnygramFoundStrip: View, Equatable {
    let targets: [String]
    let extras: [String]
    let total: Int
    let english: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(AppLanguage.text("TABLERO  \(targets.count)/\(total)", "BOARD  \(targets.count)/\(total)")).pzLabelStyle()
                Spacer()
                Text(AppLanguage.text("OTRAS  \(extras.count)", "EXTRAS  \(extras.count)")).pzLabelStyle()
                // Cada `AnygramGame.extrasPerFreeLetter` extras regalan una letra: muestra cuánto falta.
                Text("· \(extras.count % AnygramGame.extrasPerFreeLetter)/\(AnygramGame.extrasPerFreeLetter)")
                    .pzLabelStyle()
                    .accessibilityLabel(AppLanguage.text(
                        "\(AnygramGame.extrasPerFreeLetter - extras.count % AnygramGame.extrasPerFreeLetter) palabras extra para la próxima letra gratis",
                        "\(AnygramGame.extrasPerFreeLetter - extras.count % AnygramGame.extrasPerFreeLetter) extra words to the next free letter"))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(targets, id: \.self) { word in chip(word, tint: PZ.anygram) }
                    if !targets.isEmpty && !extras.isEmpty { Divider().frame(height: 24) }
                    ForEach(extras, id: \.self) { word in chip(word, tint: PZColor.inkSecondary) }
                    if targets.isEmpty && extras.isEmpty {
                        Text(AppLanguage.text("Las palabras encontradas aparecerán aquí", "Your found words will appear here"))
                            .font(PZFont.caption)
                            .foregroundStyle(PZColor.inkSecondary)
                    }
                }
            }
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PZColor.surface, in: PZRadius.rect(PZRadius.card))
    }

    private func chip(_ word: String, tint: Color) -> some View {
        Group {
            if english {
                // System dictionaries follow installed OS dictionaries, not the in-app language.
                Text(word).font(PZFont.caption).foregroundStyle(tint)
            } else {
                PZDefinableWord(word: word, font: PZFont.caption, tint: tint)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(PZColor.wash(tint), in: Capsule())
    }
}

struct AnygramGame: View {
    /// Cada tantas palabras extra (válidas, fuera del tablero) se revela gratis una letra.
    static let extrasPerFreeLetter = 3
    let puzzle: AnygramPuzzle
    /// Calculado una vez: `puzzle.boardCells` reconstruye el diccionario entero en cada acceso.
    private let boardCells: [GridCell: Character]
    init(puzzle: AnygramPuzzle) {
        self.puzzle = puzzle
        self.boardCells = puzzle.boardCells
    }
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var selected: [Int] = []
    @State private var found = Set<String>()
    @State private var extraWords = Set<String>()
    @State private var hintedCells = Set<GridCell>()
    @State private var elapsed = 0
    @State private var finished = false
    @State private var toast: PZToast?
    @State private var result: PZResult?
    @FocusState private var hardwareKeyboardFocused: Bool
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var candidate: String { String(selected.map { puzzle.letters[$0] }) }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 760
            VStack(spacing: compact ? 5 : 8) {
                header
                crosswordBoard(maxHeight: compact ? 190 : 220)

                // Keep the board independently readable, then use the spare
                // vertical space to lower the input wheel and found-word strip.
                // This avoids the wheel visually colliding with taller 7–8 row
                // boards and removes the unused band at the bottom on iPhone.
                Spacer(minLength: compact ? 12 : 18)

                Text(candidate.isEmpty ? AppLanguage.text("Desliza para formar una palabra", "Swipe to form a word") : candidate)
                    .font(candidate.isEmpty ? PZFont.body : PZFont.title)
                    .foregroundStyle(candidate.isEmpty ? PZColor.inkTertiary : PZ.anygram)
                    .lineLimit(1)
                    .frame(height: compact ? 28 : 34)
                    .accessibilityLabel(candidate.isEmpty ? AppLanguage.text("Ninguna letra seleccionada", "No letters selected") : candidate)

                wheel(side: compact ? 176 : 196)
                foundWords
            }
            .padding(.horizontal, PZSpace.screenH)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .background(PZGameBackdrop(color: PZ.anygram))
        .background {
            PZHardwareKeyCapture { handleCapturedHardwareKey($0) }
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        .focusable(interactions: .activate)
        .focused($hardwareKeyboardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handleHardwareKey(press)
        }
        .simultaneousGesture(TapGesture().onEnded { claimHardwareKeyboardFocus() })
        .navigationTitle("Anygram")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            let savedWords = progress.found(puzzle.id)
            found = Set(savedWords.filter { puzzle.answers.contains($0) })
            extraWords = Set(savedWords.compactMap { value in
                value.hasPrefix("extra:") ? String(value.dropFirst(6)) : nil
            })
            hintedCells = Set(progress.fill(puzzle.id).keys.compactMap { key in
                let parts = key.split(separator: ",").compactMap { Int($0) }
                guard parts.count == 2 else { return nil }
                return GridCell(row: parts[0], col: parts[1])
            })
            claimHardwareKeyboardFocus()
            #if DEBUG
            // Ayuda de verificación: NR_AUTOWIN=1 termina la partida al abrirla para llegar a la hoja de resultado.
            if ProcessInfo.processInfo.environment["NR_AUTOWIN"] == "1", !AnygramAutoWin.used {
                AnygramAutoWin.used = true
                Task { @MainActor in try? await Task.sleep(for: .seconds(1)); finish() }
            }
            // Ayuda para capturas: NR_ANYFOUND=n descubre n palabras (sin guardar) para ver tablero y animación.
            if let n = Int(ProcessInfo.processInfo.environment["NR_ANYFOUND"] ?? "") {
                Task { @MainActor in
                    for word in puzzle.answers.prefix(n) {
                        try? await Task.sleep(for: .seconds(0.8))
                        found.insert(word)
                    }
                }
            }
            #endif
        }
        .onReceive(tick) { _ in
            guard !finished else { return }
            elapsed += 1
            if elapsed % 5 == 0 { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(item: $result) { PZResultSheet(result: $0) }
        .pzToast($toast)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { hintsMenu }
        }
        .pzRules(.anygram)
    }

    private var header: some View {
        HStack {
            PZStat(label: AppLanguage.text("ENCONTRADAS", "FOUND"), value: "\(found.count)/\(puzzle.answers.count)")
            Spacer()
            PZStat(label: AppLanguage.text("TIEMPO", "TIME"), value: PuzzleTiming.clock(TimeInterval(elapsed)), alignment: .trailing)
        }
    }

    private func crosswordBoard(maxHeight: CGFloat) -> some View {
        AnygramBoard(rows: puzzle.boardRows, cols: puzzle.boardCols, english: puzzle.id.hasPrefix("en-"),
                     maxHeight: maxHeight, cells: boardCells, shown: revealedCells.union(hintedCells),
                     found: found.count, total: puzzle.answers.count)
            .equatable()
    }

    private var revealedCells: Set<GridCell> {
        var set = Set<GridCell>()
        for entry in puzzle.entries where found.contains(entry.word) { set.formUnion(entry.cells) }
        return set
    }

    /// The board starts completely blank: only found words and paid hints show
    /// letters, so no answer is given away for free.
    private func isHint(_ cell: GridCell) -> Bool {
        hintedCells.contains(cell)
    }

    private var nextHiddenCell: GridCell? {
        let revealed = revealedCells
        return puzzle.entries
            .filter { !found.contains($0.word) }
            .flatMap(\.cells)
            .first { !isHint($0) && !revealed.contains($0) }
    }

    private var nextHiddenEntry: AnygramPuzzle.Entry? {
        puzzle.entries.first { !found.contains($0.word) }
    }

    private var hintsMenu: some View {
        Menu {
            Button {
                revealLetter()
            } label: {
                Label(AppLanguage.text("Revelar letra · +30 s", "Reveal a letter · +30 s"), systemImage: "character.cursor.ibeam")
            }
            .disabled(nextHiddenCell == nil)

            Button {
                revealWord()
            } label: {
                Label(AppLanguage.text("Revelar palabra · +90 s", "Reveal a word · +90 s"), systemImage: "text.badge.checkmark")
            }
            .disabled(nextHiddenEntry == nil)
        } label: {
            Image(systemName: "lightbulb")
                .foregroundStyle(PZ.anygram)
        }
        .accessibilityLabel(AppLanguage.text("Pistas", "Hints"))
        .accessibilityHint(AppLanguage.text("Las pistas añaden una penalización al tiempo", "Hints add a time penalty"))
    }

    private func wheel(side: CGFloat) -> some View {
        AnygramWheel(letters: puzzle.letters, side: side, selected: $selected, onSubmit: submit)
    }

    private var foundWords: some View {
        AnygramFoundStrip(targets: puzzle.answers.filter(found.contains), extras: extraWords.sorted(),
                          total: puzzle.answers.count, english: puzzle.id.hasPrefix("en-"))
            .equatable()
    }

    private func persistWords() {
        let targets = puzzle.answers.filter(found.contains)
        let extras = extraWords.sorted().map { "extra:" + $0 }
        progress.setFound(puzzle.id, targets + extras)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func handleHardwareKey(_ press: KeyPress) -> KeyPress.Result {
        guard !finished else { return .ignored }
        if press.key == .delete {
            if !selected.isEmpty { selected.removeLast(); PZHaptics.tick() }
            return .handled
        }
        if press.key == .return {
            submit()
            return .handled
        }
        let text = press.characters.uppercased()
        guard text.count == 1, let letter = text.first,
              let index = puzzle.letters.indices.first(where: {
                  puzzle.letters[$0] == letter && !selected.contains($0)
              }) else { return .ignored }
        selected.append(index)
        PZHaptics.tick()
        return .handled
    }

    private func handleCapturedHardwareKey(_ key: PZHardwareKey) -> Bool {
        guard !finished else { return false }
        switch key.unmodifiedInput {
        case UIKeyCommand.inputDelete:
            if !selected.isEmpty { selected.removeLast(); PZHaptics.tick() }
            return true
        case "\r", "\n":
            submit()
            return true
        default:
            let text = key.unmodifiedInput.uppercased()
            guard text.count == 1, let letter = text.first,
                  let index = puzzle.letters.indices.first(where: {
                      puzzle.letters[$0] == letter && !selected.contains($0)
                  }) else { return false }
            selected.append(index)
            PZHaptics.tick()
            return true
        }
    }

    /// Wheel buttons can become the focused element. Move focus back to this
    /// input surface after their action so letter keys keep working on iPad.
    private func claimHardwareKeyboardFocus() {
        Task { @MainActor in
            await Task.yield()
            hardwareKeyboardFocused = true
        }
    }

    /// Revela la siguiente casilla oculta y la guarda (en `fill`, como las pistas pagadas).
    /// Devuelve false si ya no queda ninguna.
    @discardableResult
    private func revealNextCell() -> Bool {
        guard let cell = nextHiddenCell else { return false }
        withAnimation(PZAnim.reveal) { _ = hintedCells.insert(cell) }
        progress.setFill(puzzle.id, Dictionary(uniqueKeysWithValues: hintedCells.map {
            ("\($0.row),\($0.col)", String(boardCells[$0] ?? " "))
        }))
        return true
    }

    private func revealLetter() {
        guard revealNextCell() else { return }
        elapsed += 30
        progress.setElapsed(puzzle.id, elapsed)
        toast = PZToast(text: AppLanguage.text("Letra revelada · +30 s", "Letter revealed · +30 s"), kind: .info)
        PZHaptics.warning()
    }

    private func revealWord() {
        guard let entry = nextHiddenEntry else { return }
        elapsed += 90
        withAnimation(PZAnim.reveal) { _ = found.insert(entry.word) }
        progress.setElapsed(puzzle.id, elapsed)
        persistWords()
        toast = PZToast(text: AppLanguage.text("\(entry.word) revelada · +90 s", "\(entry.word) revealed · +90 s"), kind: .info)
        PZHaptics.warning()
        if found.count == puzzle.answers.count { finish() }
    }

    private func submit() {
        defer {
            withAnimation(PZAnim.reveal) {
                selected.removeAll()
            }
        }
        guard selected.count >= 3 else {
            if !selected.isEmpty {
                toast = PZToast(text: AppLanguage.text("Las palabras deben tener al menos 3 letras", "Words must have at least 3 letters"), kind: .error)
                PZHaptics.error()
            }
            return
        }
        if puzzle.answers.contains(candidate) {
            guard !found.contains(candidate) else {
                toast = PZToast(text: AppLanguage.text("Ya habías encontrado \(candidate)", "You already found \(candidate)"), kind: .info)
                PZHaptics.warning()
                return
            }
            found.insert(candidate)
            persistWords()
            PZHaptics.success()
            if found.count == puzzle.answers.count { finish() }
            return
        }

        guard (puzzle.id.hasPrefix("en-") ? EnglishPuzzleLexicon.wordSet : PuzzleLexicon.wordSet).contains(candidate) else {
            toast = PZToast(text: AppLanguage.text("«\(candidate)» no está en el diccionario", "“\(candidate)” is not in this curated dictionary"), kind: .error)
            PZHaptics.error()
            return
        }
        guard !extraWords.contains(candidate) else {
            toast = PZToast(text: AppLanguage.text("Ya habías encontrado \(candidate)", "You already found \(candidate)"), kind: .info)
            PZHaptics.warning()
            return
        }
        extraWords.insert(candidate)
        persistWords()
        // Solo se regala en el momento de llegar a 3, 6, 9… extras: al reabrir la partida no se repite,
        // porque la casilla ya quedó guardada en `fill`.
        if extraWords.count % Self.extrasPerFreeLetter == 0, revealNextCell() {
            toast = PZToast(text: AppLanguage.text("Palabra extra: \(candidate) · ¡letra gratis!", "Extra word: \(candidate) · free letter!"), kind: .success)
        } else {
            toast = PZToast(text: AppLanguage.text("Palabra extra: \(candidate)", "Extra word: \(candidate)"), kind: .success)
        }
        PZHaptics.success()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(max(5, elapsed)), kind: .anygram, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        result = PZResult(
            kind: .anygram,
            didWin: true,
            headline: AppLanguage.text("¡Tablero completo!", "Board complete!"),
            detail: AppLanguage.text("Has revelado todas las palabras cruzadas", "You revealed all the crossing words"),
            metrics: [(AppLanguage.text("Palabras", "Words"), "\(found.count)"),
                      (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed)))],
            shareText: AppLanguage.text("NewsRaider Anygram · \(found.count) palabras · \(PuzzleTiming.clock(TimeInterval(elapsed)))", "NewsRaider Anygram · \(found.count) words · \(PuzzleTiming.clock(TimeInterval(elapsed)))"))
    }
}
#endif
