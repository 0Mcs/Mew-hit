extends Control
class_name HUD

# HUD dibujado con _draw(), sin escenas de UI: reticula, barra de vida y
# destello al recibir dano. El Control va con mouse_filter = IGNORE para que
# nunca se coma el input del jugador (raton y teclas pasan al mundo 3D).
#
# La reticula se abre con UN Tween guardado en variable: si se crea uno nuevo
# por disparo y no se mata el anterior, se acumulan y la mira vibra (el bug de
# v0.1).

@export var radio_reticula: float = 9.0
@export var largo_punto: float = 7.0
@export var grosor_linea: float = 2.0
@export var apertura_disparo: float = 16.0
@export var duracion_apertura: float = 0.12
@export var ancho_barra: float = 240.0
@export var alto_barra: float = 14.0
@export var margen: float = 24.0
@export var duracion_destello: float = 0.35
@export var duracion_marcador: float = 0.22
@export var largo_marcador: float = 7.0
@export var duracion_pop: float = 0.18
@export var radio_pop: float = 22.0
@export var tamano_contador: float = 22.0
@export var tamano_titulo: float = 72.0
@export var tamano_subtitulo: float = 24.0
@export var minimapa: bool = true
@export var escala_minimapa: float = 13.0

const COLOR_RETICULA: Color = Color(1.0, 1.0, 1.0, 0.95)
const COLOR_ALCANZABLE: Color = Color(0.4, 1.0, 0.5, 0.98)
const COLOR_MURO: Color = Color(1.0, 0.35, 0.3, 0.95)
const COLOR_DASH: Color = Color(0.35, 0.85, 1.0, 0.95)
const COLOR_DASH_FONDO: Color = Color(0.0, 0.0, 0.0, 0.45)
const COLOR_CONTORNO: Color = Color(0.0, 0.0, 0.0, 0.6)
const COLOR_VIDA_ALTA: Color = Color(0.35, 0.85, 0.4)
const COLOR_VIDA_BAJA: Color = Color(0.9, 0.2, 0.15)
const COLOR_DESTELLO: Color = Color(0.85, 0.1, 0.1)
const COLOR_CONTADOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const COLOR_VICTORIA: Color = Color(0.4, 1.0, 0.55)
const COLOR_DERROTA: Color = Color(1.0, 0.3, 0.25)
const COLOR_MARCADOR: Color = Color(1.0, 0.92, 0.4, 1.0)
const COLOR_POP: Color = Color(1.0, 1.0, 1.0, 0.85)

# Estados de fin de partida que pinta la pantalla grande.
const FIN_JUGANDO: int = 0
const FIN_VICTORIA: int = 1
const FIN_DERROTA: int = 2

var apertura: float = 0.0
var prop_vida: float = 1.0
var destello_dano: float = 0.0
var marcador: float = 0.0
var pop: float = 0.0
var tween_apertura: Tween = null

var jugador: Node = null
var pistola: Node = null
var vida_nodo: Node = null
var partida: Node = null
var sonido: Node = null
var enemigos_abatidos: int = 0
var enemigos_totales: int = 0
var fin_partida: int = FIN_JUGANDO
var zona_actual: String = "Dormitorio"
var aviso_dev: String = ""
var tiempo_aviso_dev: float = 0.0
var mostrar_ayuda: bool = false

# Enfriamiento del dash, copiado del jugador cada frame para poder pintar
# el arco de recarga.
var enfriamiento_dash: float = 0.0
var cooldown_dash: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deferred: el HUD se prepara cuando ya esta toda la escena en el arbol,
	# asi da igual si va antes o despues del Jugador en test_level.tscn.
	call_deferred("conectar")


