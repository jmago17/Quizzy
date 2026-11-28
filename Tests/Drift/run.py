#!/usr/bin/env python3
"""Compila el motor de Derrape (QuizzyWatch/WatchArcade.swift + WatchDriftView.swift) para macOS
con unos sustitutos mínimos y juega partidas simuladas con el piloto automático: sin simulador ni
interfaz. Comprueba que no revienta, que el piloto pasa de etapa sin que la carretera le obligue a
chocar, que coge monedas y turbos, y que todo (las cuatro etapas) se puede dibujar. DEVELOPER_DIR por comando."""
import os, subprocess, tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[2]
env = dict(os.environ, DEVELOPER_DIR=os.environ.get('DEVELOPER_DIR', '/Applications/Xcode-beta.app/Contents/Developer'))
with tempfile.TemporaryDirectory(prefix='quizzy-drift-') as t:
    work = Path(t)
    here = Path(__file__).parent
    parts = [here / 'stubs.swift', root / 'QuizzyWatch/WatchArcade.swift', root / 'QuizzyWatch/WatchDriftView.swift', here / 'main.swift']
    src = work / 'Checks.swift'
    src.write_text('\n'.join(p.read_text() for p in parts))
    out = work / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-O', '-D', 'DEBUG',
                    '-module-cache-path', '/tmp/quizzy-drift-module-cache', str(src), '-o', str(out)],
                   env=env, check=True, timeout=600)
    subprocess.run([str(out)] + __import__('sys').argv[1:], env=env, check=True, timeout=900)
