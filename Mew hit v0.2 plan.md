# Mew Hit v0.2 — Plan de desarrollo (revisión 2)

> Documento para ejecutar en OpenCode, pieza por pieza. Godot 4.7.2, GDScript, variables
> y comentarios en español. Sin LSPs. Todo procedural, sin assets externos.
> Cada fase es independiente y tiene su criterio de aceptación.
>
> **Revisión 2:** el proyecto se construye **desde cero** en esta carpeta
> (`Sesiones opencode/Mew hit v0.2/`). No se copia ningún archivo de v0.1; esa carpeta
> solo se consulta como referencia de lo que ya funcionaba. Se han corregido once puntos
> del plan original (ver apartado 0bis).

---

## 0. Contexto: qué salió mal en v0.1

v0.1 quedó congelada en `Sesiones opencode por hermes/Mew hit v0.1/`. Funciona: carga, el
gato se mueve, hay disparo, HUD, sonido y ciclo de partida. El problema no fue la falta de
funciones, fue el método de trabajo:

- Se ajustaron números de sensación a ciegas, sin ejecutar el juego, y se entregó como
  terminado. La verificación automática comprobaba que existieran nodos, no que el juego
  fuera usable.
- Se pidieron siete archivos de una sola vez. OpenCode se agotó, dejó carpetas vacías y
  hubo que repetir el trabajo en trozos.
- Cada cambio grande introdujo bugs nuevos: nodos duplicados, grupos de colisión
  ausentes, acciones de input con nombre distinto al configurado, y una capa de colisión
  que el raycast no detectaba. Ese último hacía el juego injugable y el test pasaba en
  verde.

**Reglas de trabajo para v0.2:**

1. Una pieza por tarea. Máximo 3 o 4 archivos por ejecución de OpenCode.
2. Cada pieza se juega antes de continuar. No encadenar sin probar.
3. Verificar es jugar. Un test en verde no dice si algo se siente bien.
4. Ninguna constante inventada. Todo valor que use el código se lee de la escena o se
   guarda en `_ready`. Nunca números que no correspondan a la geometría real. Los valores
   de sensación (velocidades, damping, amplitudes) van como `@export` para poder
   cazarlos ciegas desde el inspector.
5. Cada tarea se cierra con los tres comandos del apartado 13.

---

## 0bis. Correcciones de la revisión 2

Las once diferencias entre el plan original y lo que se ha comprobado en disco:

1. **Ruta.** El proyecto se crea en `Sesiones opencode/Mew hit v0.2/` (el directorio de
   trabajo de la sesión), no en `Sesiones opencode por hermes/`.
2. **Fase 1 sin copias.** Todas las tareas que decían "copiar desde v0.1" se sustituyen
   por "escribir". v0.1 solo sirve de consulta.
3. **Orden de la fase 1.** El plan original mandaba comprobar que el proyecto cargaba en
   la tarea 1.1, cuando `test_level.tscn` ya referenciaba un `player.tscn` que todavía no
   existía: habría fallado. Ahora el nivel se escribe después de que existan las escenas
   que instancia.
4. **Capas de colisión sin definir.** Tabla única, en el apartado 2bis. La máscara de la
   pistola en v0.1 se ampliaba en código con `mask |= 6`, que sumaba la capa 2 (el propio
   jugador). Desde cero: máscara fija en la escena, sin tocarla en el script.
5. **El disparo no salía de la cámara.** `pistol.gd` de v0.1 orientaba la *dirección* a
   la cámara pero el rayo seguía naciendo en el arma, así que la puntería no era la
   centro-cámara que prometía el apartado 5. Ahora se reubica el `RayCast3D` a la posición
   de la cámara antes de disparar.
6. **`partida.gd` de v0.1 ya no usa `node_exiting`** (solo queda un comentario en la línea
   89). El aviso del apartado 8 sobra: se escribe con señal propia `derribado`.
7. **`scripts/forma_gato.gd`** no existe y no lo referencia ninguna escena de v0.1 (solo
   el README). Se elimina de la estructura del apartado 11.
8. **`minf(agarre_suelo, 6.0)`** era una constante inventada en contra de la regla 4. Se
   sustituye por `agarre_tope`, exportado y ajustable.
9. **Acciones de input.** El apartado 2 decía "sin acciones nuevas", pero los controles
   del apartado 12 usan Ctrl y R, que en v0.1 se leían a mano con `KEY_CTRL`/`KEY_R`.
   Se añaden dos acciones: `crouch` (Ctrl) y `reiniciar` (R). `Escape` es `ui_cancel`,
   nativo de Godot, no hace falta declararla.
