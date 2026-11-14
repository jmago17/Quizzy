#!/usr/bin/env python3
"""Compiles Shared/Games/DecoderCore.swift (pure Foundation) with the executable
checks in main.swift and runs them. No simulator, no UI. DEVELOPER_DIR per command."""
import os, subprocess, tempfile, shutil
from pathlib import Path
root = Path(__file__).resolve().parents[2]
env = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode-beta.app/Contents/Developer'))
with tempfile.TemporaryDirectory(prefix='kaffa-decoder-') as t:
    work = Path(t)
    # main.swift cannot hold @main alongside top-level code: concatenate into one library-style file.
    src = work / 'Checks.swift'
    src.write_text((root / 'Quizzy/Games/DecoderCore.swift').read_text() + '\n' + (Path(__file__).parent / 'main.swift').read_text())
    out = work / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library', '-O',
                    '-module-cache-path', '/tmp/kaffa-decoder-module-cache', str(src), '-o', str(out)],
                   env=env, check=True, timeout=300)
    subprocess.run([str(out)], env=env, check=True, timeout=300)