func conectar() -> void:
	jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	pistola = jugador.get_node_or_null("Pistola")
	if pistola == null:
		pistola = jugador.get_node_or_null("Modelo/Pistola")
	vida_nodo = jugador.get_node_or_null("Vida")

	if pistola != null and pistola.has_signal("disparo_realizado"):
		pistola.connect("disparo_realizado", _al_disparar)
	if pistola != null and pistola.has_signal("blanco_alcanzado"):
		pistola.connect("blanco_alcanzado", _al_danar_blanco)
	sonido = get_tree().get_first_node_in_group("sonido")
	if vida_nodo != null:
		if vida_nodo.has_signal("vida_cambiada"):
			vida_nodo.connect("vida_cambiada", _al_cambiar_vida)
		leer_vida()
	if jugador.has_signal("dano_recibido"):
		jugador.connect("dano_recibido", _al_recibir_dano)

	# Partida: se localiza subiendo por la jerarquia hasta encontrar un nodo
	# que emita enemigo_abatido. Sin grupos ni nombres: da igual como se
	# llame o en que escena se monte el HUD.
	partida = _buscar_partida()
	queue_redraw()


func _buscar_partida() -> Node:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return null
	var nivel: Node = get_parent()
	while nivel != null:
		for hijo: Node in nivel.get_children():
			if hijo.has_signal("enemigo_abatido") and hijo.has_method("reiniciar"):
				return hijo
		if nivel == arbol.root:
			break
		nivel = nivel.get_parent()
	return null


func leer_vida() -> void:
	if vida_nodo == null:
		return
	var maxima: int = int(vida_nodo.get("vida_maxima"))
	_al_cambiar_vida(int(vida_nodo.get("vida")), maxima)


func _process(delta: float) -> void:
	if destello_dano > 0.0:
		destello_dano = maxf(destello_dano - delta / maxf(duracion_destello, 0.01), 0.0)
	if tiempo_aviso_dev > 0.0:
		tiempo_aviso_dev -= delta
		if tiempo_aviso_dev <= 0.0:
			aviso_dev = ""
	if marcador > 0.0:
		marcador = maxf(marcador - delta / maxf(duracion_marcador, 0.01), 0.0)
	if pop > 0.0:
		pop = maxf(pop - delta / maxf(duracion_pop, 0.01), 0.0)
	_sincronizar_partida()
	_sincronizar_jugador()
	queue_redraw()


# La mira y el dash se leen de las referencias ya guardadas, igual que la
# partida: nada de buscar nodos frame a frame.
func _sincronizar_jugador() -> void:
	if jugador == null:
		return
	var enf: Variant = jugador.get("enfriamiento_dash")
	var cd: Variant = jugador.get("cooldown_dash")
	enfriamiento_dash = float(enf) if enf != null else 0.0
	cooldown_dash = float(cd) if cd != null else 1.0
	if jugador is Node3D:
		zona_actual = zona_de((jugador as Node3D).global_position)


# En que cuarto esta un punto del mundo. Rectangulos de los suelos tal cual
# estan montados en las escenas; fuera de todos ellos, "Patio".
func zona_de(pos: Vector3) -> String:
	if pos.x >= 2.59 and pos.x <= 7.31:
		if pos.z >= 1.09 and pos.z <= 4.51:
			return "Cocina"
		if pos.z >= -1.11 and pos.z <= 1.11:
			return "Pasillo"
	if pos.x >= -3.01 and pos.x <= 2.61:
		if pos.z >= 1.99 and pos.z <= 6.81:
			return "Salón"
		if pos.z >= -2.51 and pos.z <= 2.01:
			return "Dormitorio"
	return "Patio"


# Los contadores se leen de la referencia ya guardada, no se busca nada por
# nombre frame a frame: la partida manda y el HUD pinta.
func _sincronizar_partida() -> void:
	if partida == null:
		return
	enemigos_abatidos = int(partida.get("enemigos_abatidos"))
	enemigos_totales = int(partida.get("enemigos_totales"))
	if bool(partida.get("partida_perdida")):
		fin_partida = FIN_DERROTA
	elif bool(partida.get("partida_ganada")):
		fin_partida = FIN_VICTORIA


