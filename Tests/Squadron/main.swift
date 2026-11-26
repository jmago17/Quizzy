// Partidas simuladas de Escuadrón. Los golpes se cuentan pero no quitan vida (QW_GOD=1).
import Foundation

var failures = 0
var checks = 0
func check(_ ok: @autoclosure () -> Bool, _ name: String, line: Int = #line) {
    checks += 1
    if !ok() { failures += 1; print("FAIL [\(line)] \(name)") } else { print("ok   \(name)") }
}

struct Run { var zones: [Int] = []; var bosses: [SkyWorld.BossKind] = []; var hits = 0; var crashes = 0; var peaks = 0; var seconds: CGFloat = 0; var draws = 0 }

/// Juega `seconds` con el piloto automático (el mando se mueve como en la app: 1,8 anchos/s como mucho).
@MainActor func play(size: CGSize, phone: Bool, seconds: CGFloat, env: [String: String], untilZone: Int? = nil, render: Bool = false) -> Run {
    for key in ["QW_ZONE", "QW_BOSS", "QW_BOOST", "QW_GORGE"] { unsetenv(key) }
    setenv("QW_GOD", "1", 1)
    for (k, v) in env { setenv(k, v, 1) }
    let world = SkyWorld()
    if phone { world.free2D = true; world.swingRolls = false; world.drawsHUD = false; world.spawnScale = 0.7; world.topInset = 53; world.bottomInset = 34 }
    world.reset(size: size)
    var run = Run(), x: CGFloat = 0.5, t: CGFloat = 0
    let dt: CGFloat = 1.0 / 60
    var frame = 0
    while t < seconds {
        let want = world.autopilot()
        x = min(1, max(0, x + max(-1.8 * dt, min(1.8 * dt, want - x))))
        _ = world.step(dt: dt, input: x)
        t += dt; frame += 1
        if run.zones.last != world.zoneIndex { run.zones.append(world.zoneIndex) }
        if let b = world.bossKind, run.bosses.count < run.zones.count { run.bosses.append(b) }
        if render, frame % 20 == 0 {
            let renderer = ImageRenderer(content: Canvas { ctx, s in var c = ctx; world.draw(&c, size: s) }.frame(width: size.width, height: size.height))
            if renderer.cgImage != nil { run.draws += 1 }
        }
        if let z = untilZone, world.zoneIndex >= z { break }
    }
    run.hits = world.hitsTaken; run.crashes = world.crashes; run.peaks = world.peakCrashes; run.seconds = t
    return run
}

@main struct Runner {
    @MainActor static func main() {
        let watch = CGSize(width: 198, height: 242), phone = CGSize(width: 200, height: 433)
        let names = ["mar", "desierto", "bosque", "ciudad", "montaña"]
        let expected: [SkyWorld.BossKind] = [.ship, .train, .tank, .plane, .heli]

        // 1. Cada zona saca su jefe y se le puede derribar (sin mejoras) en un tiempo razonable.
        for z in 0..<5 {
            for (label, size, isPhone) in [("reloj", watch, false), ("iPhone", phone, true)] {
                let r = play(size: size, phone: isPhone, seconds: 150, env: ["QW_ZONE": "\(z)", "QW_BOSS": "1"], untilZone: z + 1, render: z == 1 || z == 4)
                check(r.bosses.first == expected[z], "\(names[z]) (\(label)): jefe \(expected[z])")
                check(r.zones.last == z + 1, "\(names[z]) (\(label)): jefe derribado en \(Int(r.seconds)) s, \(r.hits) golpes")
            }
        }

        // 2. Montaña sin jefe: un minuto de picos y desfiladeros. El piloto no debería estrellarse casi nunca.
        for (label, size, isPhone) in [("reloj", watch, false), ("iPhone", phone, true)] {
            var crashes = 0, peaks = 0, seconds: CGFloat = 0
            for _ in 0..<6 {
                let r = play(size: size, phone: isPhone, seconds: 55, env: ["QW_ZONE": "4", "QW_GORGE": "1"], render: true)
                crashes += r.crashes; peaks += r.peaks; seconds += r.seconds
            }
            check(crashes <= 3, "montaña (\(label)): \(crashes) choques (\(peaks) contra picos) en \(Int(seconds)) s de piloto")
        }

        // 3. Partida larga desde el principio: pasa por todas las zonas, dibujando por el camino.
        for (label, size, isPhone) in [("reloj", watch, false), ("iPhone", phone, true)] {
            let r = play(size: size, phone: isPhone, seconds: 1200, env: [:], untilZone: 6, render: true)
            check(r.zones.count >= 7, "partida larga (\(label)): zonas \(r.zones), \(Int(r.seconds)) s, \(r.hits) golpes, \(r.crashes) choques, \(r.draws) dibujos")
            check(Array(r.bosses.prefix(5)) == expected, "partida larga (\(label)): jefes en orden \(r.bosses)")
            check(r.draws > 100, "partida larga (\(label)): se dibuja")
        }

        print("\(checks - failures)/\(checks) comprobaciones")
        if failures > 0 { exit(1) }
    }
}
