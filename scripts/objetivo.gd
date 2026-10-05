extends CharacterBody3D
class_name Objetivo

# Blanco de practica: capa 4, grupo "objetivo". El disparo de la pistola busca
# quien tenga recibir_dano() y lo encuentra aqui. Las cifras viven en el nodo
# hijo Vida (el mismo componente que usa el jugador); este script se queda con
# el feedback: destello al recibir dano, color segun la vida, muerte y
# reaparicion. Y desde v0.6 el raton HUYE del jugador si se acerca mucho: es
# una caza, no una diana quieta.

signal impacto_recibido(cantidad: int)
signal destruido

@export var velocidad_giro: float = 0.9
@export var tiempo_reaparicion: float = 3.0
@export var duracion_destello: float = 0.12

# Huida: si el jugador se acerca a menos de esto, el raton corre al lado
# contrario. El radio es corto a proposito: los tests colocan el blanco a
# 1.0 m de la camara y no deben espantarlo.
@export var radio_huida: float = 0.8
@export var velocidad_huida: float = 2.5
@export var gravedad: float = 20.0

const COLOR_IMPACTO: Color = Color(6.0, 6.0, 6.0)
const COLOR_MUERTO: Color = Color(0.15, 0.15, 0.15)
const COLOR_LLENDO: Color = Color(1.0, 0.15, 0.15)
# Nunca escala 0 exacto: una base con determinante 0 hace fallar al motor al
# invertirla. 0.001 se ve igual de desaparecido.
const ESCALA_OCULTA: Vector3 = Vector3(0.001, 0.001, 0.001)

@onready var malla: MeshInstance3D = get_node_or_null("Malla")

var vida_nodo: Node = null
var muerto: bool = false
var capa_original: int = 4
var mascara_original: int = 1
var material_blanco: StandardMaterial3D = null
var color_base: Color = Color.WHITE
var color_vida: Color = Color.WHITE
var tween_destello: Tween = null
var tween_muerte: Tween = null
var reaparicion_pendiente: bool = false


func _ready() -> void:
	capa_original = collision_layer
	mascara_original = collision_mask
	vida_nodo = get_node_or_null("Vida")
	if vida_nodo != null:
		if vida_nodo.has_signal("vida_cambiada"):
			vida_nodo.connect("vida_cambiada", _al_cambiar_vida)
		if vida_nodo.has_signal("muerto"):
			vida_nodo.connect("muerto", _morir)
	_preparar_material()


func _process(delta: float) -> void:
	if muerto or velocidad_giro == 0.0:
		return
	rotation.y = wrapf(rotation.y + velocidad_giro * delta, -PI, PI)


func _physics_process(delta: float) -> void:
	if muerto:
		return
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y -= gravedad * delta
	_huir()
	move_and_slide()


# Si el jugador se acerca EN MOVIMIENTO, correr al lado contrario. Quieto
# o lejos, el raton ni se inmuta (acechar funciona, acosar andando no: el
# raton es mas rapido que el paso). Muerto, quieto.
func _huir() -> void:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return
	var jugador: Node = arbol.get_first_node_in_group("jugador")
	if jugador == null or not (jugador is Node3D):
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var plano: Vector3 = global_position - (jugador as Node3D).global_position
	plano.y = 0.0
	var corre: bool = false
	if jugador is CharacterBody3D:
		var paso: Vector3 = (jugador as CharacterBody3D).velocity
		corre = Vector2(paso.x, paso.z).length() > 1.0
	if corre and plano.length() < radio_huida and plano.length() > 0.001:
		plano = plano.normalized()
		velocity.x = plano.x * velocidad_huida
		velocity.z = plano.z * velocidad_huida
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func recibir_dano(cantidad: int) -> void:
	if muerto:
		return
	if vida_nodo != null and vida_nodo.has_method("recibir_dano"):
		vida_nodo.call("recibir_dano", cantidad)
	impacto_recibido.emit(cantidad)
	_destello()


func vida_actual() -> int:
	if vida_nodo == null:
		return 0
	var valor: Variant = vida_nodo.get("vida")
	return valor as int if valor is int else 0


# ---------------------------------------------------------------------------
# Feedback visual
# ---------------------------------------------------------------------------
func _preparar_material() -> void:
	if malla == null:
		return
	var base: Material = malla.get_active_material(0)
	if base is StandardMaterial3D:
		material_blanco = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	if material_blanco == null:
		material_blanco = StandardMaterial3D.new()
	color_base = material_blanco.albedo_color
	color_vida = color_base
	malla.material_override = material_blanco

	# Toda la pieza destella con el mismo material: cabeza, orejas, cola...
	_tintar_ramas(self)


func _tintar_ramas(nodo: Node) -> void:
	for hijo: Node in nodo.get_children():
		if hijo.get_script() != null:
			continue
		if hijo is MeshInstance3D:
			(hijo as MeshInstance3D).material_override = material_blanco
		_tintar_ramas(hijo)


func _al_cambiar_vida(actual: int, maxima: int) -> void:
	if material_blanco == null or maxima <= 0:
		return
	var proporcion: float = clampf(float(actual) / float(maxima), 0.0, 1.0)
	color_vida = color_base.lerp(COLOR_LLENDO, 1.0 - proporcion)
	material_blanco.albedo_color = color_vida


func _destello() -> void:
	if material_blanco == null:
		return
	if tween_destello != null and tween_destello.is_valid():
		tween_destello.kill()
	material_blanco.albedo_color = COLOR_IMPACTO
	tween_destello = create_tween()
	tween_destello.tween_property(material_blanco, "albedo_color", color_vida, duracion_destello)


# ---------------------------------------------------------------------------
# Muerte y reaparicion
# ---------------------------------------------------------------------------
func _morir() -> void:
	if muerto:
		return
	muerto = true
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if tween_destello != null and tween_destello.is_valid():
		tween_destello.kill()
	if tween_muerte != null and tween_muerte.is_valid():
		tween_muerte.kill()
	if material_blanco != null:
		material_blanco.albedo_color = COLOR_MUERTO
	tween_muerte = create_tween()
	tween_muerte.tween_property(self, "scale", ESCALA_OCULTA, 0.3)
	tween_muerte.tween_callback(_programar_reaparicion)
	destruido.emit()


func _programar_reaparicion() -> void:
	if tiempo_reaparicion <= 0.0 or reaparicion_pendiente:
		return
	reaparicion_pendiente = true
	await get_tree().create_timer(tiempo_reaparicion).timeout
	reaparicion_pendiente = false
	if is_inside_tree() and muerto:
		reiniciar()


func reiniciar() -> void:
	muerto = false
	scale = Vector3.ONE
	set_deferred("collision_layer", capa_original)
	set_deferred("collision_mask", mascara_original)
	if vida_nodo != null and vida_nodo.has_method("reiniciar"):
		vida_nodo.call("reiniciar")
	if material_blanco != null:
		material_blanco.albedo_color = color_vida