# ---------------------------------------------------------------------------
# Senales
# ---------------------------------------------------------------------------
func _al_disparar(impacto: bool) -> void:
	if tween_apertura != null and tween_apertura.is_valid():
		tween_apertura.kill()
	apertura = apertura_disparo
	tween_apertura = create_tween()
	tween_apertura.tween_property(self, "apertura", 0.0, duracion_apertura)
	tween_apertura.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if impacto:
		pop = 1.0


# Solo cuando el disparo ha danado a algo (senal de la pistola), no al
# pegar en un muro: la X es el "le has dado".
func _al_danar_blanco() -> void:
	marcador = 1.0
	if sonido != null and sonido.has_method("reproducir_marcador"):
		sonido.call("reproducir_marcador")


func _al_cambiar_vida(actual: int, maxima: int) -> void:
	if maxima <= 0:
		prop_vida = 0.0
		return
	prop_vida = clampf(float(actual) / float(maxima), 0.0, 1.0)


func _al_recibir_dano(_cantidad: int) -> void:
	destello_dano = 1.0


# Aviso del menu de desarrollador (F1-F4): texto breve arriba a la
# izquierda que se borra solo al medio segundo.
func mostrar_aviso(texto: String) -> void:
	aviso_dev = texto
	tiempo_aviso_dev = 0.5


# Ayuda de controles (tecla H): panel con todas las teclas.
func alternar_ayuda() -> void:
	mostrar_ayuda = not mostrar_ayuda


func _unhandled_key_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla: InputEventKey = evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_H:
		alternar_ayuda()


# ---------------------------------------------------------------------------
# Dibujo
# ---------------------------------------------------------------------------
func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_dibujar_destello()
	_dibujar_paneles()
	if fin_partida == FIN_JUGANDO:
		_dibujar_reticula(size * 0.5)
		_dibujar_dash(size * 0.5)
		_dibujar_pop(size * 0.5)
		_dibujar_marcador(size * 0.5)
		_dibujar_zona()
		_dibujar_minimapa()
		_dibujar_aviso_dev()
		_dibujar_ayuda()
	_dibujar_barra()
	_dibujar_contadores()
	_dibujar_fin()


# Verde: delante hay un blanco o un enemigo. Rojo: un muro se cruza.
# Blanco: el rayo no pega en nada. El HUD solo pinta, quien manda es la
# pistola.
func color_reticula() -> Color:
	if pistola != null:
		if bool(pistola.get("apuntando_blanco")):
			return COLOR_ALCANZABLE
		if bool(pistola.get("apuntando_muro")):
			return COLOR_MURO
	return COLOR_RETICULA


func _dibujar_reticula(centro: Vector2) -> void:
	var desde: float = radio_reticula + apertura
	var hasta: float = desde + largo_punto
	var color: Color = color_reticula()
	var direcciones: Array[Vector2] = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT
	]

	# Sombra primero, para que la mira se lea sobre cualquier fondo.
	for dir: Vector2 in direcciones:
		draw_line(centro + dir * desde, centro + dir * hasta, COLOR_CONTORNO, grosor_linea + 2.0, true)
	draw_circle(centro, grosor_linea + 1.5, COLOR_CONTORNO)

	for dir: Vector2 in direcciones:
		draw_line(centro + dir * desde, centro + dir * hasta, color, grosor_linea, true)
	draw_circle(centro, grosor_linea * 0.9, color)


# Enfriamiento del dash: un arco alrededor de la mira mientras se recarga.
# Cuando ya esta listo no se dibuja nada: lo que importa es ver la recarga.
func _dibujar_dash(centro: Vector2) -> void:
	if cooldown_dash <= 0.0 or enfriamiento_dash <= 0.0:
		return
	var fraccion: float = 1.0 - clampf(enfriamiento_dash / cooldown_dash, 0.0, 1.0)
	var radio: float = radio_reticula + 9.0
	var puntos: int = 36
	draw_arc(centro, radio, -PI * 0.5, PI * 1.5, puntos, COLOR_DASH_FONDO, grosor_linea + 2.0, true)
	if fraccion > 0.02:
		draw_arc(
			centro, radio, -PI * 0.5, -PI * 0.5 + TAU * fraccion,
			puntos, COLOR_DASH, grosor_linea + 1.0, true
		)