10. **Godot no está en PATH.** El binario está en
    `C:\Users\Ed\Downloads\godot472\Godot_v4.7.2-stable_win64_console.exe`. Los tres
    comandos del apartado 13 usan esa ruta completa y la versión `_console`, que en
    Windows escribe la salida en la terminal.
11. **`verificar.gd` de v0.1 pasaba en verde con cosas rotas.** Su punto 6 solo comprobaba
    que *existiera el archivo* `vida.gd`, no que el jugador expusiera el daño. El test
    nuevo comprueba que **todos los scripts compilan** y que cada comprobación puede
    fallar de verdad (apartado 13).

---

## 1. Objetivo de v0.2

Un prototipo cómodo de jugar. Ese es el requisito único y el más importante. Todo se
escribe desde cero con la capa de sensación como prioridad.

Éxito, evaluado jugando:

- El gato camina sin deslizarse, ni al girar, ni al frenar.
- Se puede caminar en las ocho direcciones con el ratón apuntando en cualquier ángulo.
- La cámara responde al ratón de inmediato, sin retardo ni temblor.
- Se puede disparar a un blanco sin tener que acertar con precisión quirúrgica.
- Agacharse y trepar se sienten controlados, no atascados.

Fuera de alcance en v0.2: multijugador, guardado, arte final, más de un arma.

---

## 2. Decisiones ya tomadas

No volver a debatirlas durante la ejecución:

- **Strafe.** El cuerpo del gato sigue a la cámara, nunca a la dirección de movimiento.
  Solo gira 180 grados cuando se corre hacia atrás. La pistola siempre apunta al yaw de
  la cámara, aunque el cuerpo no.
- **Velocidades.** Caminar 4.5 m/s, correr 8.5 m/s. Son valores bajos para un juego, pero
  con agarre al suelo se sienten mejor que 7 y 12.
- **Tercera persona, cámara de hombro.** El gato se ve desde atrás y por encima.
- **Acciones de input.** Las de v0.1 (`move_forward`, `move_back`, `move_left`,
  `move_right`, `jump`, `sprint`, `dash`, `climb`, `interact`, `fire`) más `crouch` y
  `reiniciar` (revisión 2, punto 9).
- **El jugador se escribe completo en un solo `player.gd`.** Sin componentes
  separados: un nodo, un script, una sola fuente de verdad para la física.

---

## 2bis. Capas de colisión (tabla única)

Fuente de verdad para `project.godot`, todas las escenas y `verificar.gd`:

| Capa | Nombre | Quién va ahí |
|---|---|---|
| 1 | `escenario` | Suelo, muros, plataformas, columnas |
| 2 | `jugador` | El `CharacterBody3D` del gato |
| 4 | `blancos` | `objetivo.tscn` |
| 8 | `enemigos` | `enemigo.tscn` |

Máscaras:

| Nodo | `collision_layer` | `collision_mask` | Motivo |
|---|---|---|---|
| Jugador | 2 | 9 (1+8) | Choca con el escenario y con los enemigos |
| Suelo/muros | 1 | 1 | Estáticos |
| Objetivo | 4 | 1 | Estático |
| Enemigo | 8 | 3 (1+2) | Choca con el escenario y con el jugador |
| `RayCast3D` de la pistola | — | 13 (1+4+8) | Escenario + blancos + enemigos, **nunca** al jugador |
| `RayCastPared` / `RayCastTecho` | — | 1 | Solo escenario |

Grupos de escena (independientes de las capas): `suelo`, `pared`, `jugador`, `enemigo`,
`objetivo`, `sonido`.

---

## 3. Fase 1 — El andamiaje y el gato

**Objetivo:** proyecto nuevo que carga, con un jugador escrito bien desde el principio.

**Tanda 1.1 — `project.godot` + `scenes/test_level.tscn` + `verificar.gd`**

- `project.godot`: nombre, escena principal `test_level.tscn`, ventana 1280x720, stretch
  `canvas_items`, gravedad 3D 28, las cuatro capas nombradas del apartado 2bis y el input
  map completo con las doce acciones.
- `test_level.tscn`: suelo, muros, rampa, túnel, plataformas, columnas (los mismos del
  parque de pruebas de v0.1, con los grupos `suelo` y `pared`), luz, entorno. **Sin
  jugador todavía**: la escena se completa en la tanda 1.4.
