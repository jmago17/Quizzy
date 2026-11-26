//
//  WatchPlanesView.swift — Quizzy Watch
//  Escuadrón: avión visto desde arriba sobre un mar que avanza hacia abajo. Dispara solo; la
//  Corona lo mueve de lado a lado. Enemigos: cazas (rectos), acróbatas (en zigzag) y bombarderos
//  (lentos, 4 impactos, disparan apuntando). Los bombarderos pueden soltar una MEJORA temporal
//  (`ArcadeBoost`, 10 s, acumulables: R cadencia, 2 doble, V uve, E escoltas) o un corazón (vida).
//  El disparo base es uno solo y recto. 3 vidas; la dificultad sube cada 20 s.
//  Tonel: un giro brusco de Corona (ver `rollSwing`) hace que el avión dé una vuelta sobre su eje;
//  mientras dura no le alcanza nada. Tiene recarga, para que no sea un escudo permanente.
//  Jefe: cada `bossEvery` segundos de vuelo deja de llegar tráfico y entra el jefe de la zona
//  (`BossKind`: acorazado en el mar, tanque en el desierto, helicóptero en el bosque, cuatrimotor
//  en la ciudad), que se queda arriba cruzando de lado a lado con su propio patrón de disparo.
//  Los que vuelan van morro arriba, en el mismo sentido que el jugador. Cada jefe aguanta más y
//  dispara más seguido. Derribarlo: 300 puntos y un premio seguro.
//  Pantallas: cada jefe derribado cambia de ZONA (mar → desierto → bosque → ciudad → …), con otro
//  suelo y otro decorado; el cartel «ZONA n» lo anuncia. Cañones en tierra (`Turret`): bajan con el
//  suelo, apuntan al avión y disparan; caen con 2 impactos (30 puntos). No se choca con ellos.
//  Dibujos propios (formas en Canvas), sin insignias. Bucle y pantallas: `WatchArcadeStage`.
//  COMPARTIDO CON EL IPHONE (2026-11-25): este fichero y `WatchArcade.swift` entran también en el
//  target de iOS (`project.yml`); allí lo envuelve `Quizzy/Games/SquadronGame.swift`.
//

import SwiftUI

enum WatchPlanes {
    static let band = Color(hex: 0x0E1726)
    static var info: ArcadeInfo {
        ArcadeInfo(id: "planes", title: AppLanguage.text("Escuadrón", "Squadron"),
                   hint: AppLanguage.text("Gira la Corona", "Turn the Crown"), color: Color(hex: 0xF2C14E))
    }

    /// Avión visto desde arriba. `down` = morro hacia abajo (enemigos). `engines` = 2 para el bombardero, 4 para el jefe.
    static func drawPlane(in ctx: inout GraphicsContext, at c: CGPoint, size s: CGFloat, body: Color, wing: Color,
                          down: Bool = false, engines: Int = 1, spin: CGFloat = 0) {
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        if down { g.scaleBy(x: 1, y: -1) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
            g.fill(Path(roundedRect: CGRect(x: (x - w / 2) * s, y: (y - h / 2) * s, width: w * s, height: h * s), cornerRadius: r * s), with: .color(color))
        }
        rect(0, 0.42, 0.42, 0.14, 0.06, wing)                     // cola
        rect(0, -0.04, 1.0, 0.24, 0.1, wing)                      // ala
        let motors: [CGFloat] = engines == 4 ? [-0.4, -0.2, 0.2, 0.4] : (engines == 2 ? [-0.3, 0.3] : [])
        for m in motors { rect(m, -0.12, engines == 4 ? 0.10 : 0.13, 0.3, 0.05, body) }   // motores
        rect(0, 0, 0.2, 1.0, 0.1, body)                           // fuselaje
        rect(0, -0.14, 0.11, 0.2, 0.05, Color(hex: 0x1B2233))     // cabina
        // Hélices: disco fino que «gira» cambiando de ancho.
        let blade = 0.16 + 0.1 * abs(sin(spin))
        if !motors.isEmpty {
            for m in motors { rect(m, -0.29, blade * (engines == 4 ? 0.8 : 1), 0.035, 0.01, .white.opacity(0.7)) }
        } else {
            rect(0, -0.52, blade * 1.5, 0.04, 0.01, .white.opacity(0.7))
        }
    }
}

final class SkyWorld: ArcadeWorld {
    enum Kind { case fighter, weaver, bomber }
    struct Enemy {
        var kind: Kind
        var p: CGPoint
        var baseX: CGFloat
        var hp: Int
        var t: CGFloat = 0
        var fireT: CGFloat = 1
    }
    struct Bullet { var p: CGPoint; var v: CGVector }
    enum PickupKind { case boost(ArcadeBoost), life }
    struct Pickup { var p: CGPoint; var kind: PickupKind }
    /// Un jefe distinto por zona: acorazado en el mar, tanque en el desierto, helicóptero en el
    /// bosque y cuatrimotor en la ciudad. Cada uno con su silueta, su vaivén y su forma de disparar.
    enum BossKind: Int {
        case ship, tank, heli, plane
        /// Media anchura y media altura de la silueta (para el vaivén, la barra de vida y los impactos).
        var half: CGSize {
            switch self {
            case .ship: return CGSize(width: 32, height: 11)
            case .tank: return CGSize(width: 18, height: 20)
            case .heli: return CGSize(width: 22, height: 22)
            case .plane: return CGSize(width: SkyWorld.bossSize / 2, height: SkyWorld.bossSize / 2)
            }
        }
        func hit(_ d: CGPoint) -> Bool {
            let x = abs(d.x), y = abs(d.y)
            switch self {
            case .ship: return x < 32 && y < 11
            case .tank: return x < 18 && y < 20
            case .heli: return (x < 11 && y < 14) || (x < 4 && d.y > 0 && d.y < 24)   // cabina o cola
            // Ala (ancha y baja) o fuselaje (estrecho y largo).
            case .plane: return (x < SkyWorld.bossSize * 0.5 && y < 14) || (x < 7 && y < SkyWorld.bossSize * 0.5)
            }
        }
    }
    struct Boss {
        var kind: BossKind = .plane
        var entered = false
        var burst = 0
        var burstT: CGFloat = 0
        var p: CGPoint
        var hp: Int, maxHp: Int
        var t: CGFloat = 0
        var fireT: CGFloat = 1.6
        var volley = 0
        var flash: CGFloat = 0
    }
    /// Segundos de vuelo (sin contar los combates) entre un jefe y el siguiente.
    static let bossEvery: CGFloat = 60
    static let bossSize: CGFloat = 54
    /// Separación lateral de los escoltas.
    static let wingGap: CGFloat = 19
    /// Alto reservado arriba al marcador (en el iPhone, además, la zona segura).
    var topInset: CGFloat = ArcadeHUD.top
    private var bossY: CGFloat { topInset + 52 }   // su barra de vida queda bajo el marcador