# Marca en X alrededor de la mira cuando el disparo ha danado a algo:
# se enciende con el golpe y se apaga sola con `duracion_marcador`.
func _dibujar_marcador(centro: Vector2) -> void:
	if marcador <= 0.0:
		return
	var diagonales: Array[Vector2] = [
		Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
		Vector2(-0.7071, -0.7071), Vector2(0.7071, -0.7071)
	]
	var desde: float = radio_reticula + apertura + 3.0
	var hasta: float = desde + largo_marcador
	var color: Color = COLOR_MARCADOR
	color.a = marcador
	for dir: Vector2 in diagonales:
		draw_line(
			centro + dir * desde, centro + dir * hasta,
			COLOR_CONTORNO, grosor_linea + 2.0, true
		)
	for dir: Vector2 in diagonales:
		draw_line(centro + dir * desde, centro + dir * hasta, color, grosor_linea, true)


# Anillo que se abre y se desvanece en la mira cuando el rayo pega en algo:
# el "pop" de que ha conectado, sea muro o blanco.
func _dibujar_pop(centro: Vector2) -> void:
	if pop <= 0.0:
		return
	var avance: float = 1.0 - pop
	var radio: float = lerpf(radio_reticula + 4.0, radio_pop, avance)
	var color: Color = COLOR_POP
	color.a = 0.75 * pop
	draw_arc(centro, radio, 0.0, TAU, 24, color, grosor_linea, true)


# Panel oscuro tras la columna derecha (contadores + minimapa) para que se
# lean sobre cualquier fondo. Solo pinta, no toca ningun dato.
func _dibujar_paneles() -> void:
	if enemigos_totales <= 0:
		return
	var lado: float = 150.0
	var caja: Rect2 = Rect2(
		Vector2(size.x - margen - lado - 8.0, margen - 8.0),
		Vector2(lado + 16.0, tamano_contador + 16.0 + lado + 16.0)
	)
	draw_rect(caja, Color(0.0, 0.0, 0.0, 0.45), true)
	draw_rect(caja, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)


func _dibujar_barra() -> void:
	var origen: Vector2 = Vector2(margen, size.y - margen - alto_barra)
	var caja: Rect2 = Rect2(origen, Vector2(ancho_barra, alto_barra))
	draw_rect(caja, Color(0.0, 0.0, 0.0, 0.55), true)

	# Barra por segmentos estilo PSX: 10 pastillas, la ultima parcial.
	var borde: float = 2.0
	var dentro: float = ancho_barra - borde * 2.0
	var segmentos: int = 10
	var paso: float = dentro / float(segmentos)
	for i: int in segmentos:
		var desde: float = float(i) / float(segmentos)
		if desde >= prop_vida:
			break
		var hasta: float = minf(float(i + 1) / float(segmentos), prop_vida)
		var ancho_seg: float = (hasta - desde) * dentro - 1.0
		if ancho_seg > 0.0:
			draw_rect(
				Rect2(
					origen + Vector2(borde + desde * dentro, borde),
					Vector2(ancho_seg, alto_barra - borde * 2.0)
				),
				color_vida(), true
			)
	# Con poca vida el marco palpita en rojo.
	var alfa_borde: float = 0.35
	if prop_vida < 0.3:
		alfa_borde = 0.5 + 0.4 * sin(float(Time.get_ticks_msec()) / 200.0)
		draw_rect(caja, Color(COLOR_VIDA_BAJA.r, COLOR_VIDA_BAJA.g, COLOR_VIDA_BAJA.b, alfa_borde), false, 2.0)
	else:
		draw_rect(caja, Color(1.0, 1.0, 1.0, alfa_borde), false, 2.0)


