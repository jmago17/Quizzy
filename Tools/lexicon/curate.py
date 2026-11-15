import json, sys, re, random
S, D = sys.argv[1], sys.argv[2]
forms = set(json.load(open(f'{S}/tools/forms_folded.json')))
def spanish(w):
    if w in forms: return True
    for suf, rep in (('S', ''), ('ES', ''), ('ONES', 'ON'), ('AS', 'O'), ('A', 'O')):
        if w.endswith(suf) and (w[:-len(suf)] + rep) in forms: return True
    return False
tags = {}
for l in open(f'{S}/tools/cw_tags.tsv').read().split('\n'):
    p = l.split('\t')
    if len(p) == 3: tags[p[0]] = p[1]
clued = {w for w, _ in json.load(open(f'{D}/natural_clues.json'))}
src = open(f'{D}/../PuzzleModels.swift').read()
fr = src[src.index('static let friendlyWords'):]; fr = fr[:fr.index(']')]
friendly = set(re.findall(r'"([A-ZÑ]+)"', fr))
PART = re.compile(r'(ADO|IDO|ADA|IDA|ADOS|IDOS|ADAS|IDAS)$'); INF = re.compile(r'(AR|ER|IR)$')
def conjugated(w):
    return tags.get(w) == 'Verb' and not INF.search(w) and not PART.search(w) and w not in clued and w not in friendly
common = json.load(open(f'{D}/common_words.json'))
foreign = [w for w in common if not spanish(w) and w not in clued and w not in friendly]
print('common fuera (no español / nombre propio):', len(foreign)); print(' ', ' '.join(foreign))
wordle = json.load(open(f'{D}/wordle_answers.json'))
wf = [w for w in wordle if not spanish(w)]
print('wordle fuera:', len(wf), ' '.join(wf))