- `verificar.gd`: versión mínima. Carga la escena principal, comprueba grupos y que
  **todos los `.gd` del proyecto compilan**. Se amplía en cada tanda.

**Tanda 1.2 — `scenes/pistol.tscn` + `scripts/pistol.gd` + `scripts/vida.gd`**

- `pistol.tscn`: `Pistola` (Node3D) con malla y `RayCast3D` con `collision_mask = 13` y
  `target_position (0, 0, -100)`.
- `pistol.gd`: `disparar()` con cooldown, destello, señales `disparo_realizado` e
  `impacto`, sonido por grupo, búsqueda de `recibir_dano` en el colisionador y sus hijos.
- `vida.gd`: componente de vida en un nodo hijo (en Godot 4 un nodo admite un solo
  script), con señales `vida_cambiada` y `muerto`.

**Tanda 1.3 — `scenes/player.tscn`** *(el archivo más grande; solo él)*

Un solo archivo. Nodos y nombres exactos, porque el script los buscará por nombre:

- `Jugador` (CharacterBody3D), collision_layer 2, collision_mask 9
  - `CollisionShape3D` en (0, 0.9, 0), CapsuleShape3D radius 0.4, height 1.8
  - `Modelo` (Node3D) en (0,0,0)
    - `Cuerpo` (0, 0.62, 0), CapsuleMesh radius 0.32 height 1.05, escala Z 1.3
    - `Cabeza` (0, 0.85, -0.62), SphereMesh radius 0.28 height 0.56
    - `Hocico` (0, 0.78, -0.85), BoxMesh 0.2 x 0.14 x 0.18
    - `OrejaIzquierda` (-0.16, 1.15, -0.55), BoxMesh 0.12 x 0.22 x 0.08, rotación Z -0.25
    - `OrejaDerecha` (0.16, 1.15, -0.55), misma forma, rotación Z 0.25
    - `Cola` (0, 0.75, 0.62), BoxMesh 0.12 x 0.12 x 0.75
    - `Pata1` (-0.3, 0.25, -0.35), BoxMesh 0.14 x 0.5 x 0.14
    - `Pata2` (0.3, 0.25, -0.35), igual que Pata1
    - `Pata3` (-0.3, 0.25, 0.4), BoxMesh 0.16 x 0.5 x 0.16
    - `Pata4` (0.3, 0.25, 0.4), igual que Pata3
    - `OjoIzquierdo` (-0.16, 0.95, -0.83) y `OjoDerecho` (0.16, 0.95, -0.83), SphereMesh
      radius 0.06, material emisivo verde
  - `Pistola` (0.35, 0.65, -0.5), instancia de pistol.tscn
  - `SpringArm3D` en (0, 0.95, 0), spring_length 4.2, collision_mask 1
    - `Camara3D`, fov 75, current true
  - `RayCastPared` en (0, 0.9, 0), target_position (0, 0, -0.9) = `alcance_pared`
  - `RayCastTecho` en (0, 0.9, 0), target_position (0, 1.8, 0) = hasta la altura de pie
  - `Vida` (Node) con `vida.gd`

Materiales: cuerpo gris oscuro, cabeza un poco más clara, hocico y orejas rosados,
ojos verdes emisivos. Todos StandardMaterial3D, sin texturas.

**Nota importante:** la pistola va como hija de la raíz, no de SpringArm3D. En v0.1 se
puso bajo el brazo de cámara y quedó detrás del plano de la cámara, invisible. El raycast
se orienta a la cámara desde el script, no al revés.

**Tanda 1.4 — `scripts/player.gd`** *(se escribe en dos pasos, y se juega entre ellos)*

Primer paso: `_ready`, resolución de nodos, movimiento en el suelo, gravedad y salto.
Segundo paso: dash, trepar, agacharse y paso. Estructura obligatoria:

```gdscript
extends CharacterBody3D
class_name Jugador

const GRUPO_PARED: String = "pared"
const GRUPO_SUELO: String = "suelo"
```

**Resolución de nodos.** Una sola función auxiliar, usada por todos:

```gdscript
func buscar(nombre: String) -> Node:
	var n: Node = get_node_or_null(nombre)
	if n == null:
		n = get_node_or_null("Modelo/" + nombre)
	return n
```

Obligatorio: `colision`, `brazo_camara`, `pistola`, `raycast_pared`, `raycast_techo`.
Opcionales: `cuerpo`, `cabeza`, `cola`, `pata1` a `pata4`, `modelo`.

