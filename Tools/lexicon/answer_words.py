"""answer_words.json = common_words sin formas que solo son conjugación.
Conjugación = NLTagger dice verbo, no es infinitivo ni participio, y además
(no es entrada del diccionario Hunspell ni su plural/femenino) o tiene terminación verbal inequívoca."""
import json, sys, re, unicodedata
S, D = sys.argv[1], sys.argv[2]
head = set(json.load(open(f'{S}/tools/headwords.json')))
def nominal(w):
    if w in head: return True
    for suf, rep in (('S',''),('ES',''),('ONES','ON'),('A','O'),('AS','O'),('AS','A'),('ICES','IZ'),('CES','Z')):
        if w.endswith(suf) and w[:-len(suf)] + rep in head: return True
    return False
tags = {}
for l in open(f'{S}/tools/cw_tags.tsv').read().split('\n'):
    p = l.split('\t')
    if len(p) == 3: tags[p[0]] = p[1]
clued = {w for w, _ in json.load(open(f'{D}/natural_clues.json'))}
PART = re.compile(r'(ADO|IDO|ADA|IDA|ADOS|IDOS|ADAS|IDAS)$'); INF = re.compile(r'(AR|ER|IR)$')
STRONG = re.compile(r'(AMOS|EMOS|IMOS|AIS|EIS|ABA|ABAS|ABAN|ARON|IERON|ASTE|ISTE|ANDO|IENDO|RIA|RIAN|RIAS|SEN|SES)$')
def conjugated(w):
    if w in clued or tags.get(w) != 'Verb' or INF.search(w) or PART.search(w): return False
    return (not nominal(w)) or bool(STRONG.search(w))
common = json.load(open(f'{D}/common_words.json'))
answers = [w for w in common if not conjugated(w)]
json.dump(answers, open(f'{D}/answer_words.json', 'w'), ensure_ascii=False, separators=(',', ':'))
L = lambda ws, a, b: sum(a <= len(x) <= b for x in ws)
print('common', len(common), 'answer_words', len(answers), '| Quartiles 9-12:', L(common,9,12), '->', L(answers,9,12), '| Sopa 4-9:', L(common,4,9), '->', L(answers,4,9))
