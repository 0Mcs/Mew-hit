# Mew Hit v0.2

Prototipo 3D en Godot 4.7.2: un gato en tercera persona con cámara de hombro,
disparo con raycast, trepar, dash, blancos, enemigos con IA mínima, HUD dibujado
a mano y sonido 100% procedural. Todo el código y todos los sonidos están
escritos desde cero para este prototipo: no hay assets externos, ni texturas,
ni modelos importados.

La revisión **v0.3** encima del v0.2 añade: gato cuadrúpeda a escala real
compartido con los enemigos (`scenes/gato.tscn`), dormitorio de prueba a
proporción de gato, y pulido del disparo (fogonazo, trazador, retroceso,
marcador de impacto, poof de muerte, FOV y sacudida de cámara).

La revisión **v0.4** añade: la casa completa alrededor del dormitorio
(salón, pasillo y cocina en `scenes/casa.tscn`, con cuatro huecos de paso y
muebles), gato a escala 0.95, siete enemigos (en vez de cinco) y seis
ratones, disparo a distancia de los enemigos con puntería buena y mala
(`scripts/proyectil.gd`, export `precision` de cada enemigo), y SSAO con
radio amplio para que las esquinas de la casa se marquen.

La revisión **v0.5** añade: gato a escala 0.80 que cabe bajo la cama,
agachado de verdad (el cuerpo baja y las patas se pliegan; la hitbox sí se
apachurra), dos ventanas reales con cristal, marco y luz entrante,
pistola a tamaño de pata, ambiente PSX a plena resolución (niebla,
atardecer, filtro de dither/posterize/viñeta, motas de polvo), decorado 2D
procedural (cuadros pixel-art, zócalos, marcos, alfombra), destello en la
boca al disparar los enemigos y polvo al trepar.

La revisión **v0.6** arregla la iluminación (paleta fría gris-azulada estilo
survival-horror PSX: niebla neutra, atardecer suave, posterize 10 con más
dither para que no se separen los tonos) y hace el juego divertido: los
enemigos patrullan y ya no golpean cuerpo a cuerpo (solo disparan, con menos
daño y más pausa), los ratones huyen del jugador en marcha (caza de verdad),
y el HUD trae minimapa estilo radar + nombre del cuarto actual.

La revisión **v0.7** trae dos tipos de enemigos (rojos a distancia y
naranjas a cuchillo, con poco daño), GUI con estilo (paneles, barra por
segmentos con pulso a poca vida, minimapa con marco), shader mejorado
(grano animado y scanlines sutiles), noche de luna con AO más marcado,
baño nuevo, puertas anchas de 1.2 m, segunda pelota y cortinas que se
balancean solas.

La revisión **v0.8** es solo de iluminación y trae menú de desarrollador
en juego: **F1** cicla el preset de ambiente (Neutro, Luna, Atardecer,
Oscuro), **F2** cicla el modo de oclusión (SSAO, SSIL, todo, nada),
**F3** el filtro PSX y **F4** la niebla, con aviso en el HUD. Por defecto:
día neutro suave.

La revisión **v0.9** amplía el menú dev (**F1** con 6 presets, **F2** en modo
Todo, **F3** con 4 filtros apagado por defecto, **F4** con 3 nieblas,
avisos arriba-izquierda que duran medio segundo, **H** con la ayuda),
arregla el melee (no atraviesa muros ni alturas), **quita las ratas del
nivel** (los tests usan instancias propias) y arregla las repisas de las
ventanas (ya no se superponen).

El plan completo está en `Mew hit v0.2 plan.md`.

## Cómo ejecutar

- Abrir `project.godot` con **Godot 4.7.2** y pulsar F5 (o `F6` en la escena
  `scenes/test_level.tscn`, que es la escena principal).

No hace falta importar nada: la geometría son primitivas del motor
(`BoxMesh`, `CapsuleMesh`, `SphereMesh`, `PrismMesh`) y el audio son
`AudioStreamWAV` que genera `scripts/sonido.gd` al arrancar.

## Controles

