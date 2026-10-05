# Context.md — Mew hit v0.2 (v0.3 a v0.9 completas)

## Estado actual

**Qué es:** prototipo 3D "Mew Hit" en Godot 4.7.2. v0.2 (14 tandas), v0.3
(gato/cuarto/pulido), v0.4 (casa, 7+6, disparo, SSAO), v0.5 (gato 0.80,
agachado real, ventanas, pistola pequeña, PSX, decorado, partículas), v0.6
(paleta fría, patrulla, sin melee, radar, huida), v0.7 (tipos, GUI estilo,
shader v2, luna, baño, puertas, cortinas), v0.8 (menú dev F1-F4, Neutro) y
**v0.9**: dev ampliado (6 presets, 4 filtros, 3 nieblas, ayuda H), melee
con muros, **sin ratas en el nivel** y repisas arregladas. Sin apagar laptop.

**Versión:** **57 puntos** en verde (`VERIFICACION OK: 0 errores`, sin leaks
con `--verbose`), mutación validada en TODOS los puntos tocados (48/56/57
+ reworks 20/21/22/26/37/44/45/53). README simplificado a lo esencial; el
plan histórico (`Mew hit v0.2 plan.md`) se eliminó del repo a petición de
Hermes (queda en el historial de git).

**Contenido de v0.9 (lo nuevo):**

- **Dev ampliado** (`dev_luces.gd`): 6 presets (+Amanecer, +Mediodía),
  F2 por defecto **Todo**, F3 ciclo de 4 filtros (Nada/Suave/Fuerte/Noir,
  **Nada por defecto** con `visible=false`), F4 ciclo de 3 nieblas
  (Suave 10-50/Densa 4-25/Nada), toasts en minúsculas arriba-izquierda que
  duran **0.5 s**, tecla **H** con ayuda de controles (`hud.gd`:
  `mostrar_ayuda`, `alternar_ayuda`, `_dibujar_ayuda`). Shader: uniform
  `blanco_negro` + mix a luma (default y param 0.0).
- **Melee con muros** (`enemigo.gd`): AVISO y daño exigen distancia XZ,
  **`_ve_al_jugador()` y `_alcance_vertical()` (dy ≤0.7)**. En vertical
  hay vista libre, así que la puerta de vista sola no frenaba (pegaban
  desde el muro y desde justo encima). Test **57** (muro alto + caras
  opuestas + encima exacto sin muros; vida intacta + sin AVISO).
- **Fuera ratas del nivel**: borradas las 7 instancias Blanco (load_steps
  intacto); tests 20/21/22/26/37/44/45/53 con `_crear_raton()` propio
  (+`queue_free`); el 26 conecta `destruido` a `partida`; el 37 ya no
  depende del "último blanco". `objetivo.tscn/gd` y partida intactos.
- **Ventana arreglada**: la repisa estaba coplanar/hundida en el
  antepecho (z-fight = "se superponen"): ahora corona 0.03 por encima y
  asoma 0.15 al cuarto (las dos). **Marco sin solapes**: jambas dentro
  del hueco (±0.46), frente corto entre jambas (0.84) y cristal estrecho
  (0.76). Test 48: repisa existe, no hundida y asoma (cara -2.0/6.4) +
  jambas, frente y cristal en su sitio.
- Mutaciones 48/56/57 exactas y revertidas; 57/57 + `--verbose` limpio.

**Archivos clave:** `verificar.gd` (57), `scenes/{test_level(82),casa(88),
player,enemigo(6),gato,pistol,objetivo,hud}.tscn`, `scripts/{player,enemigo,
proyectil,objetivo,hud,decorado,motas,dev_luces,psx_filtro.gdshader,pistol,
gato,sonido,partida,vida}.gd`, `README.md` (simple ✓). Sin plan histórico
en el repo (borrado, en git).

**Verificado y funcionando** (carpeta del proyecto,
`$GODOT = C:\Users\Ed\Downloads\godot472\Godot_v4.7.2-stable_win64_console.exe`):

```powershell
& $GODOT --headless --path . --import          # solo al añadir/borrar archivos
& $GODOT --headless --path . --quit-after 200  # compila → 0
& $GODOT --headless --path . -s res://verificar.gd   # → 57/57, VERIFICACION OK
& $GODOT --headless --path . --verbose -s res://verificar.gd  # caza leaks
```

**Bugs ya resueltos (no reintroducir):**

- v0.3: `.tscn` sin comentarios `#`; `script=` antes que props export;
  `global_position` solo tras `add_child`; cámara asentar 30 frames;
  `Input.action_press` no llega a `_unhandled_input` → `InputEventAction`+flush;
  headless sin GPU (poof=Mesh+tween); PowerShell `Set-Content`=UTF-16;
  audio sonando al salir = leak → `_resumen()` para y espera frames.