func color_vida() -> Color:
	return COLOR_VIDA_ALTA.lerp(COLOR_VIDA_BAJA, 1.0 - prop_vida)


func _dibujar_destello() -> void:
	if destello_dano <= 0.0:
		return
	var borde: float = maxf(size.x, size.y) * 0.03 * destello_dano
	var color: Color = COLOR_DESTELLO
	color.a = 0.55 * destello_dano
	draw_rect(Rect2(0.0, 0.0, size.x, borde), color, true)
	draw_rect(Rect2(0.0, size.y - borde, size.x, borde), color, true)
	draw_rect(Rect2(0.0, 0.0, borde, size.y), color, true)
	draw_rect(Rect2(size.x - borde, 0.0, borde, size.y), color, true)


# Nombre del cuarto actual, arriba en el centro, con sombra y subrayado.
func _dibujar_zona() -> void:
	var fuente: Font = get_theme_default_font()
	if fuente == null:
		return
	var texto: String = zona_actual.to_upper()
	var alto: int = int(tamano_subtitulo)
	draw_string(
		fuente, Vector2(0.0, margen + tamano_subtitulo) + Vector2(2.0, 2.0), texto,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, alto, Color(0.0, 0.0, 0.0, 0.75)
	)
	draw_string(
		fuente, Vector2(0.0, margen + tamano_subtitulo), texto,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, alto, COLOR_CONTADOR
	)
	var ancho_texto: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_CENTER, size.x, alto).x
	var centro_x: float = size.x * 0.5
	draw_rect(
		Rect2(centro_x - ancho_texto * 0.5, margen + tamano_subtitulo + 6.0, ancho_texto, 2.0),
		Color(1.0, 1.0, 1.0, 0.5), true
	)


# Minimapa estilo radar: los cuatro cuartos y los puntos del jugador
# (verde), enemigos (rojo) y ratones (blanco). Abajo de los contadores.
func _dibujar_minimapa() -> void:
	if not minimapa:
		return
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return
	var lado: float = 150.0
	var origen: Vector2 = Vector2(size.x - margen - lado, margen + tamano_contador + 16.0)
	draw_rect(Rect2(origen, Vector2(lado, lado)), Color(0.0, 0.0, 0.0, 0.55), true)
	draw_rect(Rect2(origen, Vector2(lado, lado)), Color(1.0, 1.0, 1.0, 0.5), false, 2.0)
	for cuarto: Rect2 in [
		Rect2(-3.0, -2.5, 5.6, 4.5), Rect2(-3.0, 2.0, 5.6, 4.8),
		Rect2(2.6, -1.1, 4.7, 2.2), Rect2(2.6, 1.1, 4.7, 3.4),
	]:
		var esquina: Vector2 = origen + Vector2(8.0, 8.0) + Vector2(
			(cuarto.position.x + 3.0) * escala_minimapa,
			(cuarto.position.y + 2.5) * escala_minimapa
		)
		draw_rect(
			Rect2(esquina, cuarto.size * escala_minimapa),
			Color(1.0, 1.0, 1.0, 0.3), false, 1.0
		)
	_punto_mapa(arbol, "jugador", Color(0.4, 1.0, 0.5), 3.0, origen)
	_punto_mapa(arbol, "enemigo", Color(1.0, 0.3, 0.25), 3.0, origen)
	_punto_mapa(arbol, "objetivo", Color(1.0, 1.0, 1.0), 2.0, origen)


func _punto_mapa(arbol: SceneTree, grupo: String, color: Color, radio: float, origen: Vector2) -> void:
	for nodo: Node in arbol.get_nodes_in_group(grupo):
		if not (nodo is Node3D):
			continue
		var mundo: Vector3 = (nodo as Node3D).global_position
		var punto: Vector2 = origen + Vector2(8.0, 8.0) + Vector2(
			(mundo.x + 3.0) * escala_minimapa,
			(mundo.z + 2.5) * escala_minimapa
		)
		draw_circle(punto, radio + 1.0, Color(0.0, 0.0, 0.0, 0.8))
		draw_circle(punto, radio, color)