    // iPhone (`SquadronGame`): el avión también sube y baja, el tonel se pide con un toque y el
    // marcador lo pinta la vista. En el reloj no se toca nada de esto.
    /// `true`: `inputY` (0 = arriba … 1 = abajo) mueve el avión en vertical dentro de su franja.
    var free2D = false
    var inputY: CGFloat = 1
    /// Distancia del avión al borde inferior cuando está abajo del todo.
    var bottomInset: CGFloat = 26
    /// `false`: un movimiento brusco no dispara el tonel (con el dedo saldría sin querer).
    var swingRolls = true
    /// `false`: no pinta vidas ni la barra del triple disparo.
    var drawsHUD = true
    /// `false`: no pinta los carteles de zona y de jefe (pantalla de inicio del iPhone).
    var showsBanners = true
    /// Multiplica el tiempo entre enemigos: el campo del iPhone es más alto y quedaba vacío.
    var spawnScale: CGFloat = 1
    private var rollRequest = false
    func requestRoll() { rollRequest = true }
    /// 0…1: 1 = tonel disponible.
    var rollCharge: CGFloat { 1 - min(1, rollWait / Self.rollCooldown) }
    private var restY: CGFloat {
        guard free2D else { return size.height - 26 }
        let hi = size.height - bottomInset, lo = min(hi, max(topInset + 110, size.height * 0.42))
        return lo + min(1, max(0, inputY)) * (hi - lo)
    }

    /// Decorado del suelo; se dibuja según la zona en la que nació (isla, duna, arboleda, manzana).
    struct Island { var x: CGFloat; var y: CGFloat; var w: CGFloat; var h: CGFloat; var zone = 0; var seed = 0 }
    struct Turret { var p: CGPoint; var hp = 2; var fireT: CGFloat = 1.2; var flash: CGFloat = 0; var zone = 0 }
    static let zoneCount = 4
    static func zoneName(_ zone: Int) -> String {
        switch zone % zoneCount {
        case 1: return AppLanguage.text("DESIERTO", "DESERT")
        case 2: return AppLanguage.text("BOSQUE", "FOREST")
        case 3: return AppLanguage.text("CIUDAD", "CITY")
        default: return AppLanguage.text("MAR", "SEA")
        }
    }

    private var size: CGSize = .zero
    private var enemies: [Enemy] = []
    private var shots: [Bullet] = []
    private var bullets: [Bullet] = []
    private var pickups: [Pickup] = []
    private var islands: [Island] = []
    private var turrets: [Turret] = []
    private var turretT: CGFloat = 9
    private var zone = 0
    private var zoneFade: CGFloat = 0        // 1 → 0: el suelo nuevo aparece sobre el anterior
    private var zoneBanner: CGFloat = 0
    private var sparks: [Spark] = []
    private var px: CGFloat = 0, py: CGFloat = 0
    private(set) var lives = 3
    private var time: CGFloat = 0, scroll: CGFloat = 0
    private var fireT: CGFloat = 0, spawnT: CGFloat = 1, islandT: CGFloat = 2
    /// Mejoras temporales activas (cadencia, doble, uve, escoltas).
    private(set) var boosts = ArcadeBoosts()
    private var invuln: CGFloat = 0
    /// Tonel. Se dispara cuando el recorrido reciente de la Corona en un mismo sentido supera
    /// `rollSwing` (fracción del ancho). El recorrido «se olvida» con constante `rollMemory`, así
    /// que equivale a pedir una velocidad sostenida de rollSwing / rollMemory ≈ 0,7 anchos/s (bajado de 0,28 al
    /// reducir la Corona 2,5×: el gesto físico queda parecido, algo más amplio).
    static let rollSwing: CGFloat = 0.14
    static let rollMemory: CGFloat = 0.2
    static let rollTime: CGFloat = 0.55
    static let rollCooldown: CGFloat = 2.5
    private var roll: CGFloat = 0          // segundos que le quedan al tonel
    private var rollDir: CGFloat = 1
    private var rollWait: CGFloat = 0
    private var swing: CGFloat = 0
    private var lastInput: CGFloat?
    #if DEBUG
    private let alwaysRoll = ProcessInfo.processInfo.environment["QW_ROLL"] == "1"   // capturas: tonel continuo
    #endif

    private var boss: Boss?
    private var bossT: CGFloat = SkyWorld.bossEvery   // cuenta atrás hasta el aviso
    private var bossWarn: CGFloat = 0                  // aviso «¡JEFE!» antes de que entre
    private var bossCount = 0
    private(set) var score = 0

    private var level: CGFloat { 1 + floor(time / 20) }

    func reset(size: CGSize) {
        self.size = size
        enemies = []; shots = []; bullets = []; pickups = []; sparks = []
        islands = [Island(x: size.width * 0.25, y: size.height * 0.3, w: 46, h: 30)]
        turrets = []; turretT = 9; zone = 0; zoneFade = 0; zoneBanner = 2
        px = size.width / 2; py = restY
        lives = 3; time = 0; scroll = 0; score = 0
        fireT = 0.2; spawnT = 1; islandT = 3; boosts.clear(); invuln = 0
        boss = nil; bossWarn = 0; bossCount = 0; bossT = Self.bossEvery
        roll = 0; rollWait = 0; swing = 0; lastInput = nil; rollRequest = false
        #if DEBUG
        if ProcessInfo.processInfo.environment["QW_BOSS"] == "1" { bossT = 2 }   // capturas: jefe enseguida
        if ProcessInfo.processInfo.environment["QW_BOOST"] == "1" { ArcadeBoost.allCases.forEach { boosts.take($0) } }   // capturas: todas las mejoras
        if let z = ProcessInfo.processInfo.environment["QW_ZONE"].flatMap({ Int($0) }) {   // capturas: empezar en la zona z
            zone = z; islands = []; islandT = 0.2; turretT = 2
        }
        #endif
    }