- v0.4: test 48 con nodos anidados → `_buscar48`; test 37 apunta al último
  blanco (B6 en (3.5,0,1.6)); test 49 muestrea bandera cada 6 frames;
  `load_steps = subs+ext+1` tras CADA edición.
- v0.5: quitar un export obliga a quitar su línea del `.tscn`; un `return`
  deja inalcanzable lo dedentado (lo cazó @revisor); prohibido Set-Content;
  el chequeo tardío de un efecto efímero no puede fallar; quads bajo padre
  girado PI: local (x,z) → mundo (-x,6.38-z); posters en pared sólida.
- v0.6: **el ratón con física cae al suelo**: tests 22/45 re-encaran antes
  de cada tiro (asumían ratón flotante); **la huida necesita al jugador en
  el suelo y en marcha** (teletransportado en el aire no corre): asentar
  10f + muestreo con break; **la huida por distancia sola espantaba los
  tiros de los tests** (blanco a 1 m ≈ 0.3 m del jugador): puerta por
  velocidad >1.0; **patrulla con lazy-init** (`_ready` corre antes de
  colocar); **un edit que come un `\n` deja `void:` + código en la misma
  línea** (parse error hud.gd:410, dos veces ya).
- v0.7: **contar mal los subs nuevos rompe el parse silencioso** (casa
  87→88: 71+17-2=86, +1+1); **el último blanco lo decide el orden del
  árbol**: Blanco7 va ANTES de Blanco6 o el 37 apunta a otro cuarto;
  **params del shader viven en DOS sitios** (defaults `.gdshader` +
  `shader_parameter` del `.tscn`, el instance manda).
- v0.8: **el script del HUD vive en `HUD/Reticula`, no en `HUD`**: el toast
  dev lo busca ahí (`get_node_or_null("HUD/Reticula")`).
- v0.9: **un `call()` a función inexistente aborta el test en silencio**
  (VERIFICACION OK con SCRIPT ERROR: mirar siempre ambas líneas);
  **teletransportar al jugador lo deja en el aire**: asentar antes de
  medir velocidad; **repisa coplanar = z-fight** (coronar 0.03 + asomar);
  **en vertical hay vista libre**: la puerta de vista no basta contra
  muros altos, falta puerta por altura (dy ≤0.7);
  **marco coplanar = solape**: jambas dentro del hueco y frente entre
  jambas, nada de caras vistas compartidas con el muro.

**Flujo dual-model (acordado 2026-10-03):** sesión = Muse arquitecto;
@scripter = piezas aisladas con brief; @revisor audita tras cada pieza.
v0.9 se hizo entera en sesión principal (todo acoplado a tests).

**Pendiente:**

- **Jugar a mano con F1-F4 + H**: 6 presets, 4 filtros (Nada por defecto),
  3 nieblas, AO Todo por defecto, ayuda, melee con muros (subirse al muro
  y comprobar), ventana sin solapes, y elegir el ambiente ideal.
- Quedan las otras cosas que no gustan (dijiste que hay más).
- Si se toca algo: compila + 57/57 + `--verbose` + mutación del punto.
- NO apagar la laptop.

## Bitácora

## [2026-10-04] Entrada #1
- Empezamos haciendo: v0.4 completa — casa, escala 0.95, proyectil.gd con
  puntería, SSAO, tests 48/49.
- Problemas que aparecieron: FALTA37 (Blanco6 en muro cocina), FALTA48
  (nodos Casa anidados), chequeo ciego del 49 (bala se autolibera).
- Qué hicimos: B6 a (3.5,0,1.6), `_buscar48`, muestreo cada 6 frames;
  mutaciones 27/29/30/43/48/49 con FALTA exacta y revertidas.
- Repasamos/decidimos: plan.md histórico intacto; README a 49; queda jugar.

## [2026-10-05] Entrada #2
- Empezamos haciendo: v0.5 con modo plan + flujo dual-model: escala 0.80,
  agachado real (cabe bajo la cama), ventanas, S1-S4 delegadas, ambiente y
  tests 50/51.
- Problemas que aparecieron: tabulación perdida en el 44; S2 vació hud.tscn
  (restaurado de backup); S3 con cuadros inalcanzables (cazó @revisor); S4
  a medias (relanzado); 2 posters mal ubicados (corregidos).
- Qué hicimos: todo + mutaciones 17/27/43/44/48/50/51 exactas y revertidas;
  51/51 + `--verbose` limpio; README a 51.
- Repasamos/decidimos: plan.md intacto; pendiente jugar (retícula, posters,
  pies, filtro).

## [2026-10-05] Entrada #3
- Empezamos haciendo: v0.6 pedida por Hermes (iluminación rara con bandas
  y naranja, mapa más dinámico, sin melee, GUI con sentido, diversión).
  Investigación PSX (niebla gris + tinte + ambiente oscuro + pozas).
