#if os(iOS)
//
//  MurdleGame.swift — News Raider
//  Procedural logic-grid murder mysteries.
//

import SwiftUI
import Combine

struct MurdlePuzzle: Identifiable, Sendable, Hashable {
    enum Difficulty: Int, CaseIterable, Sendable, Hashable {
        // A 3x3 grid is not a deduction puzzle: with three suspects, three
        // places and three weapons the clues leave almost nothing to work out,
        // so it played as filler rather than a case. Four is the smallest
        // board that needs real elimination.
        //
        // Six is the ceiling, not a choice: every theme ships six places and
        // six weapons, so a seventh column would silently generate a smaller
        // grid than requested.
        case easy = 4, medium = 5, hard = 6
        var title: String { title(language: AppLanguage.current) }
        func title(language: PuzzleLanguage) -> String {
            switch self {
            case .easy: language == .english ? "Easy" : "Fácil"
            case .medium: language == .english ? "Medium" : "Medio"
            case .hard: language == .english ? "Hard" : "Difícil"
            }
        }
    }
    enum CaseKind: String, Sendable, Hashable { case murder, theft }
    enum WeaponKind: String, Sendable, Hashable { case firearm, blade, poison, ligature, blunt }
    struct Weapon: Sendable, Hashable { let name: String; let kind: WeaponKind }
    struct Place: Sendable, Hashable { let name: String; let phrase: String }
    struct Theme: Sendable {
        let id, label: String
        let kind: CaseKind
        let titles, victims, suspects: [String]
        let places: [Place]
        let weapons: [Weapon]
        let intro: String
    }
    struct Assignment: Sendable, Hashable { let suspect, place, weapon: String }

    let id: String
    var language: PuzzleLanguage = .spanish
    let difficulty: Difficulty
    let caseKind: CaseKind
    let themeLabel, title, intro, deathReport, crimePlace: String
    let suspects, places, weapons, clues: [String]
    let assignments: [Assignment]
    var culprit: Assignment { assignments.first { $0.place == crimePlace }! }

    static func generate(seed: UInt64, difficulty: Difficulty, language: PuzzleLanguage = .spanish) -> MurdlePuzzle {
        var rng = SeededGenerator(seed: seed ^ 0x4D55_5244_4C45)
        let bank = language == .english ? englishThemes : themes
        let theme = bank[rng.int(bank.count)]
        // `prefix` truncates silently, so a theme with fewer entries than the
        // requested level would quietly produce a smaller, easier grid than
        // the one the player picked. Clamp deliberately instead.
        let n = min(difficulty.rawValue,
                    min(theme.suspects.count, min(theme.places.count, theme.weapons.count)))
        let suspects = Array(rng.shuffled(theme.suspects).prefix(n))
        let pickedPlaces = Array(rng.shuffled(theme.places).prefix(n))
        let pickedWeapons = Array(rng.shuffled(theme.weapons).prefix(n))
        let placeOrder = rng.shuffled(pickedPlaces)
        let weaponOrder = rng.shuffled(pickedWeapons)
        let assignments = suspects.indices.map {
            Assignment(suspect: suspects[$0], place: placeOrder[$0].name, weapon: weaponOrder[$0].name)
        }
        let crimePlace = pickedPlaces[rng.int(n)].name
        let culprit = assignments.first { $0.place == crimePlace }!
        let phrase: (String) -> String = { name in pickedPlaces.first { $0.name == name }?.phrase ?? name.lowercased() }
        let weapon = pickedWeapons.first { $0.name == culprit.weapon }!
        var clues: [String] = []
        // Never name or directly associate the murderer. The player must infer
        // the remaining suspect by elimination from the other N−1 relations.
        let innocents = assignments.filter { $0.suspect != culprit.suspect }
        for a in rng.shuffled(innocents) {
            clues.append(text("\(a.suspect) estaba en \(phrase(a.place)).", "\(a.suspect) was in \(phrase(a.place)).", language: language))
        }
        // Do the same with the murder location and weapon: relate every other
        // place, leaving the murder weapon to be inferred by elimination.
        let safePlaces = assignments.filter { $0.place != crimePlace }
        for a in rng.shuffled(safePlaces) {
            clues.append(text("La persona de \(phrase(a.place)) llevaba \(a.weapon.lowercased()).", "The person in \(phrase(a.place)) carried the \(a.weapon.lowercased()).", language: language))
        }
        for (i, a) in rng.shuffled(innocents).prefix(max(2, n - 2)).enumerated() {
            if i.isMultiple(of: 2) {
                let wrong = pickedPlaces.first { $0.name != a.place && $0.name != crimePlace }
                    ?? pickedPlaces.first { $0.name != a.place }!
                clues.append(text("\(a.suspect) no estuvo en \(wrong.phrase).", "\(a.suspect) was not in \(wrong.phrase).", language: language))
            } else {
                let wrong = pickedWeapons.first { $0.name != a.weapon && $0.name != culprit.weapon }
                    ?? pickedWeapons.first { $0.name != a.weapon }!
                clues.append(text("\(a.suspect) no llevaba \(wrong.name.lowercased()).", "\(a.suspect) did not carry the \(wrong.name.lowercased()).", language: language))
            }
        }
        let victim = theme.victims[rng.int(theme.victims.count)]
        let intro = theme.intro.replacingOccurrences(of: "{victim}", with: victim)
        return .init(id: (language == .english ? "en-" : "") + "murdle-\(seed)", language: language, difficulty: difficulty, caseKind: theme.kind,
                     themeLabel: theme.label, title: theme.titles[rng.int(theme.titles.count)], intro: intro,
                     deathReport: theme.kind == .murder ? report(for: weapon, language: language) : text("El objeto sustraído fue \(weapon.name.lowercased()).", "The stolen item was the \(weapon.name.lowercased()).", language: language),
                     crimePlace: crimePlace,
                     suspects: suspects, places: pickedPlaces.map(\.name), weapons: pickedWeapons.map(\.name),
                     clues: rng.shuffled(clues), assignments: assignments)
    }

    private static func report(for weapon: Weapon, language: PuzzleLanguage) -> String {
        switch weapon.kind {
        case .firearm: text("La víctima murió por una herida de bala.", "The victim died from a gunshot wound.", language: language)
        case .blade: text("La víctima murió por una herida de arma blanca.", "The victim died from a stab wound.", language: language)
        case .poison: text("El examen preliminar confirmó un envenenamiento.", "The preliminary examination confirmed poisoning.", language: language)
        case .ligature: text("La víctima murió por ahorcamiento.", "The victim died by hanging.", language: language)
        case .blunt: text("La víctima murió a causa de un fuerte golpe.", "The victim died from a heavy blow.", language: language)
        }
    }

    private static func text(_ es: String, _ en: String, language: PuzzleLanguage) -> String {
        language == .english ? en : es
    }

    private static let commonSuspects = ["Adriana","Bruno","Carmen","Diego","Elena","Félix","Irene","Mateo"]
    private static func w(_ name: String, _ kind: WeaponKind) -> Weapon { .init(name: name, kind: kind) }
    private static func p(_ name: String, _ phrase: String) -> Place { .init(name: name, phrase: phrase) }
    static let themes: [Theme] = [
        .init(id:"mansion",label:"EN LA MANSIÓN",kind:.murder,titles:["Las cortinas cerradas","El reloj de medianoche","La herencia escarlata"],victims:["El dueño de la mansión ha sido hallado sin vida.","El abogado de la familia ha sido hallado sin vida."],suspects:commonSuspects,places:[p("Biblioteca","la biblioteca"),p("Salón","el salón"),p("Invernadero","el invernadero"),p("Bodega","la bodega"),p("Comedor","el comedor"),p("Dormitorio","el dormitorio")],weapons:[w("Candelabro",.blunt),w("Cuerda",.ligature),w("Abrecartas",.blade),w("Pistola",.firearm),w("Veneno",.poison),w("Cuchillo",.blade)],intro:"{victim} El asesinato ocurrió durante una recepción privada."),
        .init(id:"orient",label:"EN EL ORIENT EXPRESS",kind:.murder,titles:["El expreso de medianoche","El billete rasgado","La frontera de nieve"],victims:["El jefe del tren ha sido hallado sin vida.","El revisor nocturno ha sido hallado sin vida."],suspects:commonSuspects,places:[p("Coche comedor","el coche comedor"),p("Cabina privada","la cabina privada"),p("Equipajes","el vagón de equipajes"),p("Coche cama","el coche cama"),p("Plataforma","la plataforma trasera"),p("Conducción","la cabina del conductor")],weapons:[w("Cuchillo",.blade),w("Pistola",.firearm),w("Veneno",.poison),w("Cinturón",.ligature),w("Llave inglesa",.blunt),w("Cuerda",.ligature)],intro:"{victim} El Orient Express atravesaba Europa."),
        .init(id:"nilo",label:"EN EL CRUCERO POR EL NILO",kind:.murder,titles:["La sombra de Luxor","El secreto del camarote","La noche de Asuán"],victims:["El arqueólogo de la expedición ha sido hallado sin vida.","El capitán del barco ha sido hallado sin vida."],suspects:commonSuspects,places:[p("Proa","la cubierta de proa"),p("Camarote real","el camarote real"),p("Salón","el salón panorámico"),p("Mapas","la sala de mapas"),p("Comedor","el comedor"),p("Bodega","la bodega de carga")],weapons:[w("Cuchillo ceremonial",.blade),w("Pistola",.firearm),w("Veneno",.poison),w("Cuerda náutica",.ligature),w("Estatuilla",.blunt),w("Bastón",.blunt)],intro:"{victim} El barco navegaba por el Nilo."),
        .init(id:"luna",label:"EN LA BASE LUNAR",kind:.murder,titles:["La noche de Mare Tranquillitatis","El módulo sellado","La sombra del cráter"],victims:["El comandante de la base ha sido hallado sin vida.","El geólogo de la misión ha sido hallado sin vida."],suspects:["Vega","Elías","Nadia","Orión","Mara","León"],places:[p("Mando","el módulo de mando"),p("Laboratorio","el laboratorio lunar"),p("Invernadero","el invernadero hidropónico"),p("Esclusa","la esclusa"),p("Observatorio","el observatorio"),p("Róveres","el garaje de róveres")],weapons:[w("Cuchillo de emergencia",.blade),w("Pistola",.firearm),w("Veneno",.poison),w("Cable",.ligature),w("Llave de esclusa",.blunt),w("Martillo geológico",.blunt)],intro:"{victim} La base Selene permanecía aislada de la Tierra."),
        .init(id:"teatro",label:"EN EL TEATRO",kind:.murder,titles:["El último aplauso","La máscara rota","El telón carmesí"],victims:["El director de escena ha sido hallado sin vida.","El productor de la obra ha sido hallado sin vida."],suspects:commonSuspects,places:[p("Escenario","el escenario"),p("Camerino","el camerino"),p("Tramoya","la tramoya"),p("Butacas","el patio de butacas"),p("Ensayo","la sala de ensayo"),p("Taquilla","la taquilla")],weapons:[w("Cuchillo",.blade),w("Cuerda de telón",.ligature),w("Pistola",.firearm),w("Veneno",.poison),w("Bastón",.blunt),w("Foco",.blunt)],intro:"{victim} Faltaban minutos para levantarse el telón."),
        .init(id:"museo-robo",label:"ROBO EN EL MUSEO",kind:.theft,titles:["La vitrina vacía","El ídolo desaparecido","El marco sin lienzo"],victims:["Una pieza irreemplazable ha desaparecido.","La alarma de una galería se activó de madrugada."],suspects:["Nora","Samuel","Clara","Diego","Alicia","Tomás"],places:[p("Galería central","la galería central"),p("Almacén","el almacén"),p("Taller","el taller"),p("Sala egipcia","la sala egipcia"),p("Patio","el patio de esculturas"),p("Archivo","el archivo del museo")],weapons:[w("Ídolo de oro",.blunt),w("Collar antiguo",.blunt),w("Lienzo flamenco",.blunt),w("Sello real",.blunt),w("Máscara funeraria",.blunt),w("Moneda imperial",.blunt)],intro:"{victim} El robo se cometió sin dejar señales de entrada forzada."),
        .init(id:"joyeria",label:"ROBO EN LA JOYERÍA",kind:.theft,titles:["El diamante de medianoche","La caja fuerte abierta","El collar de la duquesa"],victims:["La pieza principal de la exposición ha desaparecido.","La caja fuerte fue abierta durante el cambio de turno."],suspects:["Valeria","Martín","Sofía","Gabriel","Olivia","Álex"],places:[p("Escaparate","el escaparate principal"),p("Caja fuerte","la sala de la caja fuerte"),p("Taller","el taller de orfebrería"),p("Despacho","el despacho privado"),p("Almacén","el almacén"),p("Galería","la galería de clientes")],weapons:[w("Diamante azul",.blunt),w("Collar de esmeraldas",.blunt),w("Tiara de rubíes",.blunt),w("Reloj de platino",.blunt),w("Broche imperial",.blunt),w("Anillo de zafiro",.blunt)],intro:"{victim} Solo seis personas conocían los códigos de seguridad."),
        .init(id:"comisaria",label:"ROBO EN LA COMISARÍA",kind:.theft,titles:["La prueba desaparecida","El precinto roto","El expediente 47"],victims:["Una prueba crucial ha desaparecido del depósito.","Un armario de evidencias apareció abierto."],suspects:["Laura","Andrés","Mónica","Pablo","Sara","Víctor"],places:[p("Evidencias","el depósito de evidencias"),p("Interrogatorios","la sala de interrogatorios"),p("Archivo","el archivo central"),p("Laboratorio","el laboratorio forense"),p("Garaje","el garaje policial"),p("Despacho","el despacho del inspector")],weapons:[w("Teléfono intervenido",.blunt),w("Sobre de documentos",.blunt),w("Memoria USB",.blunt),w("Arma precintada",.blunt),w("Muestra forense",.blunt),w("Cuaderno de pruebas",.blunt)],intro:"{victim} El sistema registró actividad dentro del edificio." )
    ]

