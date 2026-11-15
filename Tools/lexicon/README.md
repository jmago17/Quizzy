# Tools/lexicon — cómo se generaron las listas de `Quizzy/Games/Data` (2026-11-15)

Scripts de un solo uso, guardados para poder repetir o revisar el proceso. No se ejecutan en el build.

## Fuentes externas (descargar a `$S/dl/`, no se versionan)
- Frecuencias: `hermitdave/FrequencyWords` → `content/2018/es/es_full.txt` (subtítulos; decide AÑO vs ANO).
- Diccionario: LibreOffice `dictionaries/es/es_ES.dic` + `es_ES.aff` (RLA-ES, Hunspell).
  `unmunch.py` expande sufijos/prefijos (657.750 formas). Solo entradas en minúscula: deja fuera nombres propios.
- `tagall.swift`: NLTagger (categoría + lema) por palabra. Fiable en palabras largas, NO en las de 3–5 letras
  (llama verbo a CARNE y adverbio a ARROZ): por eso Wordle se revisó a mano.

## Orden
1. `enie.py` — restaura la Ñ (los JSON originales no tenían ninguna: SEÑOR era SENOR). Se usa la forma con Ñ
   si es ≥5× más frecuente. Excepción CONO (los subtítulos prefieren la palabrota). Sustituye en el sitio.
   En las listas de validación se conservan ambas formas si la de N también es común (ANO/AÑO).
   Pistas: solo BAÑERA/SEÑAL/SEÑORA (ANO y CANON mantienen su definición, que es la de la forma sin Ñ).
2. `apply_curation.py` — saca de `common_words` nombres propios/inglés/regionalismos (no están en el diccionario;
   con lista de rescate a mano) y primera pasada de Wordle.
3. `answer_words.py` — `answer_words.json` = `common_words` sin conjugaciones (para soluciones de Quartiles y Sopa).
4. `wordle_round2.py`, `wordle_round3.py` — conjugaciones, nombres y palabrotas de Wordle, sustituidas EN EL SITIO
   (misma longitud → el orden diario de los demás días no cambia; el de hoy, 2026-11-15, tampoco).
5. `clue_fixes.py`, `clue_additions.py` — pistas reescritas a mano (autorreferentes, largas, acepción rara) y
   palabras cortas nuevas para el mini crucigrama.
6. `hashtag.py` — plantillas de Hashtag desde `wordle_answers` (pegadas en `CasualPuzzleGames.swift`).

## Límites conocidos
- Se cuelan conjugaciones que el etiquetador no marca como verbo (p. ej. RUEGA, COMPRENDIO).
- Anygram mantiene conjugaciones a propósito (AMA, USA son naturales en ese juego); salen algunas raras (CAIA, DIRA).
- Las ~1.400 pistas restantes no se han revisado una a una.