**Parámetros exportados** (los de sensación se cazar desde el inspector):

```
velocidad_caminar: float = 4.5
velocidad_correr: float = 8.5
aceleracion_suelo: float = 20.0
aceleracion_aire: float = 5.0
frenado_suelo: float = 24.0
frenado_aire: float = 5.0
agarre_suelo: float = 8.0
agarre_tope: float = 6.0        # revisión 2, punto 8
gravedad: float = 28.0
gravedad_caida: float = 42.0
altura_salto: float = 2.2
velocidad_salto_min: float = 5.0
coyote_time: float = 0.12
jump_buffer: float = 0.15
fuerza_dash: float = 20.0
duracion_dash: float = 0.18
cooldown_dash: float = 0.8
curva_salida_dash: float = 12.0
velocidad_trepar: float = 4.5
velocidad_trepar_lateral: float = 2.5
alcance_pared: float = 0.9
altura_agachado: float = 1.0
altura_de_pie: float = 1.8      # se sobrescribe en _ready con la altura real de la cápsula
velocidad_rotacion: float = 12.0
velocidad_rotar_atras: float = 18.0
```

**Estado interno:** `velocidad_vertical`, `direccion_deseada`, `en_suelo`, `trepando`,
`agachado`, `baja_actual`, `temporizador_coyote`, `buffer_salto`, `enfriamiento_dash`,
`tiempo_dash`, `dash_activo`, `saliendo_dash`, `direccion_dash`, `forma_capsula`,
`modelo_y_base`, `tiempo_paso`.

**`_ready()`:** `up_direction = Vector3.UP`. Duplicar `colision.shape` (los
`sub_resource` se comparten entre instancias) y guardar `forma_capsula` desde ahí.
`altura_de_pie = forma_capsula.height` — la altura de pie se **lee de la escena**, no se
escribe. `modelo_y_base` desde la posición real del nodo `Modelo`. Ratón capturado.

**`_movimiento(delta)`, en orden:**

1. `adelante` y `derecha` desde el `SpringArm3D`, con la Y a cero y normalizados.
2. `entrada` con `Input.get_vector`. Si la longitud supera 1, normalizar.
3. `direccion_deseada = adelante * entrada.y + derecha * entrada.x`, normalizada.
4. `objetivo_vel`: correr si `sprint`, caminar si no, cero si trepando.
5. `actual` = Vector3 con velocity.x y velocity.z en cero.
6. Si hay entrada: `actual = actual.move_toward(direccion_deseada * objetivo_vel, factor * delta)`
   con factor = aceleracion_suelo en suelo, aceleracion_aire en aire.
   Si no hay entrada: frenar con frenado_suelo en suelo, frenado_aire en aire.
7. **Agarre, solo en suelo y solo con entrada:** calcular la residual como
   `actual - direccion_deseada * objetivo_vel`, y reducirla con `move_toward` hacia cero a
   razón de `minf(agarre_suelo, agarre_tope) * delta`. Sumar la residual reducida a `actual`.
   Esto quita el deslizamiento lateral sin anular el movimiento de lado, que era
   exactamente el bug de v0.1.
8. Asignar velocity.x y velocity.z, salvo si trepando, en dash o saliendo del dash.

**Rotación del cuerpo (strafe):** el objetivo de giro es el yaw de la cámara; solo se le
suma PI si `direccion_deseada.dot(adelante) < -0.4`, es decir, si se corre de espaldas.
Se interpola con `lerp_angle` a `velocidad_rotacion`, o a `velocidad_rotar_atras` cuando
el giro es el de 180. La `Pistola` toma siempre `brazo_camara.rotation.y`: el arma apunta
a la cámara aunque el cuerpo no.

**`_gravedad_y_salto(delta)`:**

- Coyote time: en suelo, `temporizador_coyote = coyote_time`; si no, decrementar.
- Jump buffer: al pulsar jump, `buffer_salto = jump_buffer`; si no, decrementar.
- Si hay buffer y coyote y no trepando: `velocidad_vertical = sqrt(2 * gravedad * altura_salto)`.
  Consumir ambos.
- Gravedad: `gravedad_caida` bajando, `gravedad` subiendo. Anulada mientras trepa.
- Salto variable: al soltar jump, si sube, recortar a `velocidad_salto_min`.
- Aterrizaje: al tocar suelo con velocidad negativa, poner a cero.

**`_dash(delta)`:**

