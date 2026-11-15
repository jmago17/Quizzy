import json, sys, unicodedata, itertools, collections
S, D = sys.argv[1], sys.argv[2]
def norm(w):
    w = w.upper().replace('Ñ', '\x00')
    w = ''.join(c for c in unicodedata.normalize('NFD', w) if unicodedata.category(c) != 'Mn')
    return w.replace('\x00', 'Ñ')
freq = collections.Counter()
for line in open(f'{S}/dl/full.txt', encoding='utf-8'):
    p = line.split()
    if len(p) == 2 and p[0].isalpha(): freq[norm(p[0])] += int(p[1])
def variants(w):
    idx = [i for i, c in enumerate(w) if c == 'N']
    for k in range(1, min(len(idx), 2) + 1):
        for comb in itertools.combinations(idx, k):
            c = list(w)
            for i in comb: c[i] = 'Ñ'
            yield ''.join(c)
def best(w):
    """Devuelve la forma con Ñ si domina claramente a la forma con N, si no None."""
    if 'N' not in w: return None
    cands = sorted(variants(w), key=lambda v: -freq[v])
    b = cands[0]
    fb, fw = freq[b], freq[w]
    if fb >= 20 and fb >= 5 * max(fw, 1): return b
    return None
out = {}
report = []
clues = json.load(open(f'{D}/natural_clues.json'))
for name in ['wordle_answers', 'common_words', 'playable_words', 'puzzle_words']:
    words = json.load(open(f'{D}/{name}.json'))
    res, changed = [], 0
    for w in words:
        b = best(w)
        if b:
            changed += 1
            if name in ('wordle_answers', 'common_words'): res.append(b)
            else:
                res.append(b)
                # Validación: se mantiene la forma sin Ñ solo si también es común por sí misma.
                if freq[w] >= 200: res.append(w)
            report.append(f'{name}\t{w}\t{b}\t{freq[w]}\t{freq[b]}')
        else: res.append(w)
    res = sorted(set(res))
    out[name] = res
    print(name, len(words), '->', len(res), 'cambiadas', changed)
# Las pistas definen el significado: solo se cambia la palabra si la definición no es de la forma sin Ñ.
cl_changes = [(w, t, best(w)) for w, t in clues if best(w)]
open(f'{S}/tools/enie_report.tsv', 'w').write('\n'.join(report))
open(f'{S}/tools/enie_clues.tsv', 'w').write('\n'.join(f'{w}\t{b}\t{t}' for w, t, b in cl_changes))
json.dump(out, open(f'{S}/tools/enie_out.json', 'w'), ensure_ascii=False)
print('pistas afectadas', len(cl_changes))