    func resize(_ size: CGSize) { self.size = size }

    func step(dt: CGFloat, input: CGFloat) -> ArcadeEvent {
        guard size.width > 0, lives > 0 else { return .none }
        var event = ArcadeEvent.none
        time += dt
        scroll += 42 * dt
        // A 26 pt del fondo y 17 de los lados: las esquinas de la pantalla son redondas.
        px = 17 + input * (size.width - 34)
        py = restY
        zoneFade = max(0, zoneFade - dt / 1.2)
        zoneBanner = max(0, zoneBanner - dt)
        invuln = max(0, invuln - dt)
        boosts.step(dt: dt)

        // Tonel: recorrido reciente de la Corona en un sentido.
        swing *= exp(-dt / Self.rollMemory)
        if let last = lastInput { swing += input - last }
        lastInput = input
        roll = max(0, roll - dt)
        rollWait = max(0, rollWait - dt)
        var wantRoll = (swingRolls && abs(swing) > Self.rollSwing) || rollRequest
        rollRequest = false
        #if DEBUG
        if alwaysRoll { wantRoll = true; rollWait = 0 }
        #endif
        if wantRoll, roll <= 0, rollWait <= 0 {
            roll = Self.rollTime; rollWait = Self.rollCooldown
            rollDir = swing >= 0 ? 1 : -1
            swing = 0
            event = .bonus
            #if DEBUG
            if ArcadeProbe.shared.fps { print("QWROLL t=\(time)") }
            #endif
        }
        Spark.step(&sparks, dt: dt)

        // Fondo: islas que bajan con el mar.
        for i in islands.indices { islands[i].y += 42 * dt }
        islands.removeAll { $0.y - $0.h > size.height }
        islandT -= dt
        // En el mar no salen islas nuevas con el jefe (un acorazado) en pantalla: navegaría por encima.
        let seaBoss = zone % Self.zoneCount == 0 && (boss != nil || bossWarn > 0)
        if islandT <= 0, !seaBoss {
            let w = CGFloat.random(in: 30...62)
            islands.append(Island(x: CGFloat.random(in: 10...(size.width - 10)), y: -w, w: w, h: w * CGFloat.random(in: 0.55...0.85),
                                  zone: zone, seed: Int.random(in: 0..<1000)))
            islandT = zone % Self.zoneCount == 0 ? CGFloat.random(in: 2.5...5) : CGFloat.random(in: 1.1...2.4)
        }

        // Cañones en tierra: bajan con el suelo y disparan apuntando mientras quedan por encima del avión.
        turretT -= dt
        if turretT <= 0, boss == nil, bossWarn <= 0 {
            turretT = max(3.2, 7 - level * 0.3) * CGFloat.random(in: 0.8...1.3)
            turrets.append(Turret(p: CGPoint(x: CGFloat.random(in: 22...(size.width - 22)), y: -14), zone: zone))
        }
        for i in turrets.indices {
            turrets[i].p.y += 42 * dt
            turrets[i].flash = max(0, turrets[i].flash - dt)
            turrets[i].fireT -= dt
            if turrets[i].fireT <= 0, turrets[i].p.y > 8, turrets[i].p.y < py - 55 {
                turrets[i].fireT = max(1.3, 2.3 - level * 0.08)
                let dx = px - turrets[i].p.x, dy = py - turrets[i].p.y, d = max(1, hypot(dx, dy))
                bullets.append(Bullet(p: CGPoint(x: turrets[i].p.x + dx / d * 8, y: turrets[i].p.y + dy / d * 8),
                                      v: CGVector(dx: dx / d * 88, dy: dy / d * 88)))
            }
        }
        turrets.removeAll { $0.p.y > size.height + 16 }

        // Disparo automático: uno, recto. Las mejoras lo doblan, lo abren en uve, lo aceleran
        // o le ponen dos escoltas que disparan a la vez.
        fireT -= dt
        if fireT <= 0 {
            fireT = boosts.on(.rapid) ? 0.11 : 0.2
            func shot(_ dx: CGFloat, _ dy: CGFloat, _ vx: CGFloat = 0) {
                shots.append(Bullet(p: CGPoint(x: px + dx, y: py + dy), v: CGVector(dx: vx, dy: vx == 0 ? -300 : -290)))
            }
            if boosts.on(.double) { shot(-4, -10); shot(4, -10) } else { shot(0, -11) }
            if boosts.on(.spread) { shot(-7, -6, -70); shot(7, -6, 70) }
            if boosts.on(.wing) { shot(-Self.wingGap, 0); shot(Self.wingGap, 0) }
        }
        for i in shots.indices { shots[i].p.x += shots[i].v.dx * dt; shots[i].p.y += shots[i].v.dy * dt }
        shots.removeAll { $0.p.y < -8 || $0.p.x < -8 || $0.p.x > size.width + 8 }

        // Jefe: aviso, entrada y combate. Mientras tanto no llega tráfico nuevo.
        if boss == nil, bossWarn <= 0 {
            bossT -= dt
            if bossT <= 0 { bossWarn = 2; event = .hit }
        } else if boss == nil {
            bossWarn -= dt
            if bossWarn <= 0 {
                bossCount += 1
                let hp = 50 + 25 * bossCount   // sin mejoras y con puntería perfecta caen 5 impactos/s; con todas, unos 30
                boss = Boss(kind: BossKind(rawValue: zone % Self.zoneCount) ?? .plane,
                            p: CGPoint(x: size.width / 2, y: -Self.bossSize), hp: hp, maxHp: hp)
            }
        }
        if var b = boss {
            b.t += dt
            b.flash = max(0, b.flash - dt)
            if !b.entered {
                b.p.y = min(bossY, b.p.y + 50 * dt)
                if b.p.y >= bossY { b.entered = true; b.t = 0 }   // el vaivén arranca centrado, sin salto
            } else {
                let amp = size.width / 2 - b.kind.half.width - 2
                let rate = max(0.85, 1.7 - CGFloat(bossCount) * 0.15)
                func shoot(_ from: CGPoint, _ angle: CGFloat, _ speed: CGFloat) {
                    bullets.append(Bullet(p: from, v: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)))
                }
                func aim(_ from: CGPoint) -> CGFloat { atan2(py - from.y, px - from.x) }
                b.fireT -= dt
                switch b.kind {
                case .plane:
                    b.p.x = size.width / 2 + sin(b.t * 0.9) * amp
                    if b.fireT <= 0 {
                        b.fireT = rate
                        b.volley += 1
                        let from = CGPoint(x: b.p.x, y: b.p.y + 20)
                        if b.volley % 2 == 1 {
                            // Abanico de 3, el central apuntado al jugador.
                            for da in [-0.32, 0, 0.32] as [CGFloat] { shoot(from, aim(from) + da, 92) }
                        } else {
                            // Ráfaga recta desde los motores de fuera: deja hueco en el centro.
                            for dx in [-0.4, 0.4] as [CGFloat] {
                                shoot(CGPoint(x: b.p.x + dx * Self.bossSize, y: b.p.y + 10), .pi / 2, 105)
                            }
                        }
                    }
                case .ship:
                    // Lento y ancho: las dos torres apuntan; cada dos andanadas, abanico desde el puente.
                    b.p.x = size.width / 2 + sin(b.t * 0.5) * amp
                    if b.fireT <= 0 {
                        b.fireT = rate
                        b.volley += 1
                        if b.volley % 2 == 1 {
                            for dx in [-18, 18] as [CGFloat] {
                                let from = CGPoint(x: b.p.x + dx, y: b.p.y)
                                shoot(from, aim(from), 96)
                            }
                        } else {
                            for da in [-0.56, -0.28, 0, 0.28, 0.56] as [CGFloat] {
                                shoot(CGPoint(x: b.p.x, y: b.p.y + 8), .pi / 2 + da, 84)
                            }
                        }
                    }
                case .tank:
                    // Avanza a tirones; un obús rápido apuntado y, cada tres, metralla en semicírculo.
                    b.p.x = size.width / 2 + sin(b.t * 0.6 + sin(b.t * 1.2) * 0.5) * amp
                    if b.fireT <= 0 {
                        b.fireT = rate * 0.8
                        b.volley += 1
                        if b.volley % 3 == 0 {
                            for k in 0..<6 { shoot(b.p, 0.35 + CGFloat(k) * (.pi - 0.7) / 5, 78) }
                        } else {
                            let a = aim(b.p)
                            shoot(CGPoint(x: b.p.x + cos(a) * 20, y: b.p.y + sin(a) * 20), a, 150)
                        }
                    }
                case .heli:
                    // Nervioso: va y viene rápido, sube y baja, y suelta ráfagas de tres.
                    b.p.x = size.width / 2 + sin(b.t * 1.3) * amp
                    b.p.y = bossY + sin(b.t * 2.1) * 9
                    if b.fireT <= 0 {
                        b.fireT = rate * 1.15
                        b.volley += 1
                        b.burst = 3; b.burstT = 0
                        if b.volley % 2 == 0 {
                            for dx in [-11, 11] as [CGFloat] { shoot(CGPoint(x: b.p.x + dx, y: b.p.y + 6), .pi / 2, 120) }
                        }
                    }
                    if b.burst > 0 {
                        b.burstT -= dt
                        if b.burstT <= 0 {
                            b.burst -= 1; b.burstT = 0.14
                            let from = CGPoint(x: b.p.x, y: b.p.y + 14)
                            shoot(from, aim(from), 112)
                        }
                    }
                }
            }
            boss = b
        }

