#if os(iOS) || os(watchOS)
//
//  MazeModel.swift — Laberinto sin UI (compartido por iPhone y Watch).
//  Movido tal cual desde MazeGame.swift el 2026-11-20.
//

import Foundation

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
#endif
