"""Expande un diccionario Hunspell (solo SFX + PFX cruzados, sin flags anidados) a formas."""
import re, sys
def load(base):
    rules = {}
    cur = None
    for line in open(base + '.aff', encoding='utf-8'):
        p = line.split('#')[0].split()
        if len(p) >= 4 and p[0] in ('SFX', 'PFX') and p[2] in ('Y', 'N') and p[3].isdigit():
            rules[p[1]] = (p[0], p[2] == 'Y', []); continue
        if len(p) >= 4 and p[0] in ('SFX', 'PFX') and p[1] in rules:
            strip = '' if p[2] == '0' else p[2]
            add = p[3].split('/')[0]; add = '' if add == '0' else add
            cond = p[4] if len(p) > 4 else '.'
            rx = re.compile((cond + '$') if p[0] == 'SFX' else ('^' + cond))
            rules[p[1]][2].append((strip, add, rx))
    forms = set()
    lines = open(base + '.dic', encoding='utf-8').read().split('\n')[1:]
    for line in lines:
        if not line.strip(): continue
        word, _, flags = line.strip().partition('/')
        flags = flags.split()[0] if flags else ''
        if not word[:1].islower(): continue           # nombres propios y siglas fuera
        forms.add(word)
        sfx = []
        for f in flags:
            r = rules.get(f)
            if not r: continue
            kind, cross, items = r
            for strip, add, rx in items:
                if kind == 'SFX' and rx.search(word) and word.endswith(strip):
                    w = word[:len(word) - len(strip)] + add; forms.add(w); sfx.append((w, cross))
                elif kind == 'PFX' and rx.search(word) and word.startswith(strip):
                    forms.add(add + word[len(strip):])
        for f in flags:                                # prefijo + sufijo cruzados
            r = rules.get(f)
            if r and r[0] == 'PFX' and r[1]:
                for w, cross in sfx:
                    if cross:
                        for strip, add, rx in r[2]:
                            if rx.search(w) and w.startswith(strip): forms.add(add + w[len(strip):])
    return forms
if __name__ == '__main__':
    f = load(sys.argv[1]); print(len(f))
    open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(sorted(f)))