- Problemas que aparecieron: ratones con física caen (22/45 re-encaran);
  huida espantaba tiros de tests (puerta por velocidad); huida sin muestra
  por jugador en el aire (asentar + muestreo); parse por `\n` comido en
  hud.gd:410.
- Qué hicimos: paleta fría + posterize 10, patrulla + sin melee + rebalanceo
  (8/2.4 s), ratones CharacterBody que huyen, HUD radar + zona, tests 52/53;
  mutaciones 29/50/52/53 exactas y revertidas; 53/53 + `--verbose` limpio.
- Repasamos/decidimos: todo en sesión principal (acoplado a tests); README
  a 53; queda jugar (paleta, bandas, patrullas, caza, tiroteos, radar).

## [2026-10-05] Entrada #4
- Empezamos haciendo: v0.7 pedida por Hermes (GUI con estilo, más
  dinamismo, shader, otra iluminación/AO, 2 tipos de enemigos, mapa más
  grande, puertas anchas, decoración dinámica). Todo en sesión principal.
- Problemas que aparecieron: conteo de subs del baño mal a la primera
  (87→88); el orden del árbol decide el último blanco (B7 antes de B6).
- Qué hicimos: rojos/naranjas con cuchillo visible, puertas a 1.2 m, baño
  completo, Pelota2, cortinas con sway, GUI con estilo, shader v2 con
  grano, noche de luna + SSAO 0.9/3.0, tests 54/55; mutaciones 29/48/50/
  54/55 exactas y revertidas; 55/55 + `--verbose` limpio.
- Repasamos/decidimos: README a 55; queda jugar (luna, shader, tipos,
  baño, cortinas, GUI); sin apagado de laptop.

## [2026-10-05] Entrada #5
- Empezamos haciendo: v0.8 solo-iluminación (Hermes: la luna no le gusta,
  quiere comparar en vivo). Menú dev F1-F4 + preset Neutro por defecto.
- Problemas que aparecieron: el `\n` comido volvió a morder en hud.gd
  (segunda vez); el script del HUD está en Reticula, no en la raíz HUD.
- Qué hicimos: dev_luces.gd (4 presets + ciclo AO SSAO/SSIL/todo/nada +
  toggles con toast), test 50 al Neutro, test 56 nuevo; mutación del AO
  exacta y revertida; 56/56 + `--verbose` limpio.
- Repasamos/decidimos: README a 56; pendiente jugar con F1-F4 y elegir el
  ambiente ideal + el resto de cosas que no gustan.

## [2026-10-05] Entrada #6
- Empezamos haciendo: v0.9 (F1 con más presets, F2 Todo, F3 con filtros y
  Nada por defecto, F4 con nieblas, toast arriba-izq 0.5 s, H ayuda; melee
  con muros; fuera ratas del nivel; repisas arregladas).
- Problemas que aparecieron: `call()` a función inexistente aborta el
  test en silencio (OK con SCRIPT ERROR); jugador teletransportado en el
  aire no corre; repisa coplanar = z-fight.
- Qué hicimos: dev ampliado + test56 reescrito, melee con puerta de vista
  + test57, 7 Blancos borrados + 8 tests con `_crear_raton()`, repisas
  coronando + asserts 48; mutaciones 48/56/57 exactas y revertidas;
  57/57 + `--verbose` limpio.
- Repasamos/decidimos: README a 57; pendiente jugar (dev completo, melee,
  ventana, ambiente ideal) + el resto de cosas que no gustan.

## [2026-10-05] Entrada #7
- Empezamos haciendo: fixes de partida (Hermes: amarillos pegan desde el
  muro y desde encima; el marco se superpone con la pared).
- Problemas que aparecieron: en vertical la vista está libre (la puerta de
  vista no frenaba); jambas/frente coplanares con el muro.
- Qué hicimos: puerta vertical dy ≤0.7 en AVISO y daño + sub-test C (sin
  muros, solo cae ese); jambas al hueco, frente entre jambas, cristal 0.76
  + asserts 48; mutaciones exactas y revertidas; 57/57 + `--verbose`.
- Repasamos/decidimos: nada nuevo que documentar en README (fixes);
  pendiente jugar (melee vertical, marco).

## [2026-10-05] Entrada #8
- Empezamos haciendo: subida a GitHub (https://github.com/0Mcs/Mew-hit,
  público, commit 67503c4) + limpieza: README simplificado y plan
  histórico borrado del repo (vive en git).
- Problemas que aparecieron: ninguno, `gh` no instalado (repo creado a
  mano en la web).
- Qué hicimos: `.gitignore` (fuera `.godot/` y `.opencode/`), rama main,
  push verificado (local == remoto).
- Repasamos/decidimos: abrir sesión nueva con el prompt de handoff.