    // Same ordered entries as Spanish: localization never changes the generated solution.
    static let englishThemes: [Theme] = [
        .init(id:"mansion",label:"AT THE MANSION",kind:.murder,titles:["The Closed Curtains","The Midnight Clock","The Scarlet Inheritance"],victims:["The mansion owner has been found dead.","The family lawyer has been found dead."],suspects:commonSuspects,places:[p("Library","the library"),p("Lounge","the lounge"),p("Greenhouse","the greenhouse"),p("Cellar","the cellar"),p("Dining Room","the dining room"),p("Bedroom","the bedroom")],weapons:[w("Candlestick",.blunt),w("Rope",.ligature),w("Letter Opener",.blade),w("Pistol",.firearm),w("Poison",.poison),w("Knife",.blade)],intro:"{victim} The murder took place during a private reception."),
        .init(id:"orient",label:"ON THE ORIENT EXPRESS",kind:.murder,titles:["The Midnight Express","The Torn Ticket","The Snowy Border"],victims:["The train manager has been found dead.","The night conductor has been found dead."],suspects:commonSuspects,places:[p("Dining Car","the dining car"),p("Private Cabin","the private cabin"),p("Luggage Car","the luggage car"),p("Sleeping Car","the sleeping car"),p("Platform","the rear platform"),p("Driver's Cab","the driver's cab")],weapons:[w("Knife",.blade),w("Pistol",.firearm),w("Poison",.poison),w("Belt",.ligature),w("Wrench",.blunt),w("Rope",.ligature)],intro:"{victim} The Orient Express was crossing Europe."),
        .init(id:"nilo",label:"ON THE NILE CRUISE",kind:.murder,titles:["The Shadow of Luxor","The Cabin Secret","The Night in Aswan"],victims:["The expedition archaeologist has been found dead.","The ship's captain has been found dead."],suspects:commonSuspects,places:[p("Bow","the bow deck"),p("Royal Cabin","the royal cabin"),p("Lounge","the panoramic lounge"),p("Chart Room","the chart room"),p("Dining Room","the dining room"),p("Cellar","the cargo hold")],weapons:[w("Ceremonial Knife",.blade),w("Pistol",.firearm),w("Poison",.poison),w("Nautical Rope",.ligature),w("Statuette",.blunt),w("Walking Stick",.blunt)],intro:"{victim} The ship was sailing along the Nile."),
        .init(id:"luna",label:"AT THE MOON BASE",kind:.murder,titles:["Night at Mare Tranquillitatis","The Sealed Module","The Crater Shadow"],victims:["The base commander has been found dead.","The mission geologist has been found dead."],suspects:["Vega","Elías","Nadia","Orión","Mara","León"],places:[p("Command Module","the command module"),p("Laboratory","the lunar laboratory"),p("Greenhouse","the hydroponic greenhouse"),p("Airlock","the airlock"),p("Observatory","the observatory"),p("Rover Garage","the rover garage")],weapons:[w("Emergency Knife",.blade),w("Pistol",.firearm),w("Poison",.poison),w("Cable",.ligature),w("Airlock Wrench",.blunt),w("Geology Hammer",.blunt)],intro:"{victim} Selene Base was cut off from Earth."),
        .init(id:"teatro",label:"AT THE THEATRE",kind:.murder,titles:["The Last Applause","The Broken Mask","The Crimson Curtain"],victims:["The stage director has been found dead.","The play's producer has been found dead."],suspects:commonSuspects,places:[p("Stage","the stage"),p("Dressing Room","the dressing room"),p("Backstage","the backstage area"),p("Auditorium","the auditorium"),p("Rehearsal Room","the rehearsal room"),p("Box Office","the box office")],weapons:[w("Knife",.blade),w("Curtain Rope",.ligature),w("Pistol",.firearm),w("Poison",.poison),w("Walking Stick",.blunt),w("Spotlight",.blunt)],intro:"{victim} The curtain was due to rise in minutes."),
        .init(id:"museo-robo",label:"THEFT AT THE MUSEUM",kind:.theft,titles:["The Empty Display Case","The Missing Idol","The Empty Frame"],victims:["An irreplaceable artefact has disappeared.","A gallery alarm went off before dawn."],suspects:["Nora","Samuel","Clara","Diego","Alicia","Tomás"],places:[p("Main Gallery","the main gallery"),p("Storeroom","the storeroom"),p("Workshop","the workshop"),p("Egyptian Room","the Egyptian room"),p("Courtyard","the sculpture courtyard"),p("Archive","the museum archive")],weapons:[w("Golden Idol",.blunt),w("Ancient Necklace",.blunt),w("Flemish Painting",.blunt),w("Royal Seal",.blunt),w("Funerary Mask",.blunt),w("Imperial Coin",.blunt)],intro:"{victim} There were no signs of forced entry."),
        .init(id:"joyeria",label:"THEFT AT THE JEWELLER'S",kind:.theft,titles:["The Midnight Diamond","The Open Safe","The Duchess's Necklace"],victims:["The exhibition's centrepiece has disappeared.","The safe was opened during the shift change."],suspects:["Valeria","Martín","Sofía","Gabriel","Olivia","Álex"],places:[p("Display Window","the main display window"),p("Safe Room","the safe room"),p("Workshop","the goldsmith's workshop"),p("Office","the private office"),p("Storeroom","the storeroom"),p("Customer Gallery","the customer gallery")],weapons:[w("Blue Diamond",.blunt),w("Emerald Necklace",.blunt),w("Ruby Tiara",.blunt),w("Platinum Watch",.blunt),w("Imperial Brooch",.blunt),w("Sapphire Ring",.blunt)],intro:"{victim} Only six people knew the security codes."),
        .init(id:"comisaria",label:"THEFT AT THE POLICE STATION",kind:.theft,titles:["The Missing Evidence","The Broken Seal","Case File 47"],victims:["Crucial evidence has disappeared from storage.","An evidence cabinet was found open."],suspects:["Laura","Andrés","Mónica","Pablo","Sara","Víctor"],places:[p("Evidence Room","the evidence store"),p("Interview Room","the interview room"),p("Archive","the central archive"),p("Laboratory","the forensic laboratory"),p("Garage","the police garage"),p("Office","the inspector's office")],weapons:[w("Seized Phone",.blunt),w("Document Envelope",.blunt),w("USB Drive",.blunt),w("Sealed Weapon",.blunt),w("Forensic Sample",.blunt),w("Evidence Notebook",.blunt)],intro:"{victim} The system recorded activity inside the building." )
    ]
}

enum MurdleMark: Int, Equatable { case unknown, excluded, confirmed }