# Aviso del menu dev: texto breve arriba a la izquierda con sombra.
func _dibujar_aviso_dev() -> void:
	if aviso_dev == "":
		return
	var fuente: Font = get_theme_default_font()
	if fuente == null:
		return
	var alto: int = int(tamano_subtitulo)
	var base: Vector2 = Vector2(margen, margen + tamano_subtitulo)
	draw_string(
		fuente, base + Vector2(2.0, 2.0), aviso_dev,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, Color(0.0, 0.0, 0.0, 0.75)
	)
	draw_string(
		fuente, base, aviso_dev,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, COLOR_CONTADOR
	)


# Panel de ayuda: todas las teclas del juego, con fondo.
func _dibujar_ayuda() -> void:
	if not mostrar_ayuda:
		return
	var fuente: Font = get_theme_default_font()
	if fuente == null:
		return
	var lineas: Array[String] = [
		"WASD / flechas: moverse", "Ratón: cámara", "Espacio: saltar",
		"Shift: correr", "E: dash", "Ctrl: agacharse",
		"Clic: disparar", "Q: trepar", "R: reiniciar",
		"F1: ambiente", "F2: oclusión", "F3: filtro", "F4: niebla",
	]
	var alto: int = int(tamano_contador)
	var origen: Vector2 = Vector2(margen, size.y * 0.5 - float(lineas.size() * (alto + 6)) * 0.5)
	var ancho: float = 300.0
	draw_rect(Rect2(origen - Vector2(8.0, 8.0), Vector2(ancho + 16.0, float(lineas.size() * (alto + 6)) + 16.0)), Color(0.0, 0.0, 0.0, 0.6), true)
	for i: int in lineas.size():
		var base: Vector2 = origen + Vector2(0.0, float(i * (alto + 6) + alto))
		draw_string(fuente, base + Vector2(2.0, 2.0), lineas[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, Color(0.0, 0.0, 0.0, 0.75))
		draw_string(fuente, base, lineas[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, COLOR_CONTADOR)


# Abatidos y restantes, arriba a la derecha, con sombra para que se lean
# sobre cualquier fondo.
func _dibujar_contadores() -> void:
	if enemigos_totales <= 0:
		return
	var fuente: Font = get_theme_default_font()
	if fuente == null:
		return
	var restantes: int = maxi(enemigos_totales - enemigos_abatidos, 0)
	var texto: String = "ABATIDOS %d   RESTANTES %d" % [enemigos_abatidos, restantes]
	var alto: int = int(tamano_contador)
	var ancho: float = fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto).x
	var base: Vector2 = Vector2(size.x - margen - ancho, margen + tamano_contador)
	draw_string(fuente, base + Vector2(2.0, 2.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(fuente, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, alto, COLOR_CONTADOR)


# Pantalla de victoria o derrota con el aviso de reinicio.
func _dibujar_fin() -> void:
	if fin_partida == FIN_JUGANDO:
		return
	var fuente: Font = get_theme_default_font()
	if fuente == null:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.5), true)

	var titulo: String = "VICTORIA" if fin_partida == FIN_VICTORIA else "DERROTA"
	var color: Color = COLOR_VICTORIA if fin_partida == FIN_VICTORIA else COLOR_DERROTA
	var centro: Vector2 = size * 0.5

	draw_string(
		fuente, Vector2(0.0, centro.y), titulo,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, int(tamano_titulo), Color(0.0, 0.0, 0.0, 0.7)
	)
	draw_string(
		fuente, Vector2(0.0, centro.y - 3.0), titulo,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, int(tamano_titulo), color
	)
	draw_string(
		fuente, Vector2(0.0, centro.y + tamano_titulo), "Pulsa R para reiniciar",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, int(tamano_subtitulo), Color(1.0, 1.0, 1.0, 0.9)
	)