- Decrementar enfriamiento y tiempo de dash.
- Al pulsar dash con enfriamiento cero y sin trepar: activar, guardar `direccion_dash`
  (la deseada, o el adelante de la cámara si está quieto).
- Mientras dure: velocity.x y velocity.z forzados a `direccion_dash * fuerza_dash`.
- Al terminar: entrar en `saliendo_dash`, y mientras dure interpolar la velocidad hacia
  `direccion_deseada * objetivo_vel` con factor `clampf(curva_salida_dash * delta, 0, 1)`.
  Nunca cortar en seco. Este detalle es el que hace que el dash se sienta felino.

**`_trepar(delta)`:**

- Orientar `RayCastPared` hacia `-direccion_deseada` y forzar su actualización. Su
  origen y alcance ya están en la escena.
- Si colisiona con un nodo del grupo `pared`, y la normal tiene la Y casi cero: hay pared.
- Se trepa si se mantiene `climb` o si `direccion_deseada.dot(-normal) > 0.3`, y no se
  está en suelo o ya se trepaba.
- Al trepar: `velocidad_vertical = velocidad_trepar`, gravedad anulada. El desplazamiento
  horizontal es la proyección del movimiento deseado sobre el plano de la pared, más un
  empuje hacia la pared de `velocidad_trepar_lateral` para mantener el contacto. Se usan
  solo constantes existentes: ninguna nueva.
- Al soltar, desaparecer la pared o llegar al suelo: `trepando = false`.

**`_agacharse(delta)`:**

- Con la acción `crouch`.
- Cambiar `forma_capsula.height` entre los dos valores, y `colision.position.y` a
  `forma_capsula.height * 0.5`.
- Bajar `modelo.position.y = modelo_y_base - baja`, donde
  `baja = (altura_de_pie - forma_capsula.height) * 0.5`.
- Antes de levantarse, `RayCastTecho`: si el golpe llega a menos de la altura de pie
  medida desde el origen del rayo, no se levanta.

**`_paso(delta)`:** oscilación vertical de `modelo.position.y` de amplitud 0.02. La fase
avanza con los metros recorridos (`tiempo_paso += delta * velocidad_horizontal`) y se
multiplica por PI, de modo que un ciclo completo dura dos metros: pasos ligados a la
velocidad sin inventar una frecuencia. Solo en suelo y en movimiento.

**`_physics_process`:** suelo, gravedad y salto, trepar, dash, movimiento,
`velocity.y = velocidad_vertical`, `move_and_slide()`, suelo otra vez, agacharse, paso.

**Tanda 1.5 — Conectar y probar.** `test_level.tscn` gana su nodo `Jugador`, `Sonido` y
`Partida` cuando existan. Hasta entonces, prueba del movimiento con un nivel sin ellos.

**Aceptación de la fase 1:** se puede caminar en las ocho direcciones, el gato no gira al
caminar de lado, solo gira al correr hacia atrás, saltar es corto o largo según cuánto se
mantenga, el dash empuja y decae, trepar funciona con Q, agacharse hunde el gato en el
suelo. La cámara todavía no responde al ratón: eso es la fase 2.

---

## 4. Fase 2 — La cámara

Es la parte que más se quejó el usuario. Se hace sola, en un paso de `player.gd`.

### Tanda 2.1 — Cámara de hombro con retardo elástico

Añadir a `player.gd`:

```
sensibilidad_mouse: float = 0.0022
damping_camara: float = 9.0
angulo_max_vertical: float = 1.35
offset_hombro: float = 0.6
inclinacion_base: float = -0.12
zoom_por_defecto: float = 4.2
zoom_correr: float = 4.6
```

**El error que hay que evitar.** El damping se aplica al acumulado del ratón, no al
resultado. Si se suaviza la rotación final, la cámara queda pegada al ratón y además el
acumulado crece sin límite y produce saltos al hacer wrap de ángulos. Ese fue el
tambaleo de v0.1.

Implementación correcta:

```gdscript
# en _unhandled_input
yaw_deseado -= event.relative.x * sensibilidad_mouse
pitch_deseado -= event.relative.y * sensibilidad_mouse

# en _actualizar_camara, con factor = clampf(damping_camara * delta, 0.0, 1.0)
yaw_suave = lerp_angle(yaw_suave, yaw_deseado, factor)
pitch_suave = lerpf(pitch_suave, clampf(pitch_deseado, -angulo_max_vertical, angulo_max_vertical), factor)
brazo_camara.rotation.y = yaw_suave
brazo_camara.rotation.x = pitch_suave + inclinacion_base
brazo_camara.position.x = offset_hombro
```