| Tecla | Acción |
|---|---|
| W A S D o flechas | Moverse, relativo a la cámara |
| Ratón | Girar cámara (`ui_cancel` / Escape libera el ratón) |
| Espacio | Saltar, más alto si se mantiene |
| Shift | Correr |
| E | Dash (con enfriamiento, el arco de la mira marca la recarga) |
| Ctrl | Agachar (`crouch`) |
| Clic izquierdo | Disparar |
| Q o empujar la pared | Trepar (desde el suelo o en el aire) |
| F | Interactuar (acción reservada, sin uso en este prototipo) |
| R | Reiniciar al terminar (`reiniciar`) |
| F1 | Preset de ambiente (Neutro, Luna, Atardecer, Oscuro, Amanecer, Mediodía) |
| F2 | Modo de oclusión (SSAO, SSIL, todo, nada) |
| F3 | Filtro (nada, suave, fuerte, noir) |
| F4 | Niebla (suave, densa, nada) |
| H | Ayuda de controles |

La retícula cambia de color según lo que hay delante: **verde** si el rayo pega
en un blanco o un enemigo, **rojo** si hay un muro de por medio y **blanco** si
no pega en nada.

## Verificación

Tres comandos desde la carpeta del proyecto (el binario de consola sirve para
ver la salida en Windows):

```powershell
$GODOT = "C:\Users\Ed\Downloads\godot472\Godot_v4.7.2-stable_win64_console.exe"

# 0. Importar: solo al añadir o borrar archivos (genera .godot y los .uid)
& $GODOT --headless --path . --import

# 1. Compilar sin errores de script
& $GODOT --headless --path . --quit-after 200
echo $LASTEXITCODE        # → 0

# 2. Test estructural y de juego (57 puntos)
& $GODOT --headless --path . -s res://verificar.gd
echo $LASTEXITCODE        # → 0, y la última línea: VERIFICACION OK: 0 errores

# 3. JUGAR. El que importa y el que no se puede saltar.
```

Para cazar fugas de memoria al salir (leaks) se añade `--verbose`:

```powershell
& $GODOT --headless --path . --verbose -s res://verificar.gd
```

`verificar.gd` comprueba que todo compila, que la escena está bien montada, y
que el juego hace lo que dice el plan: moverse, saltar, correr, agacharse,
trepar, dash, cámara, disparo que hace daño, blancos que mueren, HUD, sonido
procedural, la IA de los enemigos (persigue, avisa, golpa, muere, dispara a
distancia con su puntería), contadores, victoria y derrota, partículas,
retícula con color, recarga del dash, cabeza del gato, barra de vida de los
enemigos, gato a escala compartido, dormitorio, pulido del disparo (fogonazo,
trazador, retroceso, marcador, poof, FOV y sacudida), la casa completa con
sus ventanas y SSAO, ambiente PSX (niebla, atardecer, filtro, motas),
decorado 2D y destello del enemigo, minimapa y cuarto actual en el HUD,
patrulla enemiga sin melee y ratones que huyen, tipos de enemigos, GUI con
estilo, baño, puertas anchas y decoración viva, y salida limpia sin leaks.

## Estructura

```
project.godot
README.md
verificar.gd
Mew hit v0.2 plan.md
Context.md
scenes/
  player.tscn
  gato.tscn
  pistol.tscn
  objetivo.tscn
  enemigo.tscn
  hud.tscn
  casa.tscn
  test_level.tscn
scripts/
  player.gd
  gato.gd
  pistol.gd
  objetivo.gd
  enemigo.gd
  proyectil.gd
  decorado.gd
  motas.gd
  psx_filtro.gdshader
  hud.gd
  sonido.gd
  partida.gd
  vida.gd
```

Godot añade al lado de cada script un `*.gd.uid`. Es normal, no se editan a
mano.

## Notas de implementación

- **Capas de colisión** (apartado 2bis del plan): 1 `escenario`, 2 `jugador`,
  4 `blancos`, 8 `enemigos`. El rayo de la pistola lleva máscara 13
  (escenario + blancos + enemigos) y solo se orienta desde la cámara: el
  disparo sale siempre del centro de la cámara.
- **Sonido**: 12 flujos WAV generados por código en `_ready` (disparo, paso,
  impacto, dash, trepar, maullido, maullido de daño, viento en bucle, los
  tres avisos de los enemigos y el tick del marcador de impacto). El viento
  arranca solo.
- **HUD**: todo con `_draw()`, sin escenas de UI ni `Control` anidados; el
  nodo raíz va con `mouse_filter = IGNORE` para no comerse el input.
- **En headless no hay GPU ni audio reales**: el test verifica el comportamiento
  lógico (emisores enchufados, reproductores, señales), no la simulación.
  Por eso el comando 3 de arriba no se puede saltar.
