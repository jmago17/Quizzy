#!/usr/bin/env python3
"""Run actual Foundation puzzle generators/progress with isolated defaults, no simulator.
Only platform guards/UI declarations are removed; algorithms and banks are production.
"""
from pathlib import Path
import os, subprocess, tempfile, shutil, argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--mode", choices=["all", "english", "spanish", "progress", "spanish-anygram", "spanish-wide", "fingerprint"], default="all")
parser.add_argument("--runtime-timeout", type=int, default=180)
parser.add_argument("--compile-timeout", type=int, default=180)
args = parser.parse_args()
root=Path(__file__).resolve().parents[2]
games=root/'Quizzy/Games'
def block(text, signature):
    start=text.index(signature); opening=text.index('{',start); depth=1; i=opening+1
    while depth:
        depth += (text[i]=='{')-(text[i]=='}'); i+=1
    return text[start:i]
def core(name):
    text=(games/name).read_text()
    if text.startswith('#if os('): text=text.split('\n',1)[1]  # '#if os(iOS)' o '#if os(iOS) || os(watchOS)'
    if text.rstrip().endswith('#endif'): text=text.rstrip()[:-6]
    return text
# UI cannot be linked into the Foundation harness; guard its entry points explicitly.
screen = (games/'PuzzlesScreen.swift').read_text()
assert "PuzzleKind.allCases" not in screen
for signature in ["private func open(", "private func puzzle(", "private func newPuzzle("]:
    assert "guard offered.contains(kind)" in block(screen, signature), signature
assert "guard PuzzleKind.offered(in: language).contains(kind)" in block(screen, "nonisolated private static func make(")
assert "let available = PuzzleKind.offered(in: language)" in block(screen, "@MainActor private func generateDailyGames()")
assert "if offered.contains(.quartiles)" in block(screen, "@ViewBuilder private func destination(")
for event in [".pzNewSameGame", ".pzOpenNextGame"]:
    section = screen.split("publisher(for: " + event + ")", 1)[1].split(".onReceive", 1)[0].split(".task(id:", 1)[0]
    assert "offered.contains(kind)" in section, event
assert "progress.firstPending ?? offered.first ?? .wordsearch" in screen
print("PASS source guards: generation, restoration, route notifications, direct opening and completed-day fallback use offered catalog", flush=True)
sources=['import Foundation\nimport Combine\nlet testSuiteName = "kaffa-games-test-\\(UUID().uuidString)"\nnonisolated(unsafe) let testDefaults = UserDefaults(suiteName: testSuiteName)!']
sources.append((root/'Quizzy/Support/AppLanguage.swift').read_text().replace('.standard','testDefaults'))
sources.append(core('PuzzleModels.swift').replace('UserDefaults(suiteName: "quizzy.games")\n        ?? .standard','testDefaults'))
sources.append(core('DecoderCore.swift'))  # PuzzleKind.decoder: seed salt, stats ids, DecoderStore wipe
sources += [core(n) for n in ['WordleModel.swift','MazeModel.swift','PuzzleGenerator.swift','MiniCrossword.swift','PuzzleStats.swift','PuzzleSnapshotStore.swift','AnygramPrefetch.swift','AnygramDefaultData.swift']]
sources.append(core('EnglishPuzzleLexicon.swift'))
for name, types in [('CasualPuzzleGames.swift',['struct HashtagPuzzle','private enum HashtagBank']),('MurdleGame.swift',['struct MurdlePuzzle','struct MurdokuPuzzle'])]:
    text=(games/name).read_text()
    sources += [block(text,t) for t in types]
sources.append((Path(__file__).parent/'main.swift').read_text())
for name in ['logic_checks.swift','word_checks.swift','spanish_wide.swift']:
    p=Path(__file__).parent/name
    if p.exists(): sources.append(p.read_text())
env=dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode-beta.app/Contents/Developer'))
with tempfile.TemporaryDirectory(prefix='kaffa-games-') as temp:
    work=Path(temp); source=work/'Checks.swift'; source.write_text('\n'.join(sources))
    resources=work/'Resources'; resources.mkdir()
    for p in (games/'Data').glob('*.json'): shutil.copy2(p, resources/p.name); shutil.copy2(p, work/p.name)
    binary=work/'checks'
    subprocess.run(['xcrun','swiftc','-swift-version','6','-parse-as-library','-module-cache-path','/tmp/kaffa-games-module-cache','-g','-O',str(source),'-o',str(binary)],env=env,check=True,timeout=args.compile_timeout)
    if args.mode == "fingerprint":
        # Dos procesos distintos: el hash de Swift cambia de semilla en cada uno.
        runs = [subprocess.run([str(binary), args.mode], env=env, check=True, cwd=work, timeout=args.runtime_timeout,
                               capture_output=True, text=True).stdout for _ in range(2)]
        a = [l for l in runs[0].splitlines() if l.startswith("FP ")]
        b = [l for l in runs[1].splitlines() if l.startswith("FP ")]
        print("\n".join(a))
        if a != b or not a:
            for x, y in zip(a, b):
                if x != y: print("DISTINTO\n  1: " + x + "\n  2: " + y)
            raise SystemExit("FAIL fingerprint: la misma semilla dio puzzles distintos en dos procesos")
        print("PASS fingerprint: misma semilla → mismos puzzles en dos procesos (%d semillas)" % len(a))
        raise SystemExit(0)
    try:
        subprocess.run([str(binary), args.mode], env=dict(env, SWIFT_BACKTRACE='enable=yes'), check=True, cwd=work, timeout=args.runtime_timeout)
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT: mode {args.mode} exceeded {args.runtime_timeout}s; the last printed stage identifies unfinished coverage.", flush=True)
        raise SystemExit(124)