- `yaw_deseado` puede crecer sin límite; eso está bien. Lo que se suaviza es
  `yaw_suave` hacia ese valor, y eso siempre converge.
- El `wrapf` no hace falta si se usa `lerp_angle`, que ya toma el camino corto.
- El zoom interpola con `lerpf` hacia zoom_correr o zoom_por_defecto, con el mismo factor
  de damping (ninguna constante nueva).
- El ratón se captura en `_ready` y `ui_cancel` lo suelta y lo vuelve a capturar.

**Sin roll, sin balanceo, sin sacudida.** Se añaden solo en la fase 4, cuando el
movimiento base ya se sienta bien. En v0.1 el roll dividía el cambio de ángulo por delta y
saturaba el tope en cada frame, lo que inclinaba la cámara constantemente.

**Aceptación:** al mover el ratón la cámara responde en el mismo frame, sin retardo
perceptible, sin temblor y sin inclinar. El gato mantiene la mirada de la cámara.

---

## 5. Fase 3 — Disparo y puntería

### Tanda 3.1 — Que el arma apunte a la cámara

El problema de v0.1: la pistola era hija del cuerpo del gato, así que apuntaba donde
corre, no donde mira. Y aunque se orientaba la dirección a la cámara, el rayo seguía
naciendo en el arma (revisión 2, punto 5).

En `pistol.gd`, dentro de `disparar()`, **antes** de `force_raycast_update()`:

```gdscript
var camara: Camera3D = get_viewport().get_camera_3d()
if camara != null:
	rayo.global_position = camara.global_position
	var destino := camara.global_position - camara.global_transform.basis.z * alcance
	rayo.target_position = rayo.to_local(destino)
```

El `RayCast3D` lleva `collision_mask = 13` fijo en la escena (capas 1+4+8). No se toca
en código: el jugador está en la capa 2 y no puede salirse un disparo contra sí mismo.

Disparar desde el centro de la cámara da puntería predecible a cualquier distancia. El
arma sigue ahí visualmente en el hombro del gato y apunta al yaw de la cámara.

### Tanda 3.2 — Feedback de disparo

- Crosshair que se expande al disparar y vuelve, con un Tween único guardado en variable y
  `kill()` del anterior. En v0.1 se creaba uno nuevo por disparo y se acumulaban, y eso
  producía la vibración de la mira.
- Destello del color del arma, 0.05 s.
- Retroceso: un pequeño empuje de pitch en la cámara, amplitud exportada y mínima.

---

## 6. Fase 4 — Feedback de sensación

Solo cuando las fases 1 a 3 se sienten bien al jugar. Nada de esto es esencial.

- **Sacudida al aterrizar.** Amplitud proporcional a la velocidad de impacto, máximo
  exportado, duración 0.15 s. Se aplica sobre la rotación base y se desvanece; nunca se
  restaura después, porque eso acumula error.
- **Roll de cámara al girar.** Calcular el cambio real de Y entre frames con `wrapf`,
  dividir por delta, limitar a un tope exportado. En v0.1 esto saturaba.
- **Balanceo de paso.** Oscilación vertical del modelo, ya incluida en la fase 1.
- **Sonido de pasos.** El script de sonido lo genera: temporizador ligado a la velocidad.
- **Partículas.** Polvo al aterrizar y al correr, y un rastro al dash. Con GPUParticles3D
  y un process material simple.

---

## 7. Fase 5 — Enemigos

Blancos estáticos que se destruyen no demuestran que el combate funcione. v0.2 necesita
algo que reaccione.

### Tanda 5.1 — Enemigo con IA mínima

`scripts/enemigo.gd`, extends CharacterBody3D, señal `derribado`:

- `vida`, `velocidad`, `alcance_deteccion`, `alcance_ataque`, `dano`, `cooldown_ataque`.
- Estados: `quieto`, `persiguiendo`, `atacando`.
- Persigue al jugador con `move_and_slide` y navegación simple por capas: si el
  `move_and_slide` queda bloqueado un tiempo, se desvía a un lado. Nada de pathfinding.
- Aviso antes de atacar: se detiene, brilla, y golpea. El jugador debe poder esquivarlo.
- Al morir, se hunde y desaparece, y emite `derribado`.

`scenes/enemigo.tscn`: cuerpo parecido al del gato pero de otro color, más pequeño,
`collision_layer = 8`, `collision_mask = 3`. El raycast del jugador lleva 13 y lo detecta.

