# Bilingual games regression checks

Run from the repository root:

```sh
python3 Tests/GamesLanguage/run.py --mode all --compile-timeout 240 --runtime-timeout 180
```

The runner compiles production Foundation models/generators/progress code with
Swift 6, excluding SwiftUI view declarations and iOS-only outer guards. It loads
the real Spanish JSON resources and authored English bank. It uses a disposable
UserDefaults suite and never launches a simulator, contacts StoreKit or modifies
app data. Generated source and executable live in a temporary directory.

The bounded default covers 21 English seeds; one Spanish seed for word search,
Quartiles, crossword, Mini, Hashtag and Wordle; Maze connectivity; 600 bilingual
Murdle cases; 32 Murdoku cases with an independent exhaustive solver; language
selection; English game names and the ES10/EN9 offering; progress/timing/history isolation; word-grid
snapshot roundtrip; concurrent generation with explicit ES/EN inputs.

Spanish Anygram's existing large-vocabulary generator is separate:

```sh
python3 Tests/GamesLanguage/run.py --mode spanish-anygram --runtime-timeout 180
```

That slow mode was not completed in this task. An earlier broader run timed out;
its coarse stage logging did not identify the precise generator. Do not report
that timeout as a puzzle validity failure or as passing coverage.

Other modes (`english`, `spanish`, `progress`) narrow diagnostics without changing
production algorithms. `spanish` excludes Anygram. UIKit rendering, navigation,
installed-dictionary behavior, real StoreKit and physical-device migration remain
manual checks in `estado.md`; these tests do not certify them.

Quartiles remains in generator/data compatibility checks but is no longer offered
in English. The `progress` mode verifies nine-game completion/recommendations and
retention of both Spanish and historical English Quartiles progress.