struct MurdleGame: View {
    private func t(_ es: String, _ en: String) -> String { puzzle.language == .english ? en : es }
    let puzzle: MurdlePuzzle
    @ObservedObject private var progress = PuzzleProgress.shared
    @State private var marks: [String:MurdleMark] = [:]
    @State private var elapsed = 0
    @State private var result: PZResult?
    @State private var selectedSuspect = ""
    @State private var selectedPlace = ""
    @State private var selectedWeapon = ""
    @State private var matrix = 0
    @State private var toast: PZToast?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > 700 {
                HStack(alignment:.top,spacing:PZSpace.xl) { ScrollView { story.padding() }.frame(width:geo.size.width*0.38); ScrollView { notebook.padding() } }
            } else { ScrollView { VStack(spacing:PZSpace.lg) { story; notebook }.padding(PZSpace.screenH) } }
        }
        .background(PZGameBackdrop(color: PZ.murdle)).navigationTitle("Murdle").navigationBarTitleDisplayMode(.inline)
        .onAppear { elapsed=progress.elapsed(puzzle.id); loadMarks() }
        .onReceive(tick) { _ in elapsed += 1; if elapsed%5==0 { progress.setElapsed(puzzle.id,elapsed) } }
        .sheet(item:$result) { PZResultSheet(result:$0) }.pzToast($toast).pzRules(.murdle)
    }

    private var story: some View { VStack(alignment:.leading,spacing:PZSpace.md) {
        Text("\(puzzle.themeLabel) · \(puzzle.difficulty.title(language: puzzle.language).uppercased())").pzEyebrowStyle(PZ.murdle)
        Text(puzzle.title).font(PZFont.display)
        Text(puzzle.caseKind == .murder
             ? t("\(puzzle.intro) La investigación confirmó que el asesinato ocurrió en \(puzzle.crimePlace.lowercased()).", "\(puzzle.intro) The investigation confirmed that the murder took place in the \(puzzle.crimePlace.lowercased()).")
             : t("\(puzzle.intro) \(puzzle.deathReport) La investigación confirmó que el robo se cometió en \(puzzle.crimePlace.lowercased()).", "\(puzzle.intro) \(puzzle.deathReport) The investigation confirmed that the theft took place in the \(puzzle.crimePlace.lowercased())."))
            .font(PZFont.body)
        HStack { PZStat(label:t("TIEMPO", "TIME"),value:PuzzleTiming.clock(TimeInterval(elapsed)));Spacer();PZStat(label:t("MARCAS", "MARKS"),value:"\(marks.values.filter{$0 != .unknown}.count)",alignment:.trailing) }
        VStack(alignment:.leading,spacing:PZSpace.sm) { Text(t("LAS PISTAS", "THE CLUES")).pzLabelStyle(); ForEach(Array(puzzle.clues.enumerated()),id:\.offset) { i,c in Text("\(i+1).  \(c)").font(PZFont.body); if i<puzzle.clues.count-1 { Divider() } } }.padding(PZSpace.lg).background(PZColor.surface,in:PZRadius.rect(PZRadius.card))
    }}

    private var notebook: some View { VStack(spacing:PZSpace.md) {
        Picker(t("Matriz", "Grid"),selection:$matrix) { Text(t("Persona/Lugar", "Person/Place")).tag(0);Text(t("Persona/Objeto", "Person/Item")).tag(1);Text(t("Lugar/Objeto", "Place/Item")).tag(2) }.pickerStyle(.segmented)
        logicGrid
        VStack(spacing:PZSpace.sm) { selection(puzzle.caseKind == .murder ? t("Responsable", "Culprit") : t("Ladrón", "Thief"),values:puzzle.suspects,value:$selectedSuspect);selection(t("Lugar", "Place"),values:puzzle.places,value:$selectedPlace);selection(puzzle.caseKind == .murder ? t("Objeto", "Item") : t("Pieza robada", "Stolen item"),values:puzzle.weapons,value:$selectedWeapon); Button(t("Resolver el caso", "Solve the case")) { accuse() }.buttonStyle(PZButton(filled:true,tint:PZ.murdle)) }.padding(PZSpace.lg).background(PZColor.surface,in:PZRadius.rect(PZRadius.card))
    }}

    private var axes: ([String],[String]) { matrix==0 ? (puzzle.suspects,puzzle.places) : matrix==1 ? (puzzle.suspects,puzzle.weapons) : (puzzle.places,puzzle.weapons) }
    private var logicGrid: some View { let a=axes; return Grid(horizontalSpacing:2,verticalSpacing:2) { GridRow { Color.clear.frame(width:78,height:34); ForEach(a.1,id:\.self) { Text($0).font(.system(size:9,weight:.bold)).lineLimit(2).minimumScaleFactor(0.6).frame(maxWidth:.infinity) } }; ForEach(Array(a.0.enumerated()),id:\.offset) { r,row in GridRow { Text(row).font(PZFont.caption).frame(width:78,alignment:.leading); ForEach(a.1.indices,id:\.self) { c in markButton(key:"\(matrix)-\(r)-\(c)") } } } }.padding(6).background(PZColor.surface,in:PZRadius.rect(PZRadius.card)) }
    private func markButton(key:String)->some View { let m=marks[key] ?? .unknown; return Button { marks[key] = m == .unknown ? .excluded : m == .excluded ? .confirmed : .unknown; saveMarks(); PZHaptics.tick() } label:{ Text(m == .excluded ? "×" : m == .confirmed ? "●" : "").font(.system(size:19,weight:.bold)).foregroundStyle(m == .confirmed ? PZColor.success : PZ.murdle).frame(maxWidth:.infinity,minHeight:38).pzVolume(m == .confirmed ? PZColor.success.mix(with: .black, by: 0.45) : m == .excluded ? PZ.murdle.mix(with: .black, by: 0.6) : nil, radius: 5) }.buttonStyle(.plain) }
    private func selection(_ label:String,values:[String],value:Binding<String>)->some View { HStack { Text(label).font(PZFont.body);Spacer();Picker(label,selection:value) { Text(t("Elegir…", "Choose…")).tag("");ForEach(values,id:\.self){Text($0).tag($0)} }.labelsHidden() } }
    private func accuse() { let c=puzzle.culprit; guard selectedSuspect==c.suspect,selectedPlace==c.place,selectedWeapon==c.weapon else { toast=PZToast(text:t("Algo no encaja todavía", "Something does not fit yet"),kind:.error);PZHaptics.error();return }; progress.markDone(puzzle.id);progress.setElapsed(puzzle.id,elapsed);progress.recordTime(TimeInterval(elapsed),kind:.murdle,puzzleID:puzzle.id);progress.noteDayIfComplete();result=PZResult(kind:.murdle,didWin:true,headline:puzzle.caseKind == .murder ? t("¡Caso cerrado!", "Case closed!") : t("¡Robo resuelto!", "Theft solved!"),detail:"\(c.suspect) · \(c.place) · \(c.weapon)",metrics:[(t("Nivel", "Level"),puzzle.difficulty.title(language: puzzle.language)),(t("Tiempo", "Time"),PuzzleTiming.clock(TimeInterval(elapsed)))],shareText:t("NewsRaider Murdle · \(puzzle.difficulty.title(language: puzzle.language)) · caso cerrado", "NewsRaider Murdle · \(puzzle.difficulty.title(language: puzzle.language)) · case closed")) }
    private func loadMarks(){ marks=progress.fill(puzzle.id).reduce(into:[:]){$0[$1.key]=MurdleMark(rawValue:Int($1.value) ?? 0) ?? .unknown} }
    private func saveMarks(){ progress.setFill(puzzle.id,marks.mapValues{String($0.rawValue)}) }
}

// MARK: - Murdoku

/// A spatial deduction case built from the same people and narrative themes
/// as Murdle. The solution is a pair of permutations: every suspect occupies
/// one row and one column. Generated clues are filtered against all 14,400
/// possible 5-person layouts until exactly one remains.
struct MurdokuPuzzle: Identifiable, Sendable, Hashable {
    struct SceneObject: Identifiable, Sendable, Hashable {
        enum Kind: String, CaseIterable, Sendable, Hashable {
            case table, chair, sofa, statue, carpet, lamp
            var displayName: String { displayName(language: .spanish) }
            func displayName(language: PuzzleLanguage) -> String {
                switch self {
                case .table: language == .english ? "Table" : "Mesa"
                case .chair: language == .english ? "Chair" : "Silla"
                case .sofa: language == .english ? "Sofa" : "Sofá"
                case .statue: language == .english ? "Statue" : "Estatua"
                case .carpet: language == .english ? "Carpet" : "Alfombra"
                case .lamp: language == .english ? "Lamp" : "Lámpara"
                }
            }
            /// Furniture you can sit or stand on doesn't block a guess; a
            /// table, statue or lamp takes up the whole cell and does.
            var blocksPerson: Bool {
                switch self {
                case .chair, .sofa, .carpet: false
                case .table, .statue, .lamp: true
                }
            }
            /// "Sofá" is the one masculine noun in this set — everything
            /// else (mesa/silla/estatua/alfombra/lámpara) is feminine.
            var article: String { self == .sofa ? "el" : "la" }
        }
        let id: Int
        let name: String
        let kind: Kind
        let cell: GridCell
    }

    enum Clue: Sendable, Hashable {
        case inRoom(person: Int, room: Int)
        case notInRoom(person: Int, room: Int)
        case aloneInRoom(person: Int, room: Int)
        case northOf(person: Int, other: Int)
        case westOf(person: Int, other: Int)
        case besideObject(person: Int, object: Int)
        case northOfObject(person: Int, object: Int)
        case southOfObject(person: Int, object: Int)
        case westOfObject(person: Int, object: Int)
        case eastOfObject(person: Int, object: Int)
        case onObject(person: Int, object: Int)
        case cornerOfRoom(person: Int, room: Int)
    }

    let id: String
    var language: PuzzleLanguage = .spanish
    let size: Int
    let themeLabel: String
    let title: String
    let intro: String
    let suspects: [String]
    let rooms: [String]
    let roomMap: [[Int]]
    let victim: GridCell
    let objects: [SceneObject]
    let clues: [Clue]
    let solution: [GridCell]

    var victimRoom: Int { room(at: victim) }
    var killerIndex: Int { solution.firstIndex { room(at: $0) == victimRoom }! }
    var killer: String { suspects[killerIndex] }

    func room(at cell: GridCell) -> Int { roomMap[cell.row][cell.col] }

    func clueText(_ clue: Clue) -> String {
        if language == .english {
            switch clue {
            case .inRoom(let person, let room): return "\(suspects[person]) was in the \(rooms[room])."
            case .notInRoom(let person, let room): return "\(suspects[person]) was not in the \(rooms[room])."
            case .aloneInRoom(let person, let room): return "\(suspects[person]) was the only person in the \(rooms[room])."
            case .northOf(let person, let other): return "\(suspects[person]) was north of \(suspects[other])."
            case .westOf(let person, let other): return "\(suspects[person]) was to the left of \(suspects[other])."
            case .besideObject(let person, let object): return "\(suspects[person]) was next to \(objectPhrase(object))."
            case .northOfObject(let person, let object): return "\(suspects[person]) was north of \(objectPhrase(object))."
            case .southOfObject(let person, let object): return "\(suspects[person]) was south of \(objectPhrase(object))."
            case .westOfObject(let person, let object): return "\(suspects[person]) was to the left of \(objectPhrase(object))."
            case .eastOfObject(let person, let object): return "\(suspects[person]) was to the right of \(objectPhrase(object))."
            case .onObject(let person, let object): return "\(suspects[person]) was on \(objectPhrase(object))."
            case .cornerOfRoom(let person, let room): return "\(suspects[person]) was in a corner of the \(rooms[room])."
            }
        }
        switch clue {
        case .inRoom(let person, let room):
            return "\(suspects[person]) estaba en la estancia \(rooms[room])."
        case .notInRoom(let person, let room):
            return "\(suspects[person]) no estaba en la estancia \(rooms[room])."
        case .aloneInRoom(let person, let room):
            // "Única persona" rather than "sola"/"solo" sidesteps needing to
            // know each suspect name's grammatical gender for agreement.
            return "\(suspects[person]) fue la única persona en la estancia \(rooms[room])."
        case .northOf(let person, let other):
            return "\(suspects[person]) estaba al norte de \(suspects[other])."
        case .westOf(let person, let other):
            return "\(suspects[person]) estaba a la izquierda de \(suspects[other])."
        case .besideObject(let person, let object):
            return "\(suspects[person]) estaba junto \(objectPhrase(object, after: "a"))."
        case .northOfObject(let person, let object):
            return "\(suspects[person]) estaba al norte \(objectPhrase(object, after: "de"))."
        case .southOfObject(let person, let object):
            return "\(suspects[person]) estaba al sur \(objectPhrase(object, after: "de"))."
        case .westOfObject(let person, let object):
            return "\(suspects[person]) estaba a la izquierda \(objectPhrase(object, after: "de"))."
        case .eastOfObject(let person, let object):
            return "\(suspects[person]) estaba a la derecha \(objectPhrase(object, after: "de"))."
        case .onObject(let person, let object):
            return "\(suspects[person]) estaba sentado en \(objectPhrase(object, after: ""))."
        case .cornerOfRoom(let person, let room):
            return "\(suspects[person]) estaba en una esquina de la estancia \(rooms[room])."
        }
    }

    /// Since the same furniture kind can now appear more than once (multiple
    /// carpets, say), "la mesa" alone would be ambiguous. Qualify with the
    /// room, matching the phrasing `.inRoom`/`.notInRoom` already use. Bare
    /// form (own article, no preposition) — used standalone in the legend.
    func objectPhrase(_ object: Int) -> String {
        let obj = objects[object]
        if language == .english {
            return "the \(obj.kind.displayName(language: language).lowercased()) in the \(rooms[room(at: obj.cell)])"
        }
        return "\(obj.kind.article) \(obj.kind.displayName.lowercased()) de la estancia \(rooms[room(at: obj.cell)])"
    }

    /// Same phrase preceded by "de" or "a", contracted with a masculine
    /// article the way Spanish requires ("del sofá…"/"al sofá…") — "de"/"a"
    /// are the only two prepositions that contract with "el", and never
    /// with "la", so a feminine noun is untouched ("de la mesa…").
    private func objectPhrase(_ object: Int, after preposition: String) -> String {
        let obj = objects[object]
        let bare = "\(obj.kind.displayName.lowercased()) de la estancia \(rooms[room(at: obj.cell)])"
        guard obj.kind.article == "el" else { return "\(preposition) la \(bare)" }
        return preposition == "de" ? "del \(bare)" : "al \(bare)"
    }

