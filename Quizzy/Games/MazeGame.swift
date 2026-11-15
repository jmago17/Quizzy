#if os(iOS)
//
//  MazeGame.swift — News Raider
//  Interactive adaptation of Printables' recursive-backtracker maze.
//

import SwiftUI
import Combine

struct MazePuzzle: Identifiable, Sendable {
    static let north: UInt8 = 1, south: UInt8 = 2, east: UInt8 = 4, west: UInt8 = 8
    let id: String
    let walls: [[UInt8]]
    let cols: Int, rows: Int
    let entranceCol: Int, exitCol: Int

    static func generate(seed: UInt64, cols: Int = 12, rows: Int = 16) -> MazePuzzle {
        var rng=SeededGenerator(seed:seed)
        var walls=Array(repeating:Array(repeating:UInt8(15),count:cols),count:rows)
        var visited=Array(repeating:Array(repeating:false,count:cols),count:rows)
        var stack=[GridCell(row:0,col:0)];visited[0][0]=true
        while let p=stack.last {
            var n:[(Int,Int,UInt8,UInt8)]=[]
            if p.row>0,!visited[p.row-1][p.col]{n.append((p.row-1,p.col,north,south))}
            if p.row<rows-1,!visited[p.row+1][p.col]{n.append((p.row+1,p.col,south,north))}
            if p.col<cols-1,!visited[p.row][p.col+1]{n.append((p.row,p.col+1,east,west))}
            if p.col>0,!visited[p.row][p.col-1]{n.append((p.row,p.col-1,west,east))}
            if n.isEmpty { stack.removeLast() }
            else { let x=n[rng.int(n.count)];walls[p.row][p.col] &= ~x.2;walls[x.0][x.1] &= ~x.3;visited[x.0][x.1]=true;stack.append(GridCell(row:x.0,col:x.1)) }
        }
        let entrance=rng.int(cols),exit=rng.int(cols)
        walls[0][entrance] &= ~north;walls[rows-1][exit] &= ~south
        return MazePuzzle(id:"m-gen-\(seed)",walls:walls,cols:cols,rows:rows,entranceCol:entrance,exitCol:exit)
    }

    func canMove(from a:GridCell,to b:GridCell)->Bool {
        guard (0..<rows).contains(b.row),(0..<cols).contains(b.col) else{return false}
        let w=walls[a.row][a.col]
        if b.row==a.row-1 && b.col==a.col{return w & Self.north == 0}
        if b.row==a.row+1 && b.col==a.col{return w & Self.south == 0}
        if b.col==a.col+1 && b.row==a.row{return w & Self.east == 0}
        if b.col==a.col-1 && b.row==a.row{return w & Self.west == 0}
        return false
    }
}

