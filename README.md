# Mew Hit

Prototipo 3D en Godot 4.7.2: un gato en tercera persona con cámara de
hombro, disparo con raycast, trepar, dash, 7 enemigos (rojos a distancia,
naranjas a cuchillo), HUD dibujado a mano y sonido 100% procedural. Sin
assets externos: geometría con primitivas del motor y audio generado por
código. Versión actual: v0.9.

## Cómo ejecutar

Abrir `project.godot` con **Godot 4.7.2** y pulsar F5 (o `F6` en
`scenes/test_level.tscn`, la escena principal). No hace falta importar
nada. Los `*.uid` al lado de cada script los genera Godot, no se tocan.

## Controles

| Tecla | Acción |
|---|---|
| W A S D o flechas | Moverse, relativo a la cámara |
| Ratón | Girar cámara (`ui_cancel` / Escape libera el ratón) |
| Espacio | Saltar, más alto si se mantiene |
| Shift | Correr |
| E | Dash (el arco de la mira marca la recarga) |
| Ctrl | Agachar |
| Clic izquierdo | Disparar |
| Q o empujar la pared | Trepar (desde el suelo o en el aire) |
| F | Interactuar (reservada, sin uso) |
| R | Reiniciar al terminar |
| F1 | Preset de ambiente (Neutro, Luna, Atardecer, Oscuro, Amanecer, Mediodía) |
| F2 | Modo de oclusión (SSAO, SSIL, todo, nada) |
| F3 | Filtro (nada, suave, fuerte, noir) |
| F4 | Niebla (suave, densa, nada) |
| H | Ayuda de controles |

La retícula cambia de color: **verde** si el rayo pega en un blanco o un
enemigo, **rojo** si hay un muro de por medio y **blanco** si no pega.

## Verificación

Tres comandos desde la carpeta del proyecto:

```powershell
$GODOT = "C:\Users\Ed\Downloads\godot472\Godot_v4.7.2-stable_win64_console.exe"

# 1. Compilar sin errores de script
& $GODOT --headless --path . --quit-after 200
echo $LASTEXITCODE        # → 0

# 2. Test estructural y de juego (57 puntos)
& $GODOT --headless --path . -s res://verificar.gd
echo $LASTEXITCODE        # → 0, última línea: VERIFICACION OK: 0 errores
```

Con `--verbose` en el comando 2 se cazan fugas de memoria al salir.

`verificar.gd` comprueba que todo compila, que la escena está bien montada
y que el juego hace lo suyo: moverse, saltar, correr, agacharse, trepar,
dash, cámara, disparo, HUD, sonido, IA enemiga, victoria y derrota,
partículas, casa completa, ambiente y menú dev. Cada punto tiene su
mutación: si un comprobador no puede fallar, no sirve.

## Estructura

```
project.godot
README.md
verificar.gd
Context.md
scenes/
  player.tscn  gato.tscn  pistol.tscn  objetivo.tscn
  enemigo.tscn  hud.tscn  casa.tscn  test_level.tscn
scripts/
  player.gd  gato.gd  pistol.gd  objetivo.gd  enemigo.gd
  proyectil.gd  decorado.gd  motas.gd  dev_luces.gd
  psx_filtro.gdshader  hud.gd  sonido.gd  partida.gd  vida.gd
```

## Notas

- **Capas**: 1 `escenario`, 2 `jugador`, 4 `blancos`, 8 `enemigos`. El
  rayo de la pistola lleva máscara 13 y sale del centro de la cámara.
- **Sonido**: 12 flujos WAV generados en `_ready` (el viento arranca solo).
- **Headless no hay GPU ni audio reales**: el test verifica lógica
  (emisores, señales, contadores), no simulación. Por eso hay que jugar
  a mano lo que el test no puede ver.
