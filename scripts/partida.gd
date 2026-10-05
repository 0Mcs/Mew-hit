extends Node
class_name Partida

# El ciclo de partida. Escucha al mundo: la vida del jugador, los blancos
# destruidos y los enemigos abatidos, y manda reiniciar con la accion R.
# Nada de node_exiting ni de buscar nodos por nombre en _process: todo va
# conectado por senales al entrar en el arbol.
#
# El HUD solo mira estas senales y estos contadores; la logica vive aqui.

signal objetivo_destruido(destruidos: int)
signal enemigo_abatido(abatidos: int, restantes: int)
signal jugador_muerto
signal victoria
signal derrota
signal reiniciada

@export var accion_reiniciar: StringName = &"reiniciar"

var jugador: Node = null
var vida_jugador: Node = null
var enemigos_abatidos: int = 0
var enemigos_totales: int = 0
var blancos_destruidos: int = 0
var partida_perdida: bool = false
var partida_ganada: bool = false


func _ready() -> void:
	call_deferred("conectar")


func conectar() -> void:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return

	jugador = arbol.get_first_node_in_group("jugador")
	if jugador != null:
		vida_jugador = jugador.get_node_or_null("Vida")
		if vida_jugador != null and vida_jugador.has_signal("muerto"):
			vida_jugador.connect("muerto", _al_morir_jugador)

	for blanco: Node in arbol.get_nodes_in_group("objetivo"):
		_conectar_senal(blanco, "destruido", _al_destruir_blanco)

	_contar_enemigos(arbol)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(accion_reiniciar):
		reiniciar()


func reiniciar() -> void:
	var arbol: SceneTree = get_tree()
	if arbol == null or arbol.current_scene == null:
		return
	arbol.reload_current_scene()


# ---------------------------------------------------------------------------
# Contadores
# ---------------------------------------------------------------------------
func faltan_enemigos() -> int:
	return maxi(enemigos_totales - enemigos_abatidos, 0)


func _contar_enemigos(arbol: SceneTree) -> void:
	var lista: Array[Node] = arbol.get_nodes_in_group("enemigo")
	enemigos_totales = lista.size()
	enemigos_abatidos = 0
	for enemigo: Node in lista:
		_conectar_senal(enemigo, "derribado", _al_derribar)


func _al_destruir_blanco() -> void:
	blancos_destruidos += 1
	objetivo_destruido.emit(blancos_destruidos)


func _al_derribar() -> void:
	enemigos_abatidos += 1
	enemigo_abatido.emit(enemigos_abatidos, faltan_enemigos())
	if enemigos_totales > 0 and enemigos_abatidos >= enemigos_totales and not partida_ganada:
		partida_ganada = true
		victoria.emit()


func _al_morir_jugador() -> void:
	if partida_perdida:
		return
	partida_perdida = true
	jugador_muerto.emit()
	derrota.emit()


func _conectar_senal(nodo: Node, senal: String, destino: Callable) -> void:
	if nodo == null or not nodo.has_signal(senal):
		return
	if not nodo.is_connected(senal, destino):
		nodo.connect(senal, destino)