    static func generate(seed: UInt64, language: PuzzleLanguage = .spanish) -> MurdokuPuzzle {
        let size = 5
        var rng = SeededGenerator(seed: seed ^ 0x4D55_5244_4F4B_55)
        let murderThemes = (language == .english ? MurdlePuzzle.englishThemes : MurdlePuzzle.themes).filter { $0.kind == .murder }
        let theme = murderThemes[rng.int(murderThemes.count)]
        let suspects = Array(rng.shuffled(theme.suspects).prefix(size))
        let pickedRooms = Array(rng.shuffled(theme.places).prefix(size))
        let rooms = pickedRooms.map(\.name)
        let roomMap = roomTemplates[rng.int(roomTemplates.count)]

        var solution: [GridCell] = []
        var victim = GridCell(row: 0, col: 0)
        for _ in 0..<64 {
            let rows = rng.shuffled(Array(0..<size))
            let cols = rng.shuffled(Array(0..<size))
            let proposal = suspects.indices.map { GridCell(row: rows[$0], col: cols[$0]) }
            let occupied = Set(proposal)
            let singleRooms = rooms.indices.filter { room in
                proposal.filter { roomMap[$0.row][$0.col] == room }.count == 1
                    && allCells(size: size).contains { roomMap[$0.row][$0.col] == room && !occupied.contains($0) }
            }
            guard let murderRoom = rng.shuffled(singleRooms).first else { continue }
            let victimCells = allCells(size: size).filter {
                roomMap[$0.row][$0.col] == murderRoom && !occupied.contains($0)
            }
            guard let pickedVictim = rng.shuffled(victimCells).first else { continue }
            solution = proposal
            victim = pickedVictim
            break
        }

        // Every supplied room template has several layouts with a one-person
        // room. This fallback is deterministic and also keeps release builds
        // safe if a future template accidentally violates that assumption.
        if solution.isEmpty {
            solution = (0..<size).map { GridCell(row: $0, col: $0) }
            let occupied = Set(solution)
            let room = rooms.indices.first { roomIndex in
                solution.filter { cell in
                    roomMap[cell.row][cell.col] == roomIndex
                }.count == 1
            } ?? 0
            victim = allCells(size: size).first {
                roomMap[$0.row][$0.col] == room && !occupied.contains($0)
            } ?? GridCell(row: 0, col: 1)
        }

        let solutionCells = Set(solution)
        // One furniture piece per room, kind picked independently each time
        // — two rooms can both get a carpet. `objectPhrase` above qualifies
        // every mention with its room, so repeats never read as ambiguous.
        // Kind is picked BEFORE the candidate cell pool: a chair/sofa/carpet
        // (non-blocking, per `blocksPerson`) is allowed to land on a
        // suspect's true solution cell — otherwise every tappable "you can
        // place someone here" furniture cell would be guaranteed wrong,
        // which is both a broken promise to the player and a free elimination
        // shortcut the clue pruner never accounted for. A table/statue/lamp
        // still can't share a cell with the victim or a suspect.
        var occupiedByFurniture = Set<GridCell>()
        var objects: [SceneObject] = []
        for room in rooms.indices {
            let kind = SceneObject.Kind.allCases[rng.int(SceneObject.Kind.allCases.count)]
            let available = allCells(size: size).filter { cell in
                roomMap[cell.row][cell.col] == room && cell != victim
                    && !occupiedByFurniture.contains(cell)
                    && (!kind.blocksPerson || !solutionCells.contains(cell))
            }
            guard let cell = rng.shuffled(available).first else { continue }
            objects.append(SceneObject(id: objects.count,
                                       name: kind.displayName(language: language),
                                       kind: kind,
                                       cell: cell))
            occupiedByFurniture.insert(cell)
        }

        let victimRoom = roomMap[victim.row][victim.col]
        let killerIndex = solution.firstIndex { roomMap[$0.row][$0.col] == victimRoom }!
        // Keep insertion order stable. Building this through Set and then
        // converting to Array made the supposedly daily clue list depend on
        // Swift's per-process hash seed, so two devices could get different
        // clues for the same date.
        var pool: [Clue] = []
        func add(_ clue: Clue) {
            if !pool.contains(clue) { pool.append(clue) }
        }

        // Room clues are deliberately withheld for the killer: naming that
        // person in the victim's room would reveal the answer without solving
        // the placement puzzle. That includes "alone in room" below — the
        // killer's room is BY DEFINITION single-occupant (that's how the
        // murder room was chosen above), so it's an even more direct giveaway
        // than a plain `.inRoom` would be.
        var roomOccupancy = [Int](repeating: 0, count: rooms.count)
        for cell in solution { roomOccupancy[roomMap[cell.row][cell.col]] += 1 }
        for person in suspects.indices where person != killerIndex {
            let correctRoom = roomMap[solution[person].row][solution[person].col]
            add(.inRoom(person: person, room: correctRoom))
            if roomOccupancy[correctRoom] == 1 {
                add(.aloneInRoom(person: person, room: correctRoom))
            }
            let wrongRooms = rng.shuffled(rooms.indices.filter { $0 != correctRoom })
            for room in wrongRooms.prefix(2) {
                add(.notInRoom(person: person, room: room))
            }
        }

        // All pairwise comparisons are candidates. Together they define both
        // complete orders, so uniqueness is guaranteed even if room/object
        // clues happen to be weak for a particular seed.
        for first in suspects.indices {
            for second in suspects.indices where first < second {
                let a = solution[first], b = solution[second]
                add(a.row < b.row
                    ? .northOf(person: first, other: second)
                    : .northOf(person: second, other: first))
                add(a.col < b.col
                    ? .westOf(person: first, other: second)
                    : .westOf(person: second, other: first))
            }
        }

        for person in suspects.indices where person != killerIndex {
            let cell = solution[person]
            for object in objects {
                let target = object.cell
                let sameRoom = roomMap[cell.row][cell.col] == roomMap[target.row][target.col]
                if sameRoom && abs(cell.row - target.row) + abs(cell.col - target.col) == 1 {
                    add(.besideObject(person: person, object: object.id))
                }
                if cell.row < target.row { add(.northOfObject(person: person, object: object.id)) }
                if cell.row > target.row { add(.southOfObject(person: person, object: object.id)) }
                if cell.col < target.col { add(.westOfObject(person: person, object: object.id)) }
                if cell.col > target.col { add(.eastOfObject(person: person, object: object.id)) }
                if cell == target && !object.kind.blocksPerson {
                    add(.onObject(person: person, object: object.id))
                }
            }
            let room = roomMap[cell.row][cell.col]
            if isRoomCorner(cell, room: room, roomMap: roomMap) {
                add(.cornerOfRoom(person: person, room: room))
            }
        }

        let rowOrders = permutations(Array(0..<size))
        let colOrders = rowOrders
        var remaining: [[GridCell]] = []
        remaining.reserveCapacity(rowOrders.count * colOrders.count)
        for rows in rowOrders {
            for cols in colOrders {
                remaining.append(suspects.indices.map { GridCell(row: rows[$0], col: cols[$0]) })
            }
        }

        var availableClues = rng.shuffled(pool)
        var chosen: [Clue] = []
        while remaining.count > 1 {
            var bestIndex: Int?
            var bestRemaining = remaining.count
            for index in availableClues.indices {
                let clue = availableClues[index]
                let count = remaining.reduce(into: 0) { total, candidate in
                    if matches(clue, positions: candidate, roomMap: roomMap, objects: objects) {
                        total += 1
                    }
                }
                if count < bestRemaining {
                    bestRemaining = count
                    bestIndex = index
                }
            }
            guard let bestIndex else { break }
            let clue = availableClues.remove(at: bestIndex)
            chosen.append(clue)
            remaining.removeAll {
                !matches(clue, positions: $0, roomMap: roomMap, objects: objects)
            }
        }
        assert(remaining.count == 1, "Murdoku must have exactly one solution")

        let victimReport = theme.victims[rng.int(theme.victims.count)]
        let intro = theme.intro.replacingOccurrences(of: "{victim}", with: victimReport)
        return MurdokuPuzzle(id: (language == .english ? "en-" : "") + "murdoku-\(seed)", language: language, size: size,
                             themeLabel: theme.label, title: theme.titles[rng.int(theme.titles.count)],
                             intro: intro, suspects: suspects, rooms: rooms,
                             roomMap: roomMap, victim: victim, objects: objects,
                             clues: rng.shuffled(chosen), solution: solution)
    }

    private static func matches(_ clue: Clue, positions: [GridCell],
                                roomMap: [[Int]], objects: [SceneObject]) -> Bool {
        switch clue {
        case .inRoom(let person, let room):
            let cell = positions[person]
            return roomMap[cell.row][cell.col] == room
        case .notInRoom(let person, let room):
            let cell = positions[person]
            return roomMap[cell.row][cell.col] != room
        case .aloneInRoom(let person, let room):
            let cell = positions[person]
            guard roomMap[cell.row][cell.col] == room else { return false }
            return positions.filter { roomMap[$0.row][$0.col] == room }.count == 1
        case .northOf(let person, let other):
            return positions[person].row < positions[other].row
        case .westOf(let person, let other):
            return positions[person].col < positions[other].col
        case .besideObject(let person, let object):
            let cell = positions[person], target = objects[object].cell
            return roomMap[cell.row][cell.col] == roomMap[target.row][target.col]
                && abs(cell.row - target.row) + abs(cell.col - target.col) == 1
        case .northOfObject(let person, let object):
            return positions[person].row < objects[object].cell.row
        case .southOfObject(let person, let object):
            return positions[person].row > objects[object].cell.row
        case .westOfObject(let person, let object):
            return positions[person].col < objects[object].cell.col
        case .eastOfObject(let person, let object):
            return positions[person].col > objects[object].cell.col
        case .onObject(let person, let object):
            return positions[person] == objects[object].cell
        case .cornerOfRoom(let person, let room):
            return roomMap[positions[person].row][positions[person].col] == room
                && isRoomCorner(positions[person], room: room, roomMap: roomMap)
        }
    }

    private static func isRoomCorner(_ cell: GridCell, room: Int, roomMap: [[Int]]) -> Bool {
        let size = roomMap.count
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        let outside = directions.filter { dr, dc in
            let r = cell.row + dr, c = cell.col + dc
            return r < 0 || r >= size || c < 0 || c >= size || roomMap[r][c] != room
        }
        let hasVertical = outside.contains { $0.0 != 0 }
        let hasHorizontal = outside.contains { $0.1 != 0 }
        return hasVertical && hasHorizontal
    }

    private static func permutations(_ values: [Int]) -> [[Int]] {
        guard values.count > 1 else { return [values] }
        return values.indices.flatMap { index -> [[Int]] in
            var rest = values
            let head = rest.remove(at: index)
            return permutations(rest).map { [head] + $0 }
        }
    }

    private static func allCells(size: Int) -> [GridCell] {
        (0..<size).flatMap { row in (0..<size).map { GridCell(row: row, col: $0) } }
    }

    private static let roomTemplates: [[[Int]]] = [
        [[0,0,0,1,1],
         [0,0,2,1,1],
         [3,2,2,2,1],
         [3,3,2,4,4],
         [3,3,4,4,4]],
        [[0,0,1,1,1],
         [0,2,2,1,1],
         [0,2,3,3,1],
         [4,2,3,3,3],
         [4,4,4,4,3]],
        [[0,0,0,1,1],
         [0,2,0,1,1],
         [2,2,3,3,1],
         [2,4,4,3,3],
         [2,4,4,4,3]]
    ]
}