        // Enemigos nuevos.
        spawnT -= dt
        if spawnT <= 0, boss == nil, bossWarn <= 0 {
            spawnT = max(0.55, 1.45 - level * 0.09) * CGFloat.random(in: 0.75...1.25) * spawnScale
            let x = CGFloat.random(in: 16...(size.width - 16))
            let roll = CGFloat.random(in: 0..<1)
            if roll < 0.14 + min(0.1, level * 0.01) {
                enemies.append(Enemy(kind: .bomber, p: CGPoint(x: x, y: -18), baseX: x, hp: 4, fireT: 0.8))
            } else if roll < 0.45 {
                enemies.append(Enemy(kind: .weaver, p: CGPoint(x: x, y: -12), baseX: min(max(x, 44), size.width - 44), hp: 1))
            } else if roll < 0.6 {
                // Tres cazas en cuña.
                let cx = min(max(x, 34), size.width - 34)
                for (dx, dy) in [(0.0, 0.0), (-20.0, -14.0), (20.0, -14.0)] as [(CGFloat, CGFloat)] {
                    enemies.append(Enemy(kind: .fighter, p: CGPoint(x: cx + dx, y: -12 + dy), baseX: cx + dx, hp: 1))
                }
            } else {
                enemies.append(Enemy(kind: .fighter, p: CGPoint(x: x, y: -12), baseX: x, hp: 1))
            }
        }

        for i in enemies.indices {
            enemies[i].t += dt
            switch enemies[i].kind {
            case .fighter:
                enemies[i].p.y += (82 + level * 5) * dt
            case .weaver:
                enemies[i].p.y += (64 + level * 4) * dt
                enemies[i].p.x = enemies[i].baseX + sin(enemies[i].t * 3.2) * 30
            case .bomber:
                enemies[i].p.y += 34 * dt
                enemies[i].fireT -= dt
                if enemies[i].fireT <= 0, enemies[i].p.y > 0, enemies[i].p.y < py - 40 {
                    enemies[i].fireT = max(1.0, 1.9 - level * 0.08)
                    let dx = px - enemies[i].p.x, dy = py - enemies[i].p.y, d = max(1, hypot(dx, dy))
                    bullets.append(Bullet(p: enemies[i].p, v: CGVector(dx: dx / d * 95, dy: dy / d * 95)))
                }
            }
        }
        enemies.removeAll { $0.p.y > size.height + 24 }

        for i in bullets.indices { bullets[i].p.x += bullets[i].v.dx * dt; bullets[i].p.y += bullets[i].v.dy * dt }
        bullets.removeAll { $0.p.y > size.height + 8 || $0.p.x < -8 || $0.p.x > size.width + 8 }
        for i in pickups.indices { pickups[i].p.y += 46 * dt }
        pickups.removeAll { $0.p.y > size.height + 10 }

