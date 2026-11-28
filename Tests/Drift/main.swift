// Partidas simuladas de Derrape. Con QW_GOD=1 los choques se cuentan pero no quitan vida.
// Con un argumento (una carpeta) guarda además capturas PNG de cada etapa.
import Foundation
import ImageIO
import UniformTypeIdentifiers

var failures = 0
var checks = 0
func check(_ ok: @autoclosure () -> Bool, _ name: String, line: Int = #line) {
    checks += 1
    if !ok() { failures += 1; print("FAIL [\(line)] \(name)") } else { print("ok   \(name)") }
}

struct Run { var stage = 0; var crashes = 0; var edge = 0; var coins = 0; var near = 0; var turbos = 0; var score = 0; var seconds: CGFloat = 0; var draws = 0; var dead = false; var causes: [String: Int] = [:] }

@MainActor func image(_ world: DriftWorld, _ size: CGSize) -> CGImage? {
    let r = ImageRenderer(content: Canvas { ctx, s in var c = ctx; world.draw(&c, size: s) }.frame(width: size.width, height: size.height))
    r.scale = 2
    return r.cgImage
}

/// Juega con el piloto automático (el mando se mueve como en la app: 1,8 recorridos/s como mucho).
@MainActor func play(size: CGSize, seconds: CGFloat, god: Bool, stage: Int = 0, render: Bool = false, shots: String? = nil) -> Run {
    if god { setenv("QW_GOD", "1", 1) } else { unsetenv("QW_GOD") }
    setenv("QW_STAGE", "\(stage)", 1)
    let world = DriftWorld()
    world.reset(size: size)
    var run = Run(), x: CGFloat = 0.5, t: CGFloat = 0
    let dt: CGFloat = 1.0 / 60
    var frame = 0
    while t < seconds {
        let want = world.autopilot()
        x = min(1, max(0, x + max(-1.8 * dt, min(1.8 * dt, want - x))))
        if world.step(dt: dt, input: x) == .dead { run.dead = true; break }
        t += dt; frame += 1
        if render, frame % 20 == 0, image(world, size) != nil { run.draws += 1 }
        if let dir = shots, frame % 150 == 0, let img = image(world, size) {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("drift-\(stage)-\(frame / 150).png")
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
            }
        }
    }
    run.stage = world.stageIndex; run.crashes = world.crashes; run.edge = world.edgeCrashes; run.coins = world.coinsTaken
    run.causes = world.causes; run.near = world.nearMisses; run.turbos = world.turbos; run.score = world.score; run.seconds = t
    return run
}

@main struct Runner {
    @MainActor static func main() {
        let small = CGSize(width: 176, height: 215), big = CGSize(width: 208, height: 248)
        let shots = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil

        // 1. Sin morir (QW_GOD): cuatro minutos. Pasa por las cuatro etapas, coge monedas, y la carretera
        //    no le obliga a chocar: un piloto que solo mira 170 pt por delante choca muy poco.
        for (label, size) in [("41 mm", small), ("49 mm", big)] {
            var causes: [String: Int] = [:]
            var crashes = 0, edge = 0, seconds: CGFloat = 0, coins = 0, near = 0, turbos = 0, minStage = 99, draws = 0
            for i in 0..<6 {
                let r = play(size: size, seconds: 240, god: true, render: i == 0)
                crashes += r.crashes; edge += r.edge; seconds += r.seconds; coins += r.coins; near += r.near; turbos += r.turbos
                minStage = min(minStage, r.stage); draws += r.draws
                causes.merge(r.causes, uniquingKeysWith: +)
            }
            check(minStage >= 8, "\(label): llega a la etapa \(minStage + 1) en 4 min")
            check(crashes <= 12, "\(label): \(crashes) choques (\(edge) contra el arcén, \(causes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))) en \(Int(seconds)) s de piloto")
            check(edge <= 3, "\(label): el arcén se puede seguir siempre (\(edge) salidas)")
            check(coins > 600, "\(label): \(coins) monedas, \(near) rozando, \(turbos) turbos")
            check(turbos >= 6, "\(label): salen turbos")
            check(draws > 500, "\(label): se dibuja (\(draws))")
        }

        // 2. Partida de verdad (con vidas): el piloto aguanta un rato y la partida se acaba bien.
        for (label, size) in [("41 mm", small), ("49 mm", big)] {
            var total: CGFloat = 0, scores: [Int] = []
            for _ in 0..<8 { let r = play(size: size, seconds: 900, god: false); total += r.seconds; scores.append(r.score) }
            check(total / 8 > 60, "\(label): partida media de \(Int(total / 8)) s; puntos \(scores)")
        }

        // 3. Cada paisaje, empezando en su etapa (y capturas si se pide carpeta).
        for st in 0..<4 {
            let r = play(size: big, seconds: 22, god: true, stage: st, render: true, shots: shots)
            check(r.draws > 50 && r.stage >= st, "etapa \(st + 1): se dibuja y avanza (\(r.crashes) choques)")
        }

        print("\(checks - failures)/\(checks) comprobaciones")
        if failures > 0 { exit(1) }
    }
}
