"""Plantillas de Hashtag: TOP/BOTTOM horizontales (filas 1 y 3), LEFT/RIGHT verticales (columnas 1 y 3).
Cruces: TOP[1]=LEFT[1], TOP[3]=RIGHT[1], BOTTOM[1]=LEFT[3], BOTTOM[3]=RIGHT[3]. Ninguna palabra se repite."""
import json, sys, random, collections
words = [w for w in json.load(open(sys.argv[1])) if len(w) == 5]
N = int(sys.argv[2])
rng = random.Random(20261115)
by13 = collections.defaultdict(list)          # (letra1, letra3) -> palabras
for w in words: by13[(w[1], w[3])].append(w)
used, out = set(), []
order = words[:]; rng.shuffle(order)
for top in order:
    if len(out) >= N: break
    if top in used: continue
    for left in rng.sample(words, len(words)):
        if left in used or left == top or left[1] != top[1]: continue
        found = False
        for right in rng.sample(words, len(words)):
            if right in used or right in (top, left) or right[1] != top[3]: continue
            cands = [b for b in by13[(left[3], right[3])] if b not in used and b not in (top, left, right)]
            if cands:
                bottom = rng.choice(cands)
                out.append((top, bottom, left, right)); used |= {top, bottom, left, right}; found = True; break
        if found: break
for t in out: assert t[0][1]==t[2][1] and t[0][3]==t[3][1] and t[1][1]==t[2][3] and t[1][3]==t[3][3]
print(len(out), file=sys.stderr)
for t, b, l, r in out:
    print(f'        .init(horizontalTop: "{t}", horizontalBottom: "{b}", verticalLeft: "{l}", verticalRight: "{r}"),')