        // Disparos contra enemigos.
        for i in shots.indices.reversed() {
            let s = shots[i].p
            if let b = boss, b.kind.hit(CGPoint(x: s.x - b.p.x, y: s.y - b.p.y)) {
                shots.remove(at: i)
                boss!.hp -= 1
                boss!.flash = 0.08
                Spark.burst(&sparks, at: s, color: .white, count: 2)
                if boss!.hp <= 0 {
                    let at = boss!.p
                    for d in [(-18.0, -6.0), (0.0, 0.0), (18.0, -6.0), (0.0, 16.0)] as [(CGFloat, CGFloat)] {
                        Spark.burst(&sparks, at: CGPoint(x: at.x + d.0, y: at.y + d.1), color: Color(hex: 0xF2B95C), count: 14)
                    }
                    score += 300
                    pickups.append(Pickup(p: at, kind: lives < 3 ? .life : .boost(boosts.drop())))
                    bullets.removeAll()
                    boss = nil
                    bossT = Self.bossEvery
                    // Pantalla superada: cambia la zona (suelo y decorado).
                    zone += 1; zoneFade = 1; zoneBanner = 2.6; turretT = 5
                    event = .bonus
                }
                continue
            }
            if let k = turrets.firstIndex(where: { abs($0.p.x - s.x) < 9 && abs($0.p.y - s.y) < 9 }) {
                shots.remove(at: i)
                turrets[k].hp -= 1
                turrets[k].flash = 0.1
                if turrets[k].hp <= 0 {
                    Spark.burst(&sparks, at: turrets[k].p, color: Color(hex: 0xF2B95C), count: 12)
                    turrets.remove(at: k)
                    score += 30
                } else {
                    Spark.burst(&sparks, at: s, color: .white, count: 3)
                }
                continue
            }
            guard let j = enemies.firstIndex(where: {
                let r: CGFloat = $0.kind == .bomber ? 13 : 9
                return abs($0.p.x - s.x) < r && abs($0.p.y - s.y) < r
            }) else { continue }
            shots.remove(at: i)
            enemies[j].hp -= 1
            if enemies[j].hp > 0 {
                Spark.burst(&sparks, at: s, color: .white, count: 3)
                continue
            }
            let e = enemies.remove(at: j)
            switch e.kind {
            case .fighter: score += 10
            case .weaver: score += 15
            case .bomber:
                score += 50
                if CGFloat.random(in: 0..<1) < 0.55 {
                    pickups.append(Pickup(p: e.p, kind: lives < 3 && Int.random(in: 0..<3) == 0 ? .life : .boost(boosts.drop())))
                }
            }
            Spark.burst(&sparks, at: e.p, color: Color(hex: 0xF2B95C), count: e.kind == .bomber ? 16 : 9)
        }

        // Recoger premios.
        if let k = pickups.firstIndex(where: { abs($0.p.x - px) < 13 && abs($0.p.y - py) < 13 }) {
            switch pickups.remove(at: k).kind {
            case .boost(let kind): boosts.take(kind)
            case .life: lives = min(3, lives + 1)
            }
            event = .bonus
        }

