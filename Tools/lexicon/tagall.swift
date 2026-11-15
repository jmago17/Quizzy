import NaturalLanguage
import Foundation
let words = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8).split(separator: "\n").map(String.init)
let t = NLTagger(tagSchemes: [.lexicalClass, .lemma])
var out: [String] = []
for w in words {
  let s = w.lowercased(); t.string = s
  t.setLanguage(.spanish, range: s.startIndex..<s.endIndex)
  let (c, _) = t.tag(at: s.startIndex, unit: .word, scheme: .lexicalClass)
  let (l, _) = t.tag(at: s.startIndex, unit: .word, scheme: .lemma)
  out.append("\(w)\t\(c?.rawValue ?? "-")\t\(l?.rawValue ?? "-")")
}
try! out.joined(separator: "\n").write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
