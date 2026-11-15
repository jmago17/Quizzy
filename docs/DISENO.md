# Quizzy — especificación de diseño «Noche»

Versión 1 · 2026-11-15

## De dónde viene y a dónde va

Quizzy heredó de Kaffa el aspecto de un diario: papel cálido, titulares en serif,
filetes de 3 pt, botones como sello en tinta sobre un 8 % de color. Funciona para
leer noticias; para jugar resulta frío y plano.

El rediseño de Murdoku marcó otra dirección: mesa de juego de noche. Esta
especificación extiende esa dirección a toda la app para que la portada, los
ajustes y los demás juegos pertenezcan al mismo sitio que Murdoku.

## Principios

1. **Una sola apariencia, oscura.** La app no sigue el modo claro del sistema.
2. **Superficies, no filetes.** La jerarquía se da con tarjetas redondeadas sobre
   un fondo liso; desaparecen el filete superior de color y la raya bajo el título.
3. **El color señala, no decora.** Cada juego conserva su tinta, pero solo en su
   icono, su insignia y sus marcas. El azul claro queda reservado a la acción
   principal de cada pantalla.
4. **Una acción principal por pantalla**, en cápsula rellena. Las demás van en
   cápsula teñida o como enlace.
5. **Tipografía de interfaz, no de periódico.** Sans del sistema en todo; el peso
   hace el trabajo que antes hacía la serif.
6. **El estado se lee sin color.** Toda insignia lleva texto; toda marca, forma.

## Paleta

Valores únicos (no cambian entre claro y oscuro). En código: `PZColor`.

| Papel | Token | Valor |
|---|---|---|
| Fondo de la app | `canvas` | `#12151F` |
| Tarjeta | `surface` | `#1B2233` |
| Relleno dentro de tarjeta, pista de control | `fill` | `#242C40` |
| Borde de tarjeta y separadores | `hairline` | `#2C3650` |
| Texto principal | `ink` | `#F4F6FB` |
| Texto secundario | `inkSecondary` | `#8E97AB` |
| Mobiliario sin texto (flechas, apagados) | `inkTertiary` | `#5E6880` |
| Acción principal | `accent` | `#8FC2F2` |
| Texto sobre la acción principal | `onAccent` | `#10141D` |
| Hecho, correcto | `success` | `#5FD0B0` |
| Aviso | `warning` | `#F2B95C` |
| Cerrado, error, sello | `danger` | `#F0766B` |

- Tintas por juego: las variantes oscuras que ya existían en `PZ` (sin cambios).
- Lavado de color (`PZColor.wash`): 14 % de la tinta, antes 8 %, porque sobre
  marino el 8 % no se distingue.
- Cuadrículas de letras (crucigrama, mini, sopa): la casilla sigue siendo clara y
  el bloque oscuro —es tinta sobre papel—, con el papel enfriado a `#DDE3EE` y el
  bloque a `#0C0F17`.
- Decoder mantiene su aparato propio; solo cambia el fondo que lo rodea.

Contraste comprobado por cálculo: `ink` sobre `surface` 14,7:1; `inkSecondary`
sobre `surface` 5,4:1; `onAccent` sobre `accent` 9,8:1.

## Tipografía

Sans del sistema, con Dynamic Type. En código: `PZFont`.

| Uso | Estilo | Peso |
|---|---|---|
| Título de portada | 34 pt relativo a largeTitle | heavy |
| Título de tarjeta destacada | largeTitle | bold |
| Cifra o titular de sección | title | bold |
| Sección | title3 | bold |
| Título de fila | title3 | semibold |
| Texto | body | regular |
| Etiqueta en mayúsculas | caption, interletrado 1,2 | semibold |
| Insignia | caption2, interletrado 1,2 | bold |

Fuera: serif, cursiva en el saludo.

## Forma y espacio

- Radios: insignia y botón, cápsula; ficha 10; azulejo 14; tarjeta 22; tarjeta
  destacada 26; hoja 28.
- Borde de tarjeta: 1 pt `hairline`. Sin sombras.
- Espaciado: escala de 4 pt existente (`PZSpace`), sin cambios.
- Objetivo táctil mínimo: 44 pt. Acción principal: 50 pt de alto.

## Componentes

- **Tarjeta** (`pzCard`): `surface`, radio 22, borde 1 pt.
- **Acción principal** (`pzPrimaryPill`): cápsula `accent`, texto `onAccent` en
  headline, ancho completo, 50 pt.
- **Acción secundaria** (`pzPill`): cápsula con lavado de la tinta y borde al 45 %.
- **Insignia** (`PZCapsuleBadge`): cápsula con texto en mayúsculas, lavado y borde
  de su color. `success` para «Empieza por aquí», `accent` para «En curso»,
  `danger` para «Hecho».
- **Icono de juego**: símbolo en la tinta del juego sobre su lavado; círculo de
  44 pt en fila, azulejo redondeado de 56 pt en la tarjeta destacada.

## Pantallas

### Portada
1. Cabecera: «Juegos» en heavy, saludo y racha en gris debajo; ajustes y menú de
   nuevos puzzles a la derecha. Sin barra de acento ni raya.
2. Progreso del día: fecha en etiqueta, «N de M completados», un segmento por
   juego en su tinta.
3. Tarjeta destacada: icono en azulejo, insignia de estado a la derecha, título,
   descripción, detalle y la acción principal a todo el ancho.
4. «Todos los puzzles»: filas en tarjeta —icono redondo, título, detalle,
   insignia de estado y flecha—. Una columna en iPhone, dos en iPad.

### Ajustes
Formulario sobre `canvas` con filas en `surface`; interruptores en `accent`.

### Juegos
Heredan fondo, tarjetas, tinta y tipografía por los tokens. Murdoku conserva su
tema (`MurdokuTheme`), cuyos valores coinciden con esta paleta.

## Accesibilidad

- Estado de cada juego como valor de accesibilidad de su fila, además de la insignia.
- Ningún estado depende solo del color.
- Texto con Dynamic Type en todos los estilos de la tabla.

## Fuera de esta versión

- Pestañas Hoy / Casos / Estadísticas.
- Ilustraciones de portada.
- Rediseño interior de cada juego (tableros, teclados, hojas de resultado): solo
  reciben la paleta y la tipografía nuevas.
- Modo claro.
