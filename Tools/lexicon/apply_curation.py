import json, sys
S, D = sys.argv[1], sys.argv[2]
exec(open(f'{S}/tools/curate.py').read().split("common = json.load")[0])
# --- Wordle: sustitución en el sitio (misma longitud → mismo orden de días salvo los cambiados)
REMOVE = "ALLEN ALPES ARBOR BACON BAYON BERTA BOCON BONES CAGON CARLO DELLA FREDO GAUSS GRILL JUANA LIGHT LOBBY MACON MARLO ORALE PETRA PICHA RALLY ROBIN RUSIA SATAN SHORT SIOUX SPRAY SUBTE TANIA TRUST VALET VICHY ZEBRA BATON DUCTO".split()
ADD = "LUGAR AMIGO MUJER PARTE FORMA PUNTO CLASE CULPA SITIO TRATO LIBRO CALLE VIAJE CAMPO MITAD CARTA BROMA BAILE BANCO CALMA PISTA LECHE PARED PLAYA MAGIA COSTA PECHO TECHO DISCO FECHA REGLA OTOÑO ARAÑA FRUTA HORNO SELLO TABLA".split()
assert len(REMOVE) == len(ADD) == 37, (len(REMOVE), len(ADD))
wordle = json.load(open(f'{D}/wordle_answers.json'))
assert not set(ADD) & set(wordle) and set(REMOVE) <= set(wordle)
sub = dict(zip(REMOVE, ADD)); sub['NANDU'] = 'ÑANDU'
wordle = [sub.get(w, w) for w in wordle]
assert len(wordle) == len(set(wordle)) == 1072
json.dump(wordle, open(f'{D}/wordle_answers.json', 'w'), ensure_ascii=False, separators=(',', ':'))
# --- common_words: fuera nombres propios / inglés / regionalismos (salvo rescatadas)
RESCUE = set("""BURRITO BURRITOS CHUPITO CHUPITOS DIABETICO EPINEFRINA FIBRILACION GEISHA JUDO YOGA MANTRA MOUSSE YETI SAMBA
RETRO GRIAL VISON PARAMEDICO PARAMEDICOS PATOLOGO TOXICOLOGIA TOXICOLOGICO HIPERESPACIO SUPERNOVA BELLISIMA BOLITAS PALITO
PALITOS OJITOS PATITO SATELITAL SOLTERONA RIESGOSO CAVERNICOLA NUDISTA PIROMANO ESNOB GOURMET PARRILLADA DESHICE DESHIZO
MAMITA TONTITO VIEJITA TRABAJITO RAPIDITO MONITO""".split())
common = json.load(open(f'{D}/common_words.json'))
drop = {w for w in common if not spanish(w) and w not in clued and w not in friendly and w not in RESCUE}
common = [w for w in common if w not in drop]
json.dump(common, open(f'{D}/common_words.json', 'w'), ensure_ascii=False, separators=(',', ':'))
# --- answer_words: common sin conjugaciones (para elegir soluciones de Quartiles y Sopa de letras)
answers = [w for w in common if not conjugated(w)]
json.dump(answers, open(f'{D}/answer_words.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print('fuera de common', len(drop), 'common', len(common), 'answer_words', len(answers))