Nivel: 5 enemigos, colocados de forma que no todos se vean a la vez.

---

## 8. Fase 6 — HUD y ciclo de partida

El HUD se escribe con lo que hace falta desde la fase 3, y aquí se completa:

- Contador de enemigos abatidos y de enemigos restantes.
- Vida del jugador en pantalla, con barra y color cuando baja.
- Aviso cuando el jugador recibe daño: destello rojo en el borde de la pantalla.
- Pantalla de victoria cuando se limpian todos, de derrota cuando llega a cero la vida, y
  reinicio con la acción `reiniciar` (R).

`scripts/partida.gd` se escribe desde cero: conecta la señal `derribado` de cada enemigo
y la señal `muerto` de `vida.gd`. Nada de `node_exiting`.

---

## 9. Fase 7 — Sonido y ambiente

`scripts/sonido.gd` genera por código, con `AudioStreamWAV` construido en `_ready`:
disparo, paso, maullido, impacto y dash. Añadir:

- Maullido cuando el gato lleva quieto un rato, y maullido al recibir daño.
- Sonido de enemigo al detectar al jugador y al golpear.
- Ambiente: viento suave en bucle, también generado por código.

---

## 10. Fase 8 — Pulido

Solo con todo lo anterior probado:

- Barra de vida sobre los enemigos al recibir daño.
- Retícula que cambia de color según si el blanco es alcanzable o hay muro de por medio.
- Indicador de recarga del dash cuando está en enfriamiento.
- Levantar la cabeza del gato para que mire hacia donde dispara.

---

## 11. Estructura final de archivos

```
project.godot
README.md
verificar.gd
scenes/
  player.tscn
  pistol.tscn
  objetivo.tscn
  enemigo.tscn
  hud.tscn
  test_level.tscn
scripts/
  player.gd
  pistol.gd
  objetivo.gd
  enemigo.gd
  hud.gd
  sonido.gd
  partida.gd
  vida.gd
```

Godot añade al lado de cada script un `*.gd.uid`. Es normal, no se editan a mano.

---

## 12. Controles

| Tecla | Acción |
|---|---|
| W A S D o flechas | Moverse, relativo a la cámara |
| Ratón | Girar cámara |
| Espacio | Saltar, más alto si se mantiene |
| Shift | Correr |
| E | Dash |
| Ctrl | Agachar (`crouch`) |
| Clic izquierdo | Disparar |
| Q o empujar la pared | Trepar |
| F | Interactuar |
| R | Reiniciar al terminar (`reiniciar`) |
| Escape | Liberar el ratón (`ui_cancel`) |

---

## 13. Verificación

Binario (revisión 2, punto 10):

```
$GODOT = "C:\Users\Ed\Downloads\godot472\Godot_v4.7.2-stable_win64_console.exe"
```

Tres comandos, después de cada tanda, ejecutados en la carpeta del proyecto:

```powershell
# 0. Importar: genera .godot y los .uid de los scripts nuevos (solo hace falta al
#    añadir o borrar archivos)
& $GODOT --headless --path . --import

# 1. Compilar sin errores de script
& $GODOT --headless --path . --quit-after 200
echo $LASTEXITCODE

# 2. Test estructural
& $GODOT --headless --path . -s res://verificar.gd
echo $LASTEXITCODE

# 3. JUGAR. Este es el que importa y el que no se puede saltar.
```

`verificar.gd` (escrito desde cero, ampliado en cada tanda) comprueba:

- **Que todos los `.gd` del proyecto compilan.** `load()` de cada script y
  `can_instantiate()`; un script con errores de parseo hace fallar el test. Este punto es
  el que garantiza que el comando 1 tiene dientes.
- La escena principal carga y se instancia.
- Todos los nodos que el script busca por nombre existen, **con la misma lógica que
  `buscar()`**: raíz y luego `Modelo/`. Si los dos caminos no coinciden, el test falla.
- La pistola tiene `disparar()`, su `RayCast3D`, y que su `collision_mask` es 13.
- El jugador está en la capa 2 con máscara 9; el enemigo en la 8 con máscara 3.
- Los grupos `suelo` y `pared` existen en el nivel.
- El HUD tiene su retícula (`color_reticula`, `_dibujar_dash`), la barra de
  vida con `prop_vida`, los contadores y las pantallas de fin. (En v0.1 esto
  era un `ProgressBar` del árbol de UI; el HUD de v0.2 se dibuja entero con
  `_draw()`, así que no hay nodos de UI que comprobar.)