/// Small hand-drawn pictogram for a `SceneObject.Kind`, used instead of a
/// plain number badge on the board. Drawn from primitive shapes rather than
/// SF Symbols: this project has been bitten before by APIs/assets present on
/// one SDK and missing on another (see the Xcode Cloud notes in CLAUDE.md),
/// and there is no confirmed-available "statue"/"carpet" system symbol to
/// begin with, so a self-contained vector sidesteps the question entirely.
private struct FurnitureIcon: View {
    let kind: MurdokuPuzzle.SceneObject.Kind
    var tint: Color = PZColor.ink

    var body: some View {
        GeometryReader { geo in
            path(w: geo.size.width, h: geo.size.height)
                .stroke(tint, style: StrokeStyle(lineWidth: max(1, geo.size.width * 0.1),
                                                  lineCap: .round, lineJoin: .round))
        }
    }

    private func path(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        switch kind {
        case .table:
            p.move(to: CGPoint(x: w * 0.12, y: h * 0.30)); p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.30))
            p.move(to: CGPoint(x: w * 0.22, y: h * 0.30)); p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.88))
            p.move(to: CGPoint(x: w * 0.78, y: h * 0.30)); p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.88))
        case .chair:
            p.addRect(CGRect(x: w * 0.28, y: h * 0.42, width: w * 0.44, height: h * 0.28))
            p.move(to: CGPoint(x: w * 0.28, y: h * 0.42)); p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.12))
            p.move(to: CGPoint(x: w * 0.32, y: h * 0.70)); p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.90))
            p.move(to: CGPoint(x: w * 0.68, y: h * 0.70)); p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.90))
        case .sofa:
            p.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.36, width: w * 0.76, height: h * 0.34),
                              cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
            p.addRect(CGRect(x: w * 0.08, y: h * 0.30, width: w * 0.14, height: h * 0.34))
            p.addRect(CGRect(x: w * 0.78, y: h * 0.30, width: w * 0.14, height: h * 0.34))
            p.move(to: CGPoint(x: w * 0.20, y: h * 0.70)); p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.86))
            p.move(to: CGPoint(x: w * 0.80, y: h * 0.70)); p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.86))
        case .statue:
            p.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.08, width: w * 0.28, height: h * 0.28))
            p.move(to: CGPoint(x: w * 0.40, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.64))
            p.move(to: CGPoint(x: w * 0.60, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.64))
            p.addRect(CGRect(x: w * 0.18, y: h * 0.66, width: w * 0.64, height: h * 0.22))
        case .carpet:
            p.addRoundedRect(in: CGRect(x: w * 0.12, y: h * 0.24, width: w * 0.76, height: h * 0.54),
                              cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
            p.addRoundedRect(in: CGRect(x: w * 0.24, y: h * 0.36, width: w * 0.52, height: h * 0.30),
                              cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        case .lamp:
            p.move(to: CGPoint(x: w * 0.32, y: h * 0.10)); p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.10))
            p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.38))
            p.closeSubpath()
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.38)); p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.80))
            p.move(to: CGPoint(x: w * 0.30, y: h * 0.88)); p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.88))
        }
        return p
    }
}

// Murdoku's case-file palette is intentionally local to this game.
private enum MurdokuPalette {
    static let paper = Color(light: "F4EEE2", dark: "211E1A")
    static let card = Color(light: "FBF8F1", dark: "2B2722")
    static let ink = Color(light: "302923", dark: "F1E8D8")
    static let muted = Color(light: "74695D", dark: "B6AA99")
    static let line = Color(light: "D8CDBB", dark: "51473C")
    static let terracotta = Color(light: "A94F39", dark: "D9876E")
}

struct MurdokuCharacterPortrait: View {
    let index: Int
    /// `false`: sin recorte ni aro circular (lo enmarca `MurdokuAvatarTile`).
    var framed = true

    private var coat: Color {
        [Color(light: "C76B45", dark: "DA8968"), Color(light: "82765C", dark: "B8AA86"), Color(light: "E6D0B2", dark: "CDB99E"), Color(light: "6C7071", dark: "999E9E"), Color(light: "9D8170", dark: "C09F89")][index % 5]
    }
    private var garment: Color {
        [Color(light: "40505A", dark: "647783"), Color(light: "526253", dark: "758675"), Color(light: "A94F39", dark: "B9634D"), Color(light: "454A55", dark: "686F7D"), Color(light: "4E4142", dark: "796264")][index % 5]
    }
    private var isOwl: Bool { index % 5 == 1 }
    private var isRabbit: Bool { index % 5 == 2 }

    var body: some View {
        ZStack {
            Circle().fill(MurdokuPalette.paper)
            if isRabbit {
                Capsule().fill(coat).frame(width: 7, height: 20).rotationEffect(.degrees(-10)).offset(x: -7, y: -15)
                Capsule().fill(coat).frame(width: 7, height: 20).rotationEffect(.degrees(10)).offset(x: 7, y: -15)
                Capsule().fill(Color(light: "F2E2D3", dark: "E2D3C4")).frame(width: 3, height: 12).offset(x: -7, y: -15)
                Capsule().fill(Color(light: "F2E2D3", dark: "E2D3C4")).frame(width: 3, height: 12).offset(x: 7, y: -15)
            } else if isOwl {
                Circle().fill(coat).frame(width: 12, height: 12).offset(x: -9, y: -11)
                Circle().fill(coat).frame(width: 12, height: 12).offset(x: 9, y: -11)
            } else {
                MurdokuPortraitEar().fill(coat).frame(width: 12, height: 16).offset(x: -8, y: -13)
                MurdokuPortraitEar().fill(coat).frame(width: 12, height: 16).scaleEffect(x: -1, y: 1).offset(x: 8, y: -13)
                MurdokuPortraitEar().fill(Color(light: "EAC6A9", dark: "D7AE91")).frame(width: 5, height: 9).offset(x: -8, y: -11)
                MurdokuPortraitEar().fill(Color(light: "EAC6A9", dark: "D7AE91")).frame(width: 5, height: 9).scaleEffect(x: -1, y: 1).offset(x: 8, y: -11)
            }
            RoundedRectangle(cornerRadius: 12).fill(garment).frame(width: 34, height: 22).offset(y: 19)
            Ellipse().fill(coat).frame(width: 28, height: 27).offset(y: -2)
            Ellipse().fill(Color(light: "F2E2D3", dark: "E2D3C4")).frame(width: 17, height: 10).offset(y: 5)
            HStack(spacing: 8) {
                Circle().fill(Color(light: "302923", dark: "211E1A")).frame(width: 2.8, height: 2.8)
                Circle().fill(Color(light: "302923", dark: "211E1A")).frame(width: 2.8, height: 2.8)
            }.offset(y: -3)
            Circle().fill(MurdokuPalette.terracotta).frame(width: 4, height: 3).offset(y: 3)
            accessory
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle().inset(by: framed ? 0 : -40))
        .overlay { if framed { Circle().stroke(MurdokuPalette.line, lineWidth: 1) } }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var accessory: some View {
        switch index % 5 {
        case 0: // Fox detective: deerstalker cap and magnifying glass.
            Capsule().fill(Color(light: "594638", dark: "44352C")).frame(width: 25, height: 7).offset(y: -13)
            RoundedRectangle(cornerRadius: 3).fill(Color(light: "78604B", dark: "594638")).frame(width: 17, height: 7).offset(y: -17)
            Circle().stroke(MurdokuPalette.terracotta, lineWidth: 2).frame(width: 8, height: 8).offset(x: 15, y: 12)
            Capsule().fill(MurdokuPalette.terracotta).frame(width: 2, height: 6).rotationEffect(.degrees(-40)).offset(x: 18, y: 18)
        case 1: // Owl archivist: round spectacles.
            HStack(spacing: 2) {
                Circle().stroke(MurdokuPalette.ink, lineWidth: 1.2).frame(width: 8, height: 8)
                Circle().stroke(MurdokuPalette.ink, lineWidth: 1.2).frame(width: 8, height: 8)
            }.offset(y: -3)
            Capsule().fill(Color(light: "526253", dark: "758675")).frame(width: 19, height: 5).offset(y: -16)
        case 2: // Rabbit medic: red cross on a cloth band.
            Capsule().fill(Color(light: "FBF8F1", dark: "E2D3C4")).frame(width: 20, height: 5).offset(y: -12)
            RoundedRectangle(cornerRadius: 1).fill(MurdokuPalette.terracotta).frame(width: 3, height: 8).offset(y: -12)
            RoundedRectangle(cornerRadius: 1).fill(MurdokuPalette.terracotta).frame(width: 8, height: 3).offset(y: -12)
        case 3: // Badger constable: dark peaked cap and brass badge.
            Capsule().fill(Color(light: "343A43", dark: "20242B")).frame(width: 25, height: 6).offset(y: -13)
            RoundedRectangle(cornerRadius: 4).fill(Color(light: "454A55", dark: "303540")).frame(width: 17, height: 7).offset(y: -17)
            Circle().fill(Color(light: "D8AE67", dark: "E2C27E")).frame(width: 4, height: 4).offset(y: -14)
        default: // Cat pianist: small wine-red bow tie.
            Circle().fill(MurdokuPalette.terracotta).frame(width: 5, height: 5).offset(x: -4, y: 14)
            Circle().fill(MurdokuPalette.terracotta).frame(width: 5, height: 5).offset(x: 4, y: 14)
            Circle().fill(MurdokuPalette.card).frame(width: 2, height: 2).offset(y: 14)
        }
    }
}

private struct MurdokuPortraitEar: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
            path.closeSubpath()
        }
    }
}

struct MurdokuGame: View {
    private func t(_ es: String, _ en: String) -> String { puzzle.language == .english ? en : es }
    let puzzle: MurdokuPuzzle
    @ObservedObject private var progress = PuzzleProgress.shared

    /// Which tool the next tap on the board obeys. Not persisted — always
    /// starts back at `.place` on a fresh launch.
    enum Tool { case place, candidate, mark, erase }
    private struct Snapshot {
        let excluded: Set<String>
        let confirmed: [Int: GridCell]
        let candidates: Set<String>
    }