        // Golpes al avión.
        if invuln <= 0, roll <= 0 {
            var hit = false
            if let b = bullets.firstIndex(where: { abs($0.p.x - px) < 7 && abs($0.p.y - py) < 8 }) { bullets.remove(at: b); hit = true }
            if let j = enemies.firstIndex(where: { abs($0.p.x - px) < ($0.kind == .bomber ? 17 : 12) && abs($0.p.y - py) < 12 }) {
                Spark.burst(&sparks, at: enemies[j].p, color: Color(hex: 0xF2B95C))
                if enemies[j].kind != .bomber { enemies.remove(at: j) }
                hit = true
            }
            if hit {
                lives -= 1
                Spark.burst(&sparks, at: CGPoint(x: px, y: py), color: WatchPlanes.info.color, count: 14)
                invuln = 1.6
                bullets.removeAll()
                if lives <= 0 { return .dead }
                event = .hit
            }
        }
        return event
    }

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        // Suelo de la zona; al cambiar de pantalla el nuevo aparece fundido sobre el anterior.
        if zoneFade > 0 {
            drawGround(&ctx, size: size, zone: zone - 1)
            var over = ctx
            over.opacity = Double(1 - zoneFade)
            drawGround(&over, size: size, zone: zone)
        } else {
            drawGround(&ctx, size: size, zone: zone)
        }
        for isle in islands { drawDecor(&ctx, isle) }
        for t in turrets { drawTurret(&ctx, t) }
        for p in pickups {
            let rect = CGRect(x: p.p.x - 7, y: p.p.y - 7, width: 14, height: 14)
            switch p.kind {
            case .boost(let kind): kind.draw(at: p.p, in: &ctx)
            case .life:
                ctx.fill(Path(ellipseIn: rect), with: .color(.white))
                ctx.draw(Text("♥").font(.system(size: 9, weight: .black)).foregroundColor(Color(hex: 0xF0766B)), at: p.p)
            }
        }
        for e in enemies {
            switch e.kind {
            case .fighter:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 17, body: Color(hex: 0xC9534A), wing: Color(hex: 0xA03E38), down: true, spin: time * 40)
            case .weaver:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 17, body: Color(hex: 0x9C7BD6), wing: Color(hex: 0x7558AE), down: true, spin: time * 40)
            case .bomber:
                WatchPlanes.drawPlane(in: &ctx, at: e.p, size: 30, body: Color(hex: 0x7C8F86), wing: Color(hex: 0x5E7068), down: true, engines: 2, spin: time * 40)
            }
        }
        if let b = boss {
            drawBoss(&ctx, b)
            // Vida del jefe, encima de él.
            let w: CGFloat = 40, y = b.p.y - b.kind.half.height - (b.kind == .heli ? 9 : 7)
            ctx.fill(Path(roundedRect: CGRect(x: b.p.x - w / 2, y: y, width: w, height: 3.5), cornerRadius: 1.75), with: .color(.black.opacity(0.45)))
            ctx.fill(Path(roundedRect: CGRect(x: b.p.x - w / 2, y: y, width: w * CGFloat(max(0, b.hp)) / CGFloat(b.maxHp), height: 3.5), cornerRadius: 1.75),
                     with: .color(Color(hex: 0xF0766B)))
        }
        for s in shots {
            ctx.fill(Path(roundedRect: CGRect(x: s.p.x - 1.1, y: s.p.y - 4, width: 2.2, height: 8), cornerRadius: 1.1), with: .color(Color(hex: 0xFFF2B0)))
        }
        for b in bullets {
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - 2.6, y: b.p.y - 2.6, width: 5.2, height: 5.2)), with: .color(Color(hex: 0xFF8A6B)))
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - 1.1, y: b.p.y - 1.1, width: 2.2, height: 2.2)), with: .color(.white))
        }
        if lives > 0, invuln <= 0 || Int(time * 12) % 2 == 0 {
            if boosts.on(.wing) {
                // Escoltas: dos cazas pequeños, uno a cada lado y algo retrasados.
                for side in [-1, 1] as [CGFloat] {
                    let c = CGPoint(x: px + side * Self.wingGap, y: py + 7 + sin(time * 5 + side) * 1.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - 1, y: c.y + 6, width: 11, height: 4)), with: .color(.black.opacity(0.16)))
                    WatchPlanes.drawPlane(in: &ctx, at: c, size: 13, body: Color(hex: 0x9FE3A9), wing: Color(hex: 0x5FB36E), spin: time * 40)
                }
            }
            // Sombra sobre el mar + avión.
            ctx.fill(Path(ellipseIn: CGRect(x: px - 2, y: py + 8, width: 18, height: 7)), with: .color(.black.opacity(0.18)))
            if roll > 0 {
                // Vuelta sobre el eje del fuselaje: el ancho se encoge, pasa por el canto y vuelve.
                // Boca abajo se ve la panza, más oscura. Sube un poco durante el giro.
                let turn = (1 - roll / Self.rollTime) * 2 * .pi
                let c = cos(turn)
                var g = ctx
                g.translateBy(x: px, y: py - sin(turn / 2) * 5)
                g.scaleBy(x: rollDir * (c >= 0 ? max(0.1, c) : min(-0.1, c)), y: 1 + sin(turn / 2) * 0.12)
                WatchPlanes.drawPlane(in: &g, at: .zero, size: 22, body: c >= 0 ? Color(hex: 0xF2C14E) : Color(hex: 0xB9892A),
                                      wing: c >= 0 ? Color(hex: 0xD99E2B) : Color(hex: 0x8F6A1E), spin: time * 40)
            } else {
                WatchPlanes.drawPlane(in: &ctx, at: CGPoint(x: px, y: py), size: 22, body: Color(hex: 0xF2C14E), wing: Color(hex: 0xD99E2B), spin: time * 40)
            }
        }
        Spark.draw(sparks, in: &ctx)
        if drawsHUD { drawLives(lives, in: &ctx, width: size.width) }
        // Lo que queda de cada mejora, bajo el marcador.
        if drawsHUD { boosts.drawBars(in: &ctx, origin: CGPoint(x: ArcadeHUD.left, y: ArcadeHUD.y + 10), width: 34, height: 3) }
        if showsBanners, zoneBanner > 0, bossWarn <= 0 {
            let a = Double(min(1, zoneBanner * 2))
            ctx.draw(Text(AppLanguage.text("ZONA \(zone + 1)", "ZONE \(zone + 1)")).font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.8 * a)), at: CGPoint(x: size.width / 2, y: size.height * 0.36))
            ctx.draw(Text(Self.zoneName(zone)).font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(a)), at: CGPoint(x: size.width / 2, y: size.height * 0.36 + 17))
        }
        if showsBanners, bossWarn > 0, Int(time * 6) % 2 == 0 {
            ctx.draw(Text(AppLanguage.text("¡JEFE!", "BOSS!")).font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0xF0766B)), at: CGPoint(x: size.width / 2, y: size.height * 0.4))
        }
    }

    // MARK: Zonas

    private func drawGround(_ ctx: inout GraphicsContext, size: CGSize, zone: Int) {
        let full = Path(CGRect(x: 0, y: -40, width: size.width, height: size.height + 80))
        func grad(_ a: UInt32, _ b: UInt32) {
            ctx.fill(full, with: .linearGradient(Gradient(colors: [Color(hex: a), Color(hex: b)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        }
        /// Motas fijas que bajan con el suelo: `draw` recibe la posición y el índice.
        func scatter(_ count: Int, _ draw: (CGPoint, Int) -> Void) {
            let n = count * max(1, Int(size.width * size.height / (187 * 223) + 0.5))
            for i in 0..<n {
                let x = CGFloat((i * 67 + 13) % 100) / 100 * size.width
                let y = (CGFloat((i * 139 + 29) % 100) / 100 * size.height + scroll).truncatingRemainder(dividingBy: size.height)
                draw(CGPoint(x: x, y: y), i)
            }
        }
        switch zone % Self.zoneCount {
        case 1:   // Desierto: arena con ondas de duna.
            grad(0xC79A52, 0xDDB56E)
            scatter(14) { p, i in
                var ripple = Path()
                ripple.move(to: CGPoint(x: p.x - 9, y: p.y))
                ripple.addQuadCurve(to: CGPoint(x: p.x + 9, y: p.y), control: CGPoint(x: p.x, y: p.y - (i % 2 == 0 ? 4 : 2.5)))
                ctx.stroke(ripple, with: .color(Color(hex: 0x9A7238).opacity(0.45)), lineWidth: 1.2)
            }
        case 2:   // Bosque: prado con matas.
            grad(0x2F6B3C, 0x3F8048)
            scatter(18) { p, i in
                let r: CGFloat = i % 3 == 0 ? 3 : 2
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.7, width: r * 2, height: r * 1.4)),
                         with: .color((i % 2 == 0 ? Color(hex: 0x245730) : Color(hex: 0x5C9C58)).opacity(0.7)))
            }
        case 3:   // Ciudad: asfalto con una avenida y pasos de calle.
            grad(0x3A404C, 0x4A515E)
            let road = CGRect(x: size.width * 0.5 - 13, y: -40, width: 26, height: size.height + 80)
            ctx.fill(Path(road), with: .color(Color(hex: 0x23272F)))
            let dashes = max(8, Int(size.height / 30) + 2)
            for k in 0..<dashes {
                let y = (CGFloat(k) * 30 + scroll).truncatingRemainder(dividingBy: CGFloat(dashes) * 30) - 20
                ctx.fill(Path(CGRect(x: road.midX - 1, y: y, width: 2, height: 12)), with: .color(.white.opacity(0.55)))
            }
            let streets = max(3, Int(size.height / 95) + 1)
            for k in 0..<streets {
                let y = (CGFloat(k) * 95 + scroll).truncatingRemainder(dividingBy: CGFloat(streets) * 95) - 20
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 12)), with: .color(Color(hex: 0x23272F)))
            }
        default:  // Mar: crestas de ola.
            grad(0x14355A, 0x1D4E7A)
            scatter(16) { p, _ in
                ctx.fill(Path(roundedRect: CGRect(x: p.x, y: p.y, width: 9, height: 1.4), cornerRadius: 0.7), with: .color(.white.opacity(0.16)))
            }
        }
    }

    private func drawDecor(_ ctx: inout GraphicsContext, _ isle: Island) {
        let rect = CGRect(x: isle.x - isle.w / 2, y: isle.y - isle.h / 2, width: isle.w, height: isle.h)
        switch isle.zone % Self.zoneCount {
        case 1:   // Duna con su sombra y, a veces, un cactus o unas rocas.
            ctx.fill(Path(ellipseIn: rect.offsetBy(dx: 3, dy: 3)), with: .color(Color(hex: 0x9A7238).opacity(0.5)))
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xE6C583)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: isle.w * 0.2, dy: isle.h * 0.25).offsetBy(dx: -isle.w * 0.1, dy: -isle.h * 0.1)),
                     with: .color(Color(hex: 0xF0D59B)))
            if isle.seed % 2 == 0 {
                let c = CGPoint(x: isle.x + isle.w * 0.15, y: isle.y)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + 2, y: c.y + 1, width: 8, height: 4)), with: .color(.black.opacity(0.2)))
                ctx.fill(Path(roundedRect: CGRect(x: c.x - 1.6, y: c.y - 6, width: 3.2, height: 9), cornerRadius: 1.6), with: .color(Color(hex: 0x3F8048)))
                ctx.fill(Path(roundedRect: CGRect(x: c.x - 5, y: c.y - 3, width: 10, height: 2.6), cornerRadius: 1.3), with: .color(Color(hex: 0x3F8048)))
            }
        case 2:   // Arboleda: copas redondas con sombra.
            for k in 0..<5 {
                let a = CGFloat(k) * 1.257 + CGFloat(isle.seed % 7)
                let c = CGPoint(x: isle.x + cos(a) * isle.w * 0.26, y: isle.y + sin(a) * isle.h * 0.26)
                let r = isle.w * 0.2
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r + 2.5, y: c.y - r + 3, width: r * 2, height: r * 2)), with: .color(.black.opacity(0.22)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: k % 2 == 0 ? 0x1F5A2E : 0x2A6E38)))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.7, width: r * 0.8, height: r * 0.7)), with: .color(Color(hex: 0x4E9A5A).opacity(0.8)))
            }
        case 3:   // Manzana de edificios: azotea con sombra, borde claro y un par de detalles.
            let b = CGRect(x: isle.x - isle.w * 0.4, y: isle.y - isle.h * 0.5, width: isle.w * 0.8, height: isle.h)
            ctx.fill(Path(b.offsetBy(dx: 4, dy: 5)), with: .color(.black.opacity(0.3)))
            ctx.fill(Path(b), with: .color(Color(hex: [0x8D97A8, 0xA89A8A, 0x7C8AA0][isle.seed % 3])))
            ctx.stroke(Path(b.insetBy(dx: 1.5, dy: 1.5)), with: .color(.white.opacity(0.35)), lineWidth: 1)
            ctx.fill(Path(CGRect(x: b.minX + 4, y: b.minY + 4, width: 6, height: 5)), with: .color(Color(hex: 0x4A515E)))
            if isle.seed % 2 == 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: b.maxX - 11, y: b.maxY - 11, width: 7, height: 7)), with: .color(Color(hex: 0x5F6B7C)))
            }
        default:  // Isla.
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(Color(hex: 0xD9C48A)))
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x4E9A5A)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: isle.w * 0.22, dy: isle.h * 0.22).offsetBy(dx: -isle.w * 0.08, dy: -isle.h * 0.06)),
                     with: .color(Color(hex: 0x3C7F49)))
        }
    }

    private func drawBoss(_ ctx: inout GraphicsContext, _ b: Boss) {
        let hit = b.flash > 0
        func tone(_ hex: UInt32) -> Color { hit ? .white : Color(hex: hex) }
        var g = ctx
        g.translateBy(x: b.p.x, y: b.p.y)
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ c: Color) {
            g.fill(Path(roundedRect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), cornerRadius: r), with: .color(c))
        }
        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color) {
            g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(c))
        }
        /// Tubo que sale de (x, y) apuntando al jugador.
        func barrel(_ x: CGFloat, _ y: CGFloat, length: CGFloat, width: CGFloat, _ c: Color) {
            var t = g
            t.translateBy(x: x, y: y)
            t.rotate(by: .radians(Double(atan2(py - (b.p.y + y), px - (b.p.x + x)))))
            t.fill(Path(roundedRect: CGRect(x: 0, y: -width / 2, width: length, height: width), cornerRadius: width / 3), with: .color(c))
        }
        switch b.kind {
        case .plane:
            ctx.fill(Path(ellipseIn: CGRect(x: b.p.x - 14, y: b.p.y + 14, width: 44, height: 14)), with: .color(.black.opacity(0.16)))
            WatchPlanes.drawPlane(in: &ctx, at: b.p, size: Self.bossSize, body: tone(0x3F5A4C), wing: tone(0x2C4237),
                                  engines: 4, spin: time * 40)   // morro arriba: vuela en el mismo sentido que el jugador
        case .ship:
            // Estela a los dos lados, casco, cubierta, puente con chimenea y dos torres.
            for k in 0..<3 {
                let w = 70 + CGFloat(k) * 8 + sin(time * 3 + CGFloat(k)) * 3
                box(0, -4 - CGFloat(k) * 5, w, 3, 1.5, .white.opacity(0.22 - Double(k) * 0.06))
            }
            box(0, 0, 64, 22, 11, tone(0x3B4652))
            box(0, 0, 56, 14, 7, tone(0x7C8A96))
            box(0, 0, 54, 1, 0.5, .black.opacity(0.14))
            box(0, 0, 16, 12, 2.5, tone(0x4B5763))
            dot(0, -1, 3.2, Color(hex: 0x1F262E))
            box(0, 4, 9, 2.4, 1, Color(hex: 0xF2B95C))
            for dx in [-18, 18] as [CGFloat] {
                dot(dx, 0, 5.6, tone(0x2B333C))
                barrel(dx, 0, length: 12, width: 3.4, Color(hex: 0x151A20))
                dot(dx, 0, 3.4, tone(0x56626E))
            }
        case .tank:
            // Orugas con eslabones que corren, casco, torreta y cañón largo.
            g.fill(Path(ellipseIn: CGRect(x: -16, y: -14, width: 40, height: 40)), with: .color(.black.opacity(0.18)))
            let run = (time * 14).truncatingRemainder(dividingBy: 5)
            for dx in [-14, 14] as [CGFloat] {
                box(dx, 0, 9, 40, 2.5, tone(0x2B2820))
                var y = -18 + run
                while y < 19 { box(dx, y, 9, 1.2, 0, .white.opacity(0.13)); y += 5 }
            }
            box(0, 0, 22, 34, 4, tone(0x8A7440))
            box(0, -12, 16, 5, 1.5, tone(0x6B5930))
            box(0, 13, 14, 2, 1, .black.opacity(0.2))
            dot(0, 0, 10, tone(0x5B4C28))
            barrel(0, 0, length: 23, width: 4.6, Color(hex: 0x231F16))
            dot(0, 0, 6.5, tone(0x74622F))
            dot(2, -2, 1.8, Color(hex: 0xF0766B))
        case .heli:
            g.fill(Path(ellipseIn: CGRect(x: -4, y: 2, width: 30, height: 22)), with: .color(.black.opacity(0.16)))
            g.scaleBy(x: 1, y: -1)   // dibujado morro abajo; se voltea para que vuele en el sentido del jugador
            for dx in [-11, 11] as [CGFloat] { box(dx, 2, 2, 22, 1, tone(0x2A3324)) }       // patines
            box(0, 2, 22, 2, 1, tone(0x2A3324))
            box(0, -15, 4, 20, 1.5, tone(0x3F5A32))                                          // cola
            box(0, -24, 12, 3, 1.2, tone(0x3F5A32))
            box(6, -24, 1.4, 5 + 4 * abs(sin(time * 30)), 0.5, .white.opacity(0.7))           // rotor de cola
            g.fill(Path(ellipseIn: CGRect(x: -9.5, y: -12, width: 19, height: 27)), with: .color(tone(0x55783F)))
            g.fill(Path(ellipseIn: CGRect(x: -6, y: 3, width: 12, height: 10)), with: .color(Color(hex: 0x1B2233)))   // cabina, morro abajo
            // Rotor: disco tenue y dos palas cruzadas que giran.
            dot(0, -1, 23, .white.opacity(0.07))
            var r = g
            r.translateBy(x: 0, y: -1)
            r.rotate(by: .radians(Double(time * 22)))
            r.fill(Path(roundedRect: CGRect(x: -23, y: -1.3, width: 46, height: 2.6), cornerRadius: 1.3), with: .color(.white.opacity(0.6)))
            r.fill(Path(roundedRect: CGRect(x: -1.3, y: -23, width: 2.6, height: 46), cornerRadius: 1.3), with: .color(.white.opacity(0.6)))
            dot(0, -1, 2.6, tone(0x2A3324))
        }
    }

    /// Cañón: base (en el mar, sobre una balsa) y tubo que sigue al avión.
    private func drawTurret(_ ctx: inout GraphicsContext, _ t: Turret) {
        if t.zone % Self.zoneCount == 0 {
            ctx.fill(Path(roundedRect: CGRect(x: t.p.x - 11, y: t.p.y - 9, width: 22, height: 18), cornerRadius: 4), with: .color(Color(hex: 0x8A6A45)))
            ctx.fill(Path(CGRect(x: t.p.x - 11, y: t.p.y - 1, width: 22, height: 1.2)), with: .color(.black.opacity(0.25)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: t.p.x - 6, y: t.p.y - 4, width: 15, height: 12)), with: .color(.black.opacity(0.22)))
        let body = t.flash > 0 ? Color.white : Color(hex: 0x4A5263)
        ctx.fill(Path(ellipseIn: CGRect(x: t.p.x - 7.5, y: t.p.y - 7.5, width: 15, height: 15)), with: .color(Color(hex: 0x2B303B)))
        ctx.fill(Path(ellipseIn: CGRect(x: t.p.x - 5.5, y: t.p.y - 5.5, width: 11, height: 11)), with: .color(body))
        var g = ctx
        g.translateBy(x: t.p.x, y: t.p.y)
        g.rotate(by: .radians(Double(atan2(py - t.p.y, px - t.p.x))))
        g.fill(Path(roundedRect: CGRect(x: 0, y: -1.8, width: 11, height: 3.6), cornerRadius: 1.2), with: .color(Color(hex: 0x1B1F27)))
        ctx.fill(Path(ellipseIn: CGRect(x: t.p.x - 2, y: t.p.y - 2, width: 4, height: 4)), with: .color(Color(hex: 0xF0766B)))
    }

    func autopilot() -> CGFloat {
        let span = max(1, size.width - 34)
        if let b = bullets.filter({ abs($0.p.x - px) < 12 && $0.p.y < py && py - $0.p.y < 60 }).max(by: { $0.p.y < $1.p.y }) {
            return (px + (b.p.x >= px ? -28 : 28) - 17) / span
        }
        if let p = pickups.first { return (p.p.x - 17) / span }
        // Se pone bajo el enemigo más cercano, salvo que esté a punto de chocar: entonces se aparta.
        guard let e = enemies.filter({ $0.p.y < py }).max(by: { $0.p.y < $1.p.y }) else {
            return boss.map { ($0.p.x - 17) / span } ?? 0.5
        }
        if py - e.p.y < 34 { return (e.p.x + (e.p.x >= px ? -36 : 36) - 17) / span }
        return (e.p.x - 17) / span
    }
}

#if os(watchOS)
struct WatchPlanesView: View {
    var body: some View { WatchArcadeStage(info: WatchPlanes.info, world: SkyWorld()) }
}
#endif