struct MazeGame: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let puzzle:MazePuzzle
    @ObservedObject private var progress=PuzzleProgress.shared
    @State private var path:[GridCell]=[]
    @State private var elapsed=0
    @State private var finished=false
    @State private var result: PZResult?
    
    private let tick=Timer.publish(every:1,on:.main,in:.common).autoconnect()

    var body:some View {
        GeometryReader { outer in
            let landscape = outer.size.width > outer.size.height * 1.2
            ZStack(alignment: .bottomTrailing) {
                if landscape {
                    HStack(spacing:18) {
                        mazeBoard.padding(.leading,16).padding(.vertical,8)
                        VStack(alignment:.leading,spacing:20) {
                            HStack { stat(AppLanguage.text("TIEMPO", "TIME"),PuzzleTiming.clock(TimeInterval(elapsed)));Spacer();stat(AppLanguage.text("SALIDA", "EXIT"),"↓ \(puzzle.exitCol+1)") }
                            Text(AppLanguage.text("Usa el mando para moverte hasta la estrella de salida.", "Use the control to reach the exit star.")).font(.headline)
                            Text(AppLanguage.text("Pulsa la dirección contraria para retroceder.", "Press the opposite direction to go back.")).font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }.padding(.trailing,24).padding(.top,20).frame(width:outer.size.width*0.34)
                    }
                } else {
                    VStack(spacing:12) {
                        HStack { stat(AppLanguage.text("TIEMPO", "TIME"),PuzzleTiming.clock(TimeInterval(elapsed)));Spacer();stat(AppLanguage.text("SALIDA", "EXIT"),"↓ \(puzzle.exitCol+1)") }.padding(.horizontal,16)
                        mazeBoard
                        Text(AppLanguage.text("Usa el mando para moverte hasta la salida", "Use the control to reach the exit")).font(.footnote).foregroundStyle(.secondary)
                    }.padding(.vertical,12)
                }
                joystick
                    .padding(.trailing, 22)
                    .padding(.bottom, 22)
            }
        }
        .background(LiquidCanvasBackground()).navigationTitle(AppLanguage.text("Laberinto", "Maze")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(AppLanguage.text("Borrar ruta", "Clear path"), systemImage: "arrow.counterclockwise") {
                    path = [GridCell(row: 0, col: puzzle.entranceCol)]
                    // Keep time, hints and completed-day credit: reset is not
                    // a new daily puzzle nor a way to erase hint penalties.
                    finished = false
                    result = nil
                    pzHaptic()
                }
                .accessibilityHint(AppLanguage.text("Vuelve a la entrada del mismo laberinto", "Return to the entrance of this maze"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(AppLanguage.text("Reiniciar", "Restart"), systemImage: "arrow.clockwise") {
                    progress.reset(puzzle.id)
                    path = [GridCell(row: 0, col: puzzle.entranceCol)]
                    elapsed = 0
                    finished = false
                    result = nil
                    pzHaptic()
                }
                .accessibilityHint(AppLanguage.text("Reinicia tiempo y progreso del mismo laberinto, sin generar otro", "Restart time and progress for this maze without generating another"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                PZHintButton(kind: .maze,
                             isAvailable: !finished,
                             used: progress.hintsUsed(puzzle.id)) { revealNextSteps() }
            }
        }
        .onAppear { elapsed=progress.elapsed(puzzle.id);finished=progress.isDone(puzzle.id);if path.isEmpty{path=[GridCell(row:0,col:puzzle.entranceCol)]} }
        .onReceive(tick){_ in if !finished{elapsed+=1;if elapsed%5==0{progress.setElapsed(puzzle.id,elapsed)}}}
        .pzRules(.maze)
        .sheet(item: $result) { r in PZResultSheet(result: r) }
    }
    private var mazeBoard: some View {
        GeometryReader { geo in
            let cell=min(geo.size.width/CGFloat(puzzle.cols),geo.size.height/CGFloat(puzzle.rows))
            Canvas { ctx,_ in draw(ctx:ctx,cell:cell) }
                .frame(width:cell*CGFloat(puzzle.cols),height:cell*CGFloat(puzzle.rows))
                .frame(maxWidth:.infinity,maxHeight:.infinity)
        }
        .padding(12).background(PZColor.surface,in:RoundedRectangle(cornerRadius:16)).padding(.horizontal,16)
    }
    private func stat(_ a:String,_ b:String)->some View{VStack(alignment:.leading){Text(a).font(.caption.bold()).foregroundStyle(.secondary);Text(b).font(.title2.bold()).monospacedDigit()}}

    private var joystick: some View {
        PZJoystick(tint: PZ.maze) { dr, dc in step(dr: dr, dc: dc) }
    }

    /// One discrete grid step, driven by the D-pad. Pressing the opposite
    /// direction of the last move retraces the path instead of being blocked.
    private func step(dr: Int, dc: Int) {
        guard !finished, let last = path.last else { return }
        let next = GridCell(row: last.row + dr, col: last.col + dc)
        guard (0..<puzzle.rows).contains(next.row), (0..<puzzle.cols).contains(next.col) else { return }
        if path.count > 1, next == path[path.count - 2] {
            path.removeLast()
            pzHaptic()
            return
        }
        guard next != last, puzzle.canMove(from: last, to: next) else { return }
        path.append(next)
        pzHaptic()
        if next.row == puzzle.rows - 1 && next.col == puzzle.exitCol { complete() }
    }
    /// Breadth-first route from the current head to the exit. The maze is a
    /// perfect maze, so the first path found is the only one.
    private func routeToExit(from start: GridCell) -> [GridCell] {
        let exit = GridCell(row: puzzle.rows - 1, col: puzzle.exitCol)
        var queue = [start]
        var cameFrom: [GridCell: GridCell] = [:]
        var seen: Set<GridCell> = [start]
        while !queue.isEmpty {
            let cell = queue.removeFirst()
            if cell == exit { break }
            let neighbours = [
                GridCell(row: cell.row - 1, col: cell.col),
                GridCell(row: cell.row + 1, col: cell.col),
                GridCell(row: cell.row, col: cell.col - 1),
                GridCell(row: cell.row, col: cell.col + 1),
            ]
            for n in neighbours where !seen.contains(n) {
                guard (0..<puzzle.rows).contains(n.row),
                      (0..<puzzle.cols).contains(n.col),
                      puzzle.canMove(from: cell, to: n) else { continue }
                seen.insert(n)
                cameFrom[n] = cell
                queue.append(n)
            }
        }
        guard seen.contains(exit) else { return [] }
        var route: [GridCell] = []
        var cursor = exit
        while cursor != start {
            route.append(cursor)
            guard let prev = cameFrom[cursor] else { return [] }
            cursor = prev
        }
        return route.reversed()
    }

    /// Advances the drawn path a few cells along the true route.
    private func revealNextSteps() {
        guard let head = path.last else { return }
        let route = routeToExit(from: head)
        guard !route.isEmpty else { return }
        progress.addHint(puzzle.id)
        elapsed += PZHintButton.penalty
        progress.setElapsed(puzzle.id, elapsed)
        let step = max(3, route.count / 4)
        withAnimation(PZAnim.reveal) {
            path.append(contentsOf: route.prefix(step))
        }
        if let last = path.last, last.row == puzzle.rows - 1, last.col == puzzle.exitCol {
            complete()
        }
    }

    private func complete() {
        finished = true
        let avg = PuzzleTiming.average(kind: .maze, itemCount: puzzle.rows * puzzle.cols,
                                       boardSize: puzzle.cols)
        progress.setElapsed(puzzle.id, elapsed)
        progress.recordTime(TimeInterval(elapsed), kind: .maze, puzzleID: puzzle.id)
        progress.markDone(puzzle.id)
        progress.noteDayIfComplete()
        PZHaptics.success()
        result = PZResult(
            kind: .maze,
            didWin: true,
            headline: AppLanguage.text("¡Salida encontrada!", "Exit found!"),
            detail: PuzzleTiming.comparison(elapsed: TimeInterval(elapsed),
                                            average: avg.seconds,
                                            personal: avg.personal, kind: .maze),
            metrics: [
                (AppLanguage.text("Pasos", "Steps"), "\(path.count)"),
                (AppLanguage.text("Tiempo", "Time"), PuzzleTiming.clock(TimeInterval(elapsed)))
            ],
            shareText: AppLanguage.text("NewsRaider Laberinto · \(path.count) pasos · \(PuzzleTiming.clock(TimeInterval(elapsed)))", "NewsRaider Maze · \(path.count) steps · \(PuzzleTiming.clock(TimeInterval(elapsed)))"))
    }
    private func draw(ctx:GraphicsContext,cell:CGFloat){
        var walls=Path();for r in 0..<puzzle.rows{for c in 0..<puzzle.cols{let x=CGFloat(c) * cell,y=CGFloat(r) * cell,w=puzzle.walls[r][c];if w&MazePuzzle.north != 0{walls.move(to:.init(x:x,y:y));walls.addLine(to:.init(x:x+cell,y:y))};if w&MazePuzzle.west != 0{walls.move(to:.init(x:x,y:y));walls.addLine(to:.init(x:x,y:y+cell))};if r==puzzle.rows-1,w&MazePuzzle.south != 0{walls.move(to:.init(x:x,y:y+cell));walls.addLine(to:.init(x:x+cell,y:y+cell))};if c==puzzle.cols-1,w&MazePuzzle.east != 0{walls.move(to:.init(x:x+cell,y:y));walls.addLine(to:.init(x:x+cell,y:y+cell))}}};ctx.stroke(walls,with:.color(.primary),lineWidth:2)
        if path.count>1{var p=Path();for(i,x) in path.enumerated(){let q=CGPoint(x:(CGFloat(x.col)+0.5) * cell,y:(CGFloat(x.row)+0.5) * cell);i==0 ? p.move(to:q):p.addLine(to:q)};ctx.stroke(p,with:.color(PZ.maze),style:StrokeStyle(lineWidth:max(3,cell * 0.22),lineCap:.round,lineJoin:.round))}
        ctx.draw(Text("↓").font(.system(size:cell * 0.8,weight:.bold)).foregroundStyle(PZ.maze),at:CGPoint(x:(CGFloat(puzzle.entranceCol)+0.5) * cell,y:cell * 0.35))
        ctx.draw(Text("★").font(.system(size:cell * 0.55)).foregroundStyle(PZ.maze),at:CGPoint(x:(CGFloat(puzzle.exitCol)+0.5) * cell,y:(CGFloat(puzzle.rows)-0.5) * cell))
    }
}

// MARK: - Floating D-pad

enum PZDPadDirection: Equatable {
    case up, down, left, right
    var delta: (dr: Int, dc: Int) {
        switch self {
        case .up:    return (-1, 0)
        case .down:  return (1, 0)
        case .left:  return (0, -1)
        case .right: return (0, 1)
        }
    }
}

/// Floating on-screen D-pad: a draggable knob inside a circular base, snapped
/// to the four cardinal directions and auto-repeating while held. Replaces
/// dragging a finger over the board itself, which made it too easy to
/// mis-trigger an accidental backtrack.
struct PZJoystick: View {
    @AppStorage(AppLanguage.storageKey) private var languageSelection = "system"
    let tint: Color
    let onStep: (_ dr: Int, _ dc: Int) -> Void

    private let baseSize: CGFloat = 112
    private let knobSize: CGFloat = 48
    private let travel: CGFloat = 32
    private let deadZone: CGFloat = 12
    private let repeatDelay: Duration = .milliseconds(260)
    private let repeatInterval: Duration = .milliseconds(140)

    @State private var knobOffset: CGSize = .zero
    @State private var activeDirection: PZDPadDirection?
    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)
            Circle().strokeBorder(tint.opacity(0.28), lineWidth: 1.5)
            arrows
            Circle()
                .fill(LinearGradient(colors: [tint, tint.opacity(0.8)],
                                      startPoint: .top, endPoint: .bottom))
                .frame(width: knobSize, height: knobSize)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: tint.opacity(0.45), radius: 8, y: 3)
                .offset(knobOffset)
                .animation(activeDirection == nil ? .spring(response: 0.3, dampingFraction: 0.62) : nil,
                           value: knobOffset)
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Circle())
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(handle(_:))
                .onEnded { _ in release() }
        )
        .onDisappear { release() }
        .accessibilityElement(children: .ignore)
        .accessibilityAction(named: AppLanguage.text("Arriba", "Up")) { onStep(-1, 0) }
        .accessibilityAction(named: AppLanguage.text("Abajo", "Down")) { onStep(1, 0) }
        .accessibilityAction(named: AppLanguage.text("Izquierda", "Left")) { onStep(0, -1) }
        .accessibilityAction(named: AppLanguage.text("Derecha", "Right")) { onStep(0, 1) }
        .accessibilityLabel(AppLanguage.text("Mando direccional", "Directional control"))
        .accessibilityHint(AppLanguage.text("Deslízalo hacia arriba, abajo, izquierda o derecha para moverte por el laberinto", "Swipe up, down, left or right to move through the maze"))
    }

    private var arrows: some View {
        VStack(spacing: 0) {
            chevron("chevron.up")
            Spacer(minLength: 0)
            HStack {
                chevron("chevron.left")
                Spacer(minLength: 0)
                chevron("chevron.right")
            }
            Spacer(minLength: 0)
            chevron("chevron.down")
        }
        .padding(16)
        .frame(width: baseSize, height: baseSize)
        .allowsHitTesting(false)
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tint.opacity(0.4))
    }

    private func handle(_ value: DragGesture.Value) {
        let t = value.translation
        let rawMagnitude = (t.width * t.width + t.height * t.height).squareRoot()
        let magnitude = min(rawMagnitude, travel)
        if magnitude > 0 {
            let angle = atan2(t.height, t.width)
            knobOffset = CGSize(width: cos(angle) * magnitude, height: sin(angle) * magnitude)
        }

        guard rawMagnitude > deadZone else {
            if activeDirection != nil { stopRepeating() }
            return
        }

        let direction: PZDPadDirection = abs(t.width) > abs(t.height)
            ? (t.width > 0 ? .right : .left)
            : (t.height > 0 ? .down : .up)

        if activeDirection != direction {
            activeDirection = direction
            startRepeating(direction)
        }
    }

    private func startRepeating(_ direction: PZDPadDirection) {
        repeatTask?.cancel()
        onStep(direction.delta.dr, direction.delta.dc)
        repeatTask = Task { @MainActor in
            do { try await Task.sleep(for: repeatDelay) } catch { return }
            while !Task.isCancelled {
                onStep(direction.delta.dr, direction.delta.dc)
                try? await Task.sleep(for: repeatInterval)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
        activeDirection = nil
    }

    private func release() {
        stopRepeating()
        knobOffset = .zero
    }
}
#endif
