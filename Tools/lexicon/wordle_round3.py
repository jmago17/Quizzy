# Tercera pasada sobre wordle_answers (2026-11-15), revisando la lista entera a mano:
# nombres propios, inglés, conjugaciones y palabras malsonantes. Sustitución EN EL SITIO.
import json, sys
D = sys.argv[1]
REMOVE = """ALANA ARGEL CELIA CILLA CORPS CROSS DANTE DELES FACTO FILMS FLASH GALES GILES GOLFA GRANT GRECO HENRY HUELA HUELO HUYES IONES
JUDAS LIBIA LUISA MAMON MAURA MAURO MIRZA NAZIS ORGIA PARIO PERRA POLLA PORRO RAMON RUBIN SALIO SANSA SILVA SIRIO TESLA TULIO
VALIA VEGAS VERGA VUELA BOLIN""".split()
ADD = """PACTO MOSCA CURVA CLAVO PAUSA CICLO RECTO ALTAR TINTA LUNAR BOXEO MAREA GALLO RUINA PLAGA GASTO MILLA FRENO TORNO AROMA
PALMA MENTA LECHO PANDA TRAMA FRUTO CIFRA FLORA CARPA HONRA AVENA BROTE FRESA BRUJO BALSA VICIO COLMO BALDE PERLA FLECO CERCO
COPLA FICHA GRAPA JARRA OLIVO POLEA""".split()
w = json.load(open(f'{D}/wordle_answers.json'))
sub = dict(zip(REMOVE, ADD)); w = [sub.get(x, x) for x in w]
assert len(w) == len(set(w)) == 1072
json.dump(w, open(f'{D}/wordle_answers.json', 'w'), ensure_ascii=False, separators=(',', ':'))