    /// Global "nobody is here" marks — one flat set of "x-row-col" keys, NOT
    /// tied to any suspect. That's the model Josu described: × means the
    /// cell itself is empty, not "I've ruled out suspect N specifically".
    /// Set/cleared with the Mark tool.
    @State private var excluded: Set<String> = []
    /// Person index -> their confirmed cell. Long-press with a person
    /// selected (Place tool).
    @State private var confirmed: [Int: GridCell] = [:]
    /// "this suspect might be here" — single tap with a person selected
    /// (Place tool). Keyed "c<person>-<row>-<col>", per suspect (unlike
    /// `excluded`): a candidate is one suspect's guess, not a board fact.
    @State private var candidates: Set<String> = []
    @State private var tool: Tool = .place
    @State private var selected = 0
    /// The one cell that just failed a confirm attempt (row/column already
    /// taken) — a transient flash, cleared on the next board interaction or
    /// on switching the selected suspect. Never persisted.
    @State private var conflictCell: GridCell?
    /// Snapshots taken before each mutating action, popped by Undo. Capped
    /// so an extra-long session can't grow this unbounded.
    @State private var undoStack: [Snapshot] = []
    @State private var elapsed = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showClosed = false
    /// Pistas que el jugador ha marcado como usadas (casilla + tachado).
    /// Se guardan con el resto de anotaciones, clave "k<índice>".
    @State private var checkedClues: Set<Int> = []
    /// Pista tocada: resalta en el tablero de qué habla. No se guarda.
    @State private var focusedClue: Int?
    @State private var toast: PZToast?
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= MurdokuTheme.twoColumnMinWidth {
                wideLayout(geometry.size)
            } else {
                ScrollView {
                    VStack(spacing: MurdokuTheme.sectionGap) {
                        if sizeClass == .compact {
                            Text(puzzle.title)
                                .font(.title3.weight(.medium))
                                .foregroundStyle(MurdokuTheme.text)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                        }
                        board(side: max(0, min(geometry.size.width - MurdokuTheme.screenPadding * 2, MurdokuTheme.boardMaxSide)))
                        controls
                        sidebar
                    }
                    .padding(MurdokuTheme.screenPadding)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .background(PZGameBackdrop(color: PZ.murdoku))   // 2026-11-16: resplandor del color del juego
        .navigationTitle(sizeClass == .compact ? "" : puzzle.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            elapsed = progress.elapsed(puzzle.id)
            loadMarks()
            #if DEBUG
            applyDebugDemo()
            #endif
        }
        .onReceive(tick) { _ in
            guard !showClosed, !progress.isDone(puzzle.id) else { return }
            elapsed += 1
            if elapsed.isMultiple(of: 5) { progress.setElapsed(puzzle.id, elapsed) }
        }
        .sheet(isPresented: $showClosed) { MurdokuClosedSheet(model: closedCase()) }
        .pzToast($toast)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                    .disabled(undoStack.isEmpty)
                    .accessibilityLabel(t("Deshacer", "Undo"))
                Menu {
                    Button(tool == .erase ? t("Dejar de borrar", "Stop erasing") : t("Borrar una casilla", "Erase a cell"),
                           systemImage: "eraser") {
                        tool = tool == .erase ? .place : .erase
                        PZHaptics.tick()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(t("Más", "More"))
            }
        }
        .pzRules(.murdoku)
    }

    /// iPad: tablero y controles a la izquierda, pistas a la derecha.
    private func wideLayout(_ size: CGSize) -> some View {
        let pad = MurdokuTheme.screenPaddingWide
        let leftWidth = max(0, (size.width - pad * 2 - MurdokuTheme.columnGap) * MurdokuTheme.leftColumnFraction)
        let side = min(leftWidth, max(240, min(size.height - MurdokuTheme.controlsReserve, MurdokuTheme.boardMaxSide)))
        return HStack(alignment: .top, spacing: MurdokuTheme.columnGap) {
            ScrollView {
                VStack(spacing: MurdokuTheme.sectionGap) {
                    board(side: side)
                    controls
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, MurdokuTheme.screenPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: leftWidth)
            ScrollView {
                sidebar.padding(.bottom, MurdokuTheme.screenPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, pad)
        .padding(.top, MurdokuTheme.controlGap)
    }

    private var controls: some View {
        VStack(spacing: MurdokuTheme.controlGap) {
            toolPicker
            suspectChips
            checkButton
            Text(toolInstructions)
                .font(.footnote)
                .foregroundStyle(MurdokuTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sidebar: some View {
        VStack(spacing: MurdokuTheme.sectionGap) {
            cluesCard
            caseFileCard
            floorPlanCard
        }
    }

    private var toolPicker: some View {
        HStack(spacing: 0) {
            toolSegment(t("Colocar", "Place"), .place)
            toolSegment(t("Quizá", "Maybe"), .candidate)
            toolSegment(t("Descartar", "Rule out"), .mark)
        }
        .padding(3)
        .background(MurdokuTheme.controlTrack, in: Capsule())
    }

    private func toolSegment(_ title: String, _ value: Tool) -> some View {
        let isOn = tool == value
        return Button {
            tool = value
            PZHaptics.tick()
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MurdokuTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: MurdokuTheme.minTarget - 6)
                .background(isOn ? MurdokuTheme.controlOn : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var suspectChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(puzzle.suspects.indices, id: \.self) { index in
                    suspectChip(index)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func suspectChip(_ index: Int) -> some View {
        let isSelected = selected == index
        let isPlaced = confirmedCell(for: index) != nil
        let color = suspectColor(index)
        let shape = RoundedRectangle(cornerRadius: MurdokuTheme.chipRadius, style: .continuous)
        return Button {
            selected = index
            tool = .place
            conflictCell = nil
            PZHaptics.tick()
        } label: {
            HStack(spacing: 8) {
                MurdokuAvatarTile(index: index, color: isSelected ? MurdokuTheme.onAccent.opacity(0.35) : color, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(puzzle.suspects[index])
                        .font(.headline)
                        .foregroundStyle(isSelected ? MurdokuTheme.onAccent : MurdokuTheme.text)
                    Text(suspectRole(index))
                        .font(.caption)
                        .foregroundStyle(isSelected ? MurdokuTheme.onAccent.opacity(0.75) : MurdokuTheme.textMuted)
                }
                .lineLimit(1)
                if isPlaced {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(isSelected ? MurdokuTheme.onAccent : color)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(minHeight: 56)
            .background(isSelected ? .clear : color.opacity(0.10), in: shape)
            .pzVolume(isSelected ? color : nil, radius: MurdokuTheme.chipRadius, glow: isSelected)
            .overlay { shape.strokeBorder(color.opacity(isSelected ? 0 : 0.28), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(puzzle.suspects[index]), \(suspectRole(index))")
        .accessibilityValue(isPlaced ? t("Colocado", "Placed") : t("Sin colocar", "Not placed"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var checkButton: some View {
        let ready = placedCount == puzzle.suspects.count
        return Button { solve() } label: {
            Label(t("Comprobar el caso", "Check the case"), systemImage: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(ready ? MurdokuTheme.onAccent : MurdokuTheme.textMuted.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: MurdokuTheme.checkButtonHeight)
                .background(ready ? MurdokuTheme.accent : MurdokuTheme.disabledFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .accessibilityHint(ready ? "" : t("Coloca antes a todos los sospechosos", "Place every suspect first"))
    }

    // MARK: Pistas

    private var cluesCard: some View {
        MurdokuCard {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(t("Pistas", "Clues"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(MurdokuTheme.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    MurdokuBadge(text: PuzzleKind.murdoku.difficulty.uppercased())
                        .accessibilityLabel(t("Dificultad: \(PuzzleKind.murdoku.difficulty)", "Difficulty: \(PuzzleKind.murdoku.difficulty)"))
                }
                Rectangle().fill(MurdokuTheme.hairline).frame(height: 1).padding(.vertical, 8)
                ForEach(Array(puzzle.clues.enumerated()), id: \.offset) { index, clue in
                    clueRow(index, clue)
                }
                if !suspectsWithoutClues.isEmpty {
                    Text(t("Sin pistas directas: \(suspectsWithoutClues) — dedúcelo por eliminación.",
                           "No direct clues: \(suspectsWithoutClues) — deduce by elimination."))
                        .font(.footnote)
                        .foregroundStyle(MurdokuTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                Text(t("Toca una pista para ver de qué habla en el mapa.", "Tap a clue to see what it refers to on the map."))
                    .font(.footnote)
                    .foregroundStyle(MurdokuTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    private var suspectsWithoutClues: String {
        puzzle.suspects.indices.filter { clues(for: $0).isEmpty }
            .map { puzzle.suspects[$0] }.joined(separator: ", ")
    }

    private func clueRow(_ index: Int, _ clue: MurdokuPuzzle.Clue) -> some View {
        let isChecked = checkedClues.contains(index)
        let isFocused = focusedClue == index
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return HStack(alignment: .top, spacing: 0) {
            Button {
                if isChecked { checkedClues.remove(index) } else { checkedClues.insert(index) }
                saveMarks()
                PZHaptics.tick()
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.body)
                    .foregroundStyle(isChecked ? MurdokuTheme.coral : MurdokuTheme.textMuted)
                    .frame(width: MurdokuTheme.minTarget, height: MurdokuTheme.minTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(t("Pista \(index + 1)", "Clue \(index + 1)"))
            .accessibilityValue(isChecked ? t("Marcada", "Checked") : t("Sin marcar", "Unchecked"))
            Button {
                focusedClue = isFocused ? nil : index
                PZHaptics.tick()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(MurdokuTheme.textMuted)
                    Text(clueAttributed(clue, checked: isChecked))
                        .font(.body)
                        .strikethrough(isChecked)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: MurdokuTheme.minTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("\(index + 1). \(puzzle.clueText(clue))")
            .accessibilityHint(t("Resalta en el mapa de qué habla", "Highlights what it refers to on the map"))
            .accessibilityAddTraits(isFocused ? .isSelected : [])
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .background(isFocused ? MurdokuTheme.accent.opacity(0.10) : .clear, in: shape)
        .overlay {
            if isFocused {
                shape.strokeBorder(MurdokuTheme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
    }

    private func clueAttributed(_ clue: MurdokuPuzzle.Clue, checked: Bool) -> AttributedString {
        var text = AttributedString(puzzle.clueText(clue))
        text.foregroundColor = checked ? MurdokuTheme.textMuted : MurdokuTheme.text
        for person in cluePeople(clue) {
            guard let range = text.range(of: puzzle.suspects[person]) else { continue }
            text[range].font = .body.weight(.semibold)
            if !checked { text[range].foregroundColor = suspectColor(person) }
        }
        return text
    }

    private func cluePeople(_ clue: MurdokuPuzzle.Clue) -> [Int] {
        puzzle.suspects.indices.filter { clueMentions(clue, person: $0) }
    }

    /// Casillas de las que habla una pista: la estancia o el mueble que
    /// nombra y, si ya están colocados, los sospechosos que menciona.
    private func focusCells(_ clue: MurdokuPuzzle.Clue) -> Set<GridCell> {
        var cells = Set(cluePeople(clue).compactMap { confirmed[$0] })
        switch clue {
        case .inRoom(_, let room), .notInRoom(_, let room), .aloneInRoom(_, let room), .cornerOfRoom(_, let room):
            for row in 0..<puzzle.size {
                for col in 0..<puzzle.size where puzzle.roomMap[row][col] == room {
                    cells.insert(GridCell(row: row, col: col))
                }
            }
        case .besideObject(_, let object), .northOfObject(_, let object), .southOfObject(_, let object),
             .westOfObject(_, let object), .eastOfObject(_, let object), .onObject(_, let object):
            cells.insert(puzzle.objects[object].cell)
        case .northOf, .westOf:
            break
        }
        return cells
    }

    /// Oficio que sugiere el disfraz del retrato existente (0 zorro detective,
    /// 1 búho archivista, 2 conejo con cruz roja, 3 tejón agente, 4 gato
    /// pianista). Solo ambientación; no es una pista.
    private func suspectRole(_ index: Int) -> String {
        [t("detective", "detective"), t("archivista", "archivist"), t("socorrista", "medic"),
         t("agente", "constable"), t("pianista", "pianist")][index % 5]
    }

    private func clues(for person: Int) -> [MurdokuPuzzle.Clue] {
        puzzle.clues.filter { clueMentions($0, person: person) }
    }

    private func clueMentions(_ clue: MurdokuPuzzle.Clue, person: Int) -> Bool {
        switch clue {
        case .inRoom(let p, _), .notInRoom(let p, _), .aloneInRoom(let p, _),
             .besideObject(let p, _), .northOfObject(let p, _), .southOfObject(let p, _),
             .westOfObject(let p, _), .eastOfObject(let p, _), .onObject(let p, _),
             .cornerOfRoom(let p, _):
            return p == person
        case .northOf(let a, let b), .westOf(let a, let b):
            return a == person || b == person
        }
    }

    private var toolInstructions: String {
        switch tool {
        case .place: t("Colocar a \(puzzle.suspects[selected]): toca una casilla libre. También puedes mantener pulsado.", "Place \(puzzle.suspects[selected]): tap an available cell. You can also touch and hold.")
        case .candidate: t("Quizá: toca una casilla para añadir o quitar una posibilidad de este sospechoso.", "Maybe: tap a cell to add or remove a possibility for this suspect.")
        case .mark: t("Descartar: toca una casilla para indicar que ahí no hay nadie.", "Rule out: tap a cell to mark it empty.")
        case .erase: t("Borrar: toca una casilla para limpiar todas sus anotaciones.", "Erase: tap a cell to clear all its notes.")
        }
    }

    // MARK: Tablero

    private func board(side: CGFloat) -> some View {
        let cellSide = side / CGFloat(puzzle.size)
        let focus = focusedClue.map { focusCells(puzzle.clues[$0]) } ?? []
        let shape = RoundedRectangle(cornerRadius: MurdokuTheme.boardRadius, style: .continuous)
        return ZStack(alignment: .topLeading) {
            MurdokuTheme.boardGap
            VStack(spacing: 0) {
                ForEach(0..<puzzle.size, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<puzzle.size, id: \.self) { col in
                            let cell = GridCell(row: row, col: col)
                            boardCell(cell, side: cellSide, isFocused: focus.contains(cell))
                        }
                    }
                }
            }
            roomDividers(cellSide: cellSide)
                .stroke(MurdokuTheme.roomDivider,
                        style: StrokeStyle(lineWidth: MurdokuTheme.roomDividerWidth, dash: [5, 4]))
                .allowsHitTesting(false)
            ForEach(Array(puzzle.rooms.enumerated()), id: \.offset) { room, name in
                let anchor = roomLabelAnchor(room)
                Text(name.uppercased())
                    .font(.system(size: max(9, min(15, cellSide * 0.135)), weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(MurdokuTheme.roomLabelText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(MurdokuTheme.roomLabelFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .frame(maxWidth: max(0, CGFloat(anchor.run) * cellSide - 10), alignment: .leading)
                    .offset(x: CGFloat(anchor.cell.col) * cellSide + 6, y: CGFloat(anchor.cell.row) * cellSide + 6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: side, height: side)
        .clipShape(shape)
        .overlay { shape.strokeBorder(MurdokuTheme.boardBorder, lineWidth: MurdokuTheme.boardBorderWidth) }
        // Volumen (2026-11-16): el tablero "flota" sobre el fondo; una sola sombra para todo el tablero.
        .background { shape.fill(MurdokuTheme.boardGap).shadow(color: .black.opacity(0.5), radius: 14, y: 8) }
        .accessibilityElement(children: .contain)
    }

    /// Línea discontinua en cada frontera entre dos estancias distintas.
    private func roomDividers(cellSide: CGFloat) -> Path {
        var path = Path()
        for row in 0..<puzzle.size {
            for col in 0..<puzzle.size {
                let room = puzzle.roomMap[row][col]
                let x = CGFloat(col) * cellSide, y = CGFloat(row) * cellSide
                if col + 1 < puzzle.size, puzzle.roomMap[row][col + 1] != room {
                    path.move(to: CGPoint(x: x + cellSide, y: y))
                    path.addLine(to: CGPoint(x: x + cellSide, y: y + cellSide))
                }
                if row + 1 < puzzle.size, puzzle.roomMap[row + 1][col] != room {
                    path.move(to: CGPoint(x: x, y: y + cellSide))
                    path.addLine(to: CGPoint(x: x + cellSide, y: y + cellSide))
                }
            }
        }
        return path
    }

    /// Casilla donde empieza la etiqueta de la estancia: la que tiene más
    /// casillas de su misma estancia seguidas a la derecha (para que quepa
    /// el nombre) y, a igualdad, la más alta y más a la izquierda.
    private func roomLabelAnchor(_ room: Int) -> (cell: GridCell, run: Int) {
        var best = (cell: GridCell(row: 0, col: 0), run: 0)
        for row in 0..<puzzle.size {
            for col in 0..<puzzle.size where puzzle.roomMap[row][col] == room {
                var run = 1
                while col + run < puzzle.size, puzzle.roomMap[row][col + run] == room { run += 1 }
                if run > best.run { best = (GridCell(row: row, col: col), run) }
            }
        }
        return best
    }

    private func boardCell(_ cell: GridCell, side: CGFloat, isFocused: Bool) -> some View {
        let room = puzzle.room(at: cell)
        let manualExcluded = excluded.contains(excludedKey(cell))
        let occupant = confirmedOccupant(at: cell)
        let object = puzzle.objects.first { $0.cell == cell }
        let isVictim = puzzle.victim == cell
        let noted = occupant == nil ? candidateSuspects(at: cell) : []
        // Any suspect already confirmed in this row or column makes the
        // cell impossible — a board fact, drawn fainter than a manual ×.
        let autoExcluded = occupant == nil && rowColTaken(by: cell)
        let isConflict = occupant == nil && cell == conflictCell
        let blocked = isVictim || (object?.kind.blocksPerson ?? false)
        let showCross = occupant == nil && (isConflict || manualExcluded || (autoExcluded && !blocked))
        let inner = RoundedRectangle(cornerRadius: MurdokuTheme.cellRadius, style: .continuous)
        return ZStack {
            roomColor(room)
            if let object {
                MurdokuTheme.furnitureLift
                FurnitureIcon(kind: object.kind, tint: MurdokuTheme.furnitureTint)
                    .padding(side * 0.2)
                    .opacity(occupant == nil && !showCross && noted.isEmpty ? 1 : 0.35)
            }
            if isFocused {
                Color.white.opacity(0.10)
                inner.strokeBorder(MurdokuTheme.focusLine, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            if isConflict {
                MurdokuTheme.coral.opacity(0.40)
            }
            if showCross {
                Image(systemName: "xmark")
                    .font(.system(size: side * 0.40, weight: .bold))
                    .foregroundStyle(isConflict ? MurdokuTheme.text : MurdokuTheme.mark)
                    .opacity(manualExcluded || isConflict ? 1 : 0.30)
            }
            if !noted.isEmpty {
                if !showCross {
                    Text("?")
                        .font(.system(size: side * 0.52, weight: .heavy, design: .rounded))
                        .foregroundStyle(MurdokuTheme.mark)
                        .offset(y: -side * 0.07)
                }
                // Quién podría estar aquí: mini retratos, no solo color.
                HStack(spacing: 2) {
                    ForEach(noted, id: \.self) { person in
                        MurdokuAvatarTile(index: person, color: suspectColor(person), size: side * 0.19)
                            .opacity(person == selected ? 1 : 0.6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, side * 0.05)
            }
            if let occupant {
                MurdokuAvatarTile(index: occupant, color: suspectColor(occupant), size: side * 0.76)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
            if isVictim {
                Text("V")
                    .font(.system(size: side * 0.15, weight: .black, design: .rounded))
                    .foregroundStyle(MurdokuTheme.onAccent)
                    .frame(width: side * 0.26, height: side * 0.26)
                    .background(MurdokuTheme.coral, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(side * 0.07)
            }
        }
        .overlay {
            // Bisel sutil (2026-11-16): brillo en el borde superior de cada casilla.
            inner.strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center),
                               lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(inner)
        .padding(MurdokuTheme.cellGap / 2)
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .onTapGesture { handleTap(cell) }
        .onLongPressGesture(minimumDuration: 0.45) { handleLongPress(cell) }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(for: cell, occupant: occupant,
                                               object: object, isVictim: isVictim,
                                               manualExcluded: manualExcluded, noted: noted,
                                               autoExcluded: autoExcluded, isConflict: isConflict))
        .accessibilityHint(Text(toolInstructions))
        // Long-press is hard to discover/perform under VoiceOver, so the
        // Place tool's "colocar" action is also reachable as a named
        // accessibility action (shows up in the rotor).
        .accessibilityAction(named: Text(t("Colocar aquí", "Place here"))) { if tool == .place { attemptConfirm(cell) } }
    }

    private func handleTap(_ cell: GridCell) {
        switch tool {
        case .place: attemptConfirm(cell)
        case .candidate: toggleCandidate(cell)
        case .mark: toggleExcluded(cell)
        case .erase: eraseCell(cell)
        }
    }

    private func handleLongPress(_ cell: GridCell) {
        guard tool == .place else { return }
        attemptConfirm(cell)
    }

    // MARK: Expediente y plano

    private var caseFileCard: some View {
        MurdokuCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(t("EXPEDIENTE · \(puzzle.themeLabel.uppercased())", "CASE FILE · \(puzzle.themeLabel.uppercased())"),
                      systemImage: "folder.fill")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(MurdokuTheme.coral)
                Text(t("\(puzzle.intro) Reconstruye dónde estaba cada sospechoso. La persona que quedó a solas con la víctima es el asesino.", "\(puzzle.intro) Work out where each suspect was. The person alone with the victim is the killer."))
                    .font(.subheadline)
                    .foregroundStyle(MurdokuTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    caseStat(t("TIEMPO", "TIME"), PuzzleTiming.clock(TimeInterval(elapsed)), icon: "clock")
                    Spacer()
                    caseStat(t("EN SU SITIO", "PLACED"), "\(placedCount)/\(puzzle.suspects.count)", icon: "person.fill.checkmark")
                }
            }
        }
    }

    private func caseStat(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(MurdokuTheme.textMuted)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(MurdokuTheme.textMuted)
                Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(MurdokuTheme.text)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var floorPlanCard: some View {
        MurdokuCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("PLANO", "FLOOR PLAN"))
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(MurdokuTheme.textMuted)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                    ForEach(Array(puzzle.rooms.enumerated()), id: \.element) { room, _ in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(roomColor(room))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(MurdokuTheme.roomDivider.opacity(0.5), lineWidth: 1)
                                }
                                .frame(width: 18, height: 18)
                            Text(puzzle.rooms[room]).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                }
                Rectangle().fill(MurdokuTheme.hairline).frame(height: 1)
                HStack(spacing: 8) {
                    Text("V")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(MurdokuTheme.onAccent)
                        .frame(width: 18, height: 18)
                        .background(MurdokuTheme.coral, in: Circle())
                        .accessibilityHidden(true)
                    Text(t("Víctima", "Victim"))
                }
                ForEach(puzzle.objects) { object in
                    // Qualified by room (not just object.name): two carpets
                    // would otherwise render as two identical legend rows.
                    let phrase = puzzle.objectPhrase(object.id)
                    HStack(spacing: 8) {
                        FurnitureIcon(kind: object.kind, tint: MurdokuTheme.furnitureTint).frame(width: 18, height: 18)
                        Text(phrase.prefix(1).uppercased() + phrase.dropFirst())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(MurdokuTheme.text)
        }
    }

    private var placedCount: Int {
        puzzle.suspects.indices.filter { confirmedCell(for: $0) != nil }.count
    }

    private func confirmedCell(for person: Int) -> GridCell? { confirmed[person] }

    private func confirmedOccupant(at cell: GridCell) -> Int? {
        confirmed.first { $0.value == cell }?.key
    }

    /// Every suspect owns exactly one row and one column (the solution is a
    /// pair of permutations), so once ANYONE is confirmed, every other cell
    /// in their row/column is impossible for every other suspect — live
    /// computed from `confirmed`, not stored separately, so it can never go
    /// stale. Drawn the same way regardless of whose line it is (a plain ×):
    /// that's the common case once a few suspects are placed, so it stays
    /// the bulk marking rather than a wash of red across most of the board.
    private func rowColTaken(by cell: GridCell) -> Bool {
        puzzle.suspects.indices.contains { person in
            guard let confirmed = confirmedCell(for: person), confirmed != cell else { return false }
            return confirmed.row == cell.row || confirmed.col == cell.col
        }
    }

    private func toggleExcluded(_ cell: GridCell) {
        pushUndo()
        conflictCell = nil
        let key = excludedKey(cell)
        if excluded.contains(key) { excluded.remove(key) } else { excluded.insert(key) }
        saveMarks()
        PZHaptics.tick()
    }

    /// Clears a cell entirely: the global "nobody here" mark, every
    /// suspect's "maybe here" note, and whoever's confirmed there.
    private func eraseCell(_ cell: GridCell) {
        pushUndo()
        conflictCell = nil
        excluded.remove(excludedKey(cell))
        for person in puzzle.suspects.indices {
            candidates.remove(candidateKey(person: person, cell: cell))
            if confirmed[person] == cell { confirmed[person] = nil }
        }
        saveMarks()
        PZHaptics.tick()
    }

    private func toggleCandidate(_ cell: GridCell) {
        pushUndo()
        conflictCell = nil
        let key = candidateKey(person: selected, cell: cell)
        if candidates.contains(key) { candidates.remove(key) } else { candidates.insert(key) }
        saveMarks()
        PZHaptics.tick()
    }

    private func attemptConfirm(_ cell: GridCell) {
        conflictCell = nil
        let blockingFurniture = puzzle.objects.first { $0.cell == cell }?.kind.blocksPerson ?? false
        guard cell != puzzle.victim, !blockingFurniture else {
            toast = PZToast(text: t("Esa casilla ya está ocupada en el plano", "That cell is already occupied on the floor plan"), kind: .error)
            PZHaptics.error()
            return
        }
        // Tocar una casilla ya ocupada quita a quien esté ahí (sea o no el
        // sospechoso seleccionado): en esa casilla nadie más puede ir.
        if let occupant = confirmedOccupant(at: cell) {
            pushUndo()
            confirmed[occupant] = nil
            saveMarks()
            PZHaptics.tick()
            return
        }
        // Si el seleccionado ya estaba colocado en otra casilla, esta acción lo
        // mueve (canConfirm ya ignora al seleccionado al validar fila/columna).
        guard canConfirm(cell) else {
            toast = PZToast(text: t("Ya hay una persona en esa fila o columna", "There is already someone in that row or column"), kind: .error)
            PZHaptics.error()
            // A one-cell, one-tap flash distinct from the ongoing × above:
            // this is the single square that just failed, not the whole
            // row/column.
            conflictCell = cell
            return
        }
        pushUndo()
        confirmed[selected] = cell // sobrescribe su casilla anterior si la tenía
        // Confirmed supersedes every suspect's "maybe here" note on this
        // cell — it's occupied now, not a guess anymore — and any manual
        // "nobody here" mark, which would otherwise contradict it.
        for person in puzzle.suspects.indices {
            candidates.remove(candidateKey(person: person, cell: cell))
        }
        excluded.remove(excludedKey(cell))
        saveMarks()
        PZHaptics.tick()
    }

    private func excludedKey(_ cell: GridCell) -> String { "x-\(cell.row)-\(cell.col)" }
    private func confirmedKey(_ person: Int) -> String { "f\(person)" }
    private func candidateKey(person: Int, cell: GridCell) -> String {
        "c\(person)-\(cell.row)-\(cell.col)"
    }

    private func candidateSuspects(at cell: GridCell) -> [Int] {
        puzzle.suspects.indices.filter { candidates.contains(candidateKey(person: $0, cell: cell)) }
    }

    private func pushUndo() {
        undoStack.append(Snapshot(excluded: excluded, confirmed: confirmed, candidates: candidates))
        if undoStack.count > 50 { undoStack.removeFirst(undoStack.count - 50) }
    }

    private func undo() {
        guard let last = undoStack.popLast() else {
            PZHaptics.error()
            return
        }
        excluded = last.excluded
        confirmed = last.confirmed
        candidates = last.candidates
        conflictCell = nil
        saveMarks()
        PZHaptics.tick()
    }

    /// Whether `selected` can be confirmed at `cell` given who else is
    /// already placed. Whether `selected` themself is already placed
    /// elsewhere is checked separately in `attemptConfirm`, with its own
    /// toast — that failure isn't a row/column conflict, so it shouldn't say
    /// it is.
    private func canConfirm(_ cell: GridCell) -> Bool {
        for person in puzzle.suspects.indices where person != selected {
            guard let other = confirmedCell(for: person) else { continue }
            if other == cell || other.row == cell.row || other.col == cell.col { return false }
        }
        return true
    }

    private func solve() {
        let solved = puzzle.suspects.indices.allSatisfy { confirmedCell(for: $0) == puzzle.solution[$0] }
        guard solved else {
            toast = PZToast(text: t("Alguna posición no encaja con las pistas", "Some positions do not match the clues"), kind: .error)
            PZHaptics.error()
            return
        }
        progress.markDone(puzzle.id)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(elapsed), kind: .murdoku, puzzleID: puzzle.id)
        progress.noteDayIfComplete()
        showClosed = true
    }

    /// Lo que enseña la hoja «Caso cerrado»: los mismos datos que daba la
    /// hoja de resultado anterior (culpable, estancia, tiempo, comparación
    /// con la media, sospechosos y texto para compartir).
    private func closedCase() -> MurdokuClosedCase {
        let killer = puzzle.killerIndex
        let room = puzzle.rooms[puzzle.victimRoom]
        let clock = PuzzleTiming.clock(TimeInterval(elapsed))
        let average = PuzzleTiming.average(kind: .murdoku, itemCount: puzzle.suspects.count,
                                           boardSize: puzzle.size)
        let comparison = PuzzleTiming.comparison(elapsed: TimeInterval(elapsed), average: average.seconds,
                                                 personal: average.personal, kind: .murdoku)
        return MurdokuClosedCase(
            english: puzzle.language == .english,
            title: puzzle.title,
            phrase: t("\(puzzle.killer) quedó a solas con la víctima en la estancia \(room).",
                      "\(puzzle.killer) was alone with the victim in the \(room)."),
            culprit: puzzle.killer,
            culpritIndex: killer,
            culpritColor: suspectColor(killer),
            culpritLines: [("mappin.and.ellipse", t("En la estancia \(room)", "In the \(room)")),
                           ("person.fill.questionmark", t("La única persona junto a la víctima", "The only person with the victim"))],
            summary: [("clock", clock),
                      ("chart.bar", comparison.prefix(1).uppercased() + comparison.dropFirst()),
                      ("person.2", t("\(puzzle.suspects.count) sospechosos colocados", "\(puzzle.suspects.count) suspects placed")),
                      ("checklist", t("\(checkedClues.count) de \(puzzle.clues.count) pistas marcadas", "\(checkedClues.count) of \(puzzle.clues.count) clues checked"))],
            shareText: t("NewsRaider Murdoku · \(puzzle.size)×\(puzzle.size) · caso resuelto en \(clock)", "NewsRaider Murdoku · \(puzzle.size)×\(puzzle.size) · case solved in \(clock)")
        )
    }

    #if DEBUG
    /// Ayuda de verificación, solo Debug y solo en memoria (no guarda nada):
    /// NR_MURDOKU_DEMO=marks|clue|solved|closed prepara un estado para las
    /// capturas.
    private func applyDebugDemo() {
        guard let demo = ProcessInfo.processInfo.environment["NR_MURDOKU_DEMO"], !demo.isEmpty else { return }
        let all = demo == "solved" || demo == "closed"
        excluded = []; candidates = []; confirmed = [:]; checkedClues = []
        for person in puzzle.suspects.indices.prefix(all ? puzzle.suspects.count : 3) {
            confirmed[person] = puzzle.solution[person]
        }
        if all {
            checkedClues = Set(puzzle.clues.indices)
        } else {
            let free = (0..<puzzle.size).flatMap { row in (0..<puzzle.size).map { GridCell(row: row, col: $0) } }
                .filter { $0 != puzzle.victim && !rowColTaken(by: $0) && confirmedOccupant(at: $0) == nil }
            for cell in free.prefix(2) { candidates.insert(candidateKey(person: 3, cell: cell)) }
            if let cell = free.dropFirst(2).first { candidates.insert(candidateKey(person: 4, cell: cell)) }
            for cell in free.dropFirst(3).prefix(1) { excluded.insert(excludedKey(cell)) }
            selected = 3
            if demo == "clue" {
                checkedClues = Set(puzzle.clues.indices.prefix(3))
                focusedClue = min(3, puzzle.clues.count - 1)
            }
        }
        if demo == "closed" {
            elapsed = max(elapsed, 168)
            showClosed = true
        }
    }
    #endif

    private func loadMarks() {
        // `excluded`, `confirmed` and `candidates` share one persisted
        // dictionary, split back apart by key prefix: "x-" (excluded, see
        // its property doc comment), "f<person>" (confirmed), "c<person>-"
        // (candidates).
        let stored = progress.fill(puzzle.id)
        excluded = Set(stored.filter { $0.key.hasPrefix("x-") && $0.value == "1" }.map(\.key))
        candidates = Set(stored.filter { $0.key.hasPrefix("c") && $0.value == "1" }.map(\.key))
        checkedClues = Set(stored.keys.compactMap { $0.hasPrefix("k") ? Int($0.dropFirst()) : nil })
        confirmed = [:]
        for person in puzzle.suspects.indices {
            guard let raw = stored[confirmedKey(person)] else { continue }
            let parts = raw.split(separator: "-")
            guard parts.count == 2, let row = Int(parts[0]), let col = Int(parts[1]) else { continue }
            confirmed[person] = GridCell(row: row, col: col)
        }
    }

    private func saveMarks() {
        var fill: [String: String] = [:]
        for key in excluded { fill[key] = "1" }
        for key in candidates { fill[key] = "1" }
        for (person, cell) in confirmed { fill[confirmedKey(person)] = "\(cell.row)-\(cell.col)" }
        for index in checkedClues { fill["k\(index)"] = "1" }
        progress.setFill(puzzle.id, fill)
    }

    private func roomColor(_ room: Int) -> Color { MurdokuTheme.rooms[room % MurdokuTheme.rooms.count] }

    /// One identity color per suspect (there are always exactly 5).
    private func suspectColor(_ index: Int) -> Color { MurdokuTheme.suspects[index % MurdokuTheme.suspects.count] }

    private func accessibilityLabel(for cell: GridCell, occupant: Int?,
                                    object: MurdokuPuzzle.SceneObject?, isVictim: Bool,
                                    manualExcluded: Bool, noted: [Int],
                                    autoExcluded: Bool, isConflict: Bool) -> String {
        var parts = [t("Fila \(cell.row + 1), columna \(cell.col + 1)", "Row \(cell.row + 1), column \(cell.col + 1)"), puzzle.rooms[puzzle.room(at: cell)]]
        if let occupant { parts.append(puzzle.suspects[occupant]) }
        if isVictim { parts.append(t("Víctima", "Victim")) }
        if let object { parts.append("\(object.name), \(object.kind.blocksPerson ? t("bloquea la casilla", "blocks the cell") : t("se puede colocar aquí", "can place someone here"))") }
        if isConflict {
            parts.append(t("No válido: ya hay otra persona en esta fila o columna", "Invalid: another person is already in this row or column"))
        } else if autoExcluded || manualExcluded {
            parts.append(t("Aquí no hay nadie", "Nobody is here"))
        }
        if !noted.isEmpty { parts.append(t("Posibles: \(noted.map { puzzle.suspects[$0] }.joined(separator: ", "))", "Candidates: \(noted.map { puzzle.suspects[$0] }.joined(separator: ", "))")) }
        return parts.joined(separator: ", ")
    }
}
#endif