- El sonido tiene `reproducir_disparo()`.
- El nodo `Vida` existe, su script es `vida.gd` y expone `recibir_dano`.

Un punto importante sobre el test: **debe fallar si algo está mal de verdad.** El de v0.1
pasaba en verde con el juego injugable porque solo miraba existencia de nodos y porque su
punto 6 comprobaba que un archivo existiera, no que funcionara. Si un comprobador no
puede fallar, no sirve.

---

## 14. Secuencia de tandas

| Tanda | Archivos | Se cierra con |
|---|---|---|
| 0 | `Mew hit v0.2 plan.md` | — |
| 1 | `project.godot`, `test_level.tscn`, `verificar.gd` | comandos 1 y 2 |
| 2 | `pistol.tscn`, `pistol.gd`, `vida.gd` | comandos 1 y 2 |
| 3 | `player.tscn` | comandos 1 y 2 |
| 4 | `player.gd` (movimiento, gravedad, salto) + `verificar.gd` | comandos + **jugar** |
| 5 | `player.gd` (dash, trepar, agacharse, paso) | comandos + **jugar** |
| 6 | `player.gd` (cámara) | comandos + **jugar** |
| 7 | `objetivo.tscn`, `objetivo.gd`, `pistol.gd` (puntería + feedback) | comandos + **jugar** |
| 8 | `hud.tscn`, `hud.gd` | comandos + **jugar** |
| 9 | `sonido.gd`, `partida.gd` | comandos + **jugar** |
| 10 | `enemigo.tscn`, `enemigo.gd`, `test_level.tscn` (5 enemigos) | comandos + **jugar** |
| 11 | `hud.tscn`, `hud.gd`, `partida.gd` (contadores, daño, victoria/derrota) | comandos + **jugar** |
| 12 | `player.gd` (fase 4) | comandos + **jugar** |
| 13 | `sonido.gd` (maullidos, viento) | comandos + **jugar** |
| 14 | pulido, `README.md`, `verificar.gd` final | comandos + **jugar** |

Ninguna tanda empieza con el juego sin jugar la anterior. Ninguna tanda pasa de cuatro
archivos.

---

## 15. Después de v0.2

Lo que quedará fuera y que los números del plan de juego marcan como pendiente:

- Multijugador, que es el ADN del proyecto.
- Modos de juego más allá de uno.
- Historia.
- Modelado y animación final.

Nada de eso se empieza antes de que el movimiento sea cómodo. Un prototipo con la
sensación correcta y geometría placeholder vale más que un juego completo que se siente
mal.

---

## 16. Notas de la ejecución de v0.2

Apuntes que han salido al construir el prototipo y que hay que tener presentes
antes de tocar nada más.

### Geometría placeholder del gato

Ojos, hocico, orejas y patas son cubos sueltos colocados a ojo en
`scenes/gato.tscn` (en v0.3 el modelo es compartido con los enemigos y las
piezas ya cuelgan de `Cabeza` en la propia escena). Al ajustarlos hay dos
cosas que se olvidan fácil:

- **La cabeza es un conjunto, no una bola.** Las piezas tienen que quedar
  colgadas de `Cabeza` en la escena (o quedar en la lista
  `_colgar_piezas_cabeza()` de `player.gd`, que las cuelga con
  `reparent(..., true)`, conservando la posición global) para que la cabeza
  siga la mirada entera.
- El hocico, respecto a la cabeza, va en `(0, -0.03, -0.09)`: el punto 38 del
  test comprueba esa posición relativa. Si se mueve la geometría, se actualiza
  ese número en `verificar.gd`.

Patas y orejas son solo volumen: sin esqueleto ni animación, así que las
variaciones de proporción no afectan a nada más.

### Trepar desde el suelo

Tal como está implementado en `_trepar()`:

- Con la acción `climb` (Q) **se puede empezar a trepar desde el suelo**: basta
  con estar delante de la pared y empujar.
- **Empujar la pared** (caminar contra ella) solo mantiene la trepada en el
  aire; en el suelo no arranca por sí solo, para que no se trepe nada más con
  andar puesto contra un muro.
- Al trepar se anula la gravedad y el gato sube con `velocidad_trepar`,
  empujando un poco hacia la pared (`velocidad_trepar_lateral`) para no
  soltarse.

Si se quiere que empujar la pared arranque la trepada también desde el suelo,
es cambiar la condición de arranque de `_trepar()`; el test 18 sube a ~2.25 m
y vale para las dos variantes.
