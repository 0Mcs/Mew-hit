extends Node3D

# Arma. El modelo se ve en el hombro del gato, pero el disparo sale SIEMPRE
# del centro de la camara: eso es lo que da punteria predecible a cualquier
# distancia. La camara se localiza en cada disparo, nunca por referencia
# guardada, porque la camara puede cambiar al recargar la escena.

signal disparo_realizado(impacto: bool)
signal impacto(posicion: Vector3, normal: Vector3)
signal blanco_alcanzado

@export var cooldown_disparo: float = 0.25
@export var alcance: float = 100.0
@export var dano: int = 25
@export var duracion_destello: float = 0.05

const COLOR_DESTELLO: Color = Color(4.0, 4.0, 4.0)

@onready var malla: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var rayo: RayCast3D = get_node_or_null("RayCast3D")
@onready var fogonazo: MeshInstance3D = get_node_or_null("Fogonazo")
@onready var luz_fogonazo: OmniLight3D = get_node_or_null("LuzFogonazo")
@onready var trazador: MeshInstance3D = get_node_or_null("Trazador")

var enfriamiento: float = 0.0
var material_pistola: StandardMaterial3D = null
var material_trazador: StandardMaterial3D = null
var color_original: Color = Color.WHITE
var tween_destello: Tween = null
var tween_fogonazo: Tween = null
var tween_trazador: Tween = null
var tween_arma: Tween = null
var posicion_base: Vector3 = Vector3.ZERO
var duracion_trazador: float = 0.14
var disparos: int = 0

# Lo que ve la mira, para pintar la reticula del HUD: verde si el rayo pega
# en algo que se puede romper, rojo si hay un muro de por medio, y nada si
# el rayo se va al aire. Se actualiza cada frame, no solo al disparar.
var apuntando_blanco: bool = false
var apuntando_muro: bool = false


func _ready() -> void:
	posicion_base = position
	if malla != null:
		var material: Material = malla.get_active_material(0)
		if material is StandardMaterial3D:
			material_pistola = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		elif material == null:
			material_pistola = StandardMaterial3D.new()
		if material_pistola != null:
			color_original = material_pistola.albedo_color
			malla.material_override = material_pistola
	if trazador != null:
		var mat_traz: Material = trazador.get_active_material(0)
		if mat_traz is StandardMaterial3D:
			material_trazador = (mat_traz as StandardMaterial3D).duplicate() as StandardMaterial3D
			trazador.material_override = material_trazador

	# La mascara de colision (13 = escenario + blancos + enemigos) vive en la
	# escena y aqui NO se toca: si alguien la peta, verificar.gd la pillara.
	if rayo != null:
		rayo.target_position = Vector3(0.0, 0.0, -alcance)


func _process(delta: float) -> void:
	enfriamiento = maxf(enfriamiento - delta, 0.0)
	_actualizar_mira()


# El rayo se orienta desde la camara tambien fuera del disparo, para que la
# reticula sepa si delante hay muro o blanco. La evaluacion va aparte para
# que verificar.gd pueda apuntar el rayo a mano y probar las dos ramas.
func _actualizar_mira() -> void:
	if rayo == null:
		apuntando_blanco = false
		apuntando_muro = false
		return
	_orientar_hacia_camara()
	_evaluar_mira()


func _evaluar_mira() -> void:
	if rayo == null:
		apuntando_blanco = false
		apuntando_muro = false
		return
	rayo.force_raycast_update()
	if not rayo.is_colliding():
		apuntando_blanco = false
		apuntando_muro = false
		return
	apuntando_blanco = _buscar_recibir_dano(rayo.get_collider()) != null
	apuntando_muro = not apuntando_blanco


func puede_disparar() -> bool:
	return enfriamiento <= 0.0 and rayo != null


func disparar() -> void:
	if not puede_disparar():
		return

	_orientar_hacia_camara()
	rayo.force_raycast_update()

	var golpeo: bool = rayo.is_colliding()
	var punto: Vector3 = rayo.get_collision_point() if golpeo else Vector3.ZERO
	var normal: Vector3 = rayo.get_collision_normal() if golpeo else Vector3.ZERO

	_reproducir_sonido(golpeo, punto)

	if golpeo:
		var colisionador: Object = rayo.get_collider()
		var objetivo: Node = _buscar_recibir_dano(colisionador)
		if objetivo != null:
			objetivo.call("recibir_dano", dano)
			blanco_alcanzado.emit()
		impacto.emit(punto, normal)
		_chispa(punto, normal)

	_destello()
	_fogonazo()
	_retroceso_arma()
	if golpeo:
		_trazador(punto)
	enfriamiento = cooldown_disparo
	disparos += 1
	disparo_realizado.emit(golpeo)


# El rayo nace en la camara y va paralelo a su eje -Z: disparo centro-camara.
func _orientar_hacia_camara() -> void:
	if rayo == null:
		return
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return
	var origen: Vector3 = camara.global_position
	var destino: Vector3 = origen - camara.global_transform.basis.z * alcance
	rayo.global_position = origen
	rayo.target_position = rayo.to_local(destino)


# Un nodo solo admite un script, asi que el dano puede llegar a un hijo
# (el jugador tiene el nodo "Vida"). Buscamos quien sepa recibirlo.
func _buscar_recibir_dano(colisionador: Object) -> Node:
	if colisionador is Node:
		var nodo: Node = colisionador as Node
		if nodo.has_method("recibir_dano"):
			return nodo
		for hijo: Node in nodo.get_children():
			if hijo.has_method("recibir_dano"):
				return hijo
	return null


func _obtener_sonido() -> Node:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return null
	var candidatos: Array[Node] = arbol.get_nodes_in_group("sonido")
	if candidatos.size() > 0:
		return candidatos[0]
	return find_child("Sonido", true, false)


func _reproducir_sonido(golpeo: bool, punto: Vector3) -> void:
	var sonido: Node = _obtener_sonido()
	if sonido == null:
		return
	if sonido.has_method("reproducir_disparo"):
		sonido.call("reproducir_disparo")
	if golpeo and sonido.has_method("reproducir_impacto"):
		sonido.call("reproducir_impacto", punto)


func _destello() -> void:
	if material_pistola == null:
		return
	if tween_destello != null and tween_destello.is_valid():
		tween_destello.kill()
	tween_destello = create_tween()
	tween_destello.tween_property(material_pistola, "albedo_color", COLOR_DESTELLO, duracion_destello)
	tween_destello.tween_property(material_pistola, "albedo_color", color_original, duracion_destello)


# Fogonazo en la boca del canon: se enciende con el tiro y se apaga solo.
func _fogonazo() -> void:
	if fogonazo != null:
		fogonazo.visible = true
	if luz_fogonazo != null:
		luz_fogonazo.visible = true
	if tween_fogonazo != null and tween_fogonazo.is_valid():
		tween_fogonazo.kill()
	tween_fogonazo = create_tween()
	tween_fogonazo.tween_interval(duracion_destello * 2.0)
	tween_fogonazo.tween_callback(_apagar_fogonazo)


func _apagar_fogonazo() -> void:
	if fogonazo != null:
		fogonazo.visible = false
	if luz_fogonazo != null:
		luz_fogonazo.visible = false


# Trazador del canon al punto de impacto: un fino resplandor que se
# desvanece. Solo pega impacto; al aire no hay nada que trazar.
func _trazador(punto: Vector3) -> void:
	if trazador == null:
		return
	var origen: Vector3 = to_global(Vector3(0.0, 0.015, -0.20))
	var distancia: float = origen.distance_to(punto)
	if distancia < 0.1:
		return
	if material_trazador != null:
		material_trazador.albedo_color.a = 1.0
		material_trazador.emission_energy_multiplier = 5.0
	trazador.global_position = origen.lerp(punto, 0.5)
	trazador.look_at(punto)
	trazador.scale = Vector3(1.0, 1.0, distancia)
	trazador.visible = true
	if tween_trazador != null and tween_trazador.is_valid():
		tween_trazador.kill()
	if material_trazador != null:
		tween_trazador = create_tween().set_parallel(true)
		tween_trazador.tween_property(material_trazador, "albedo_color:a", 0.0, duracion_trazador)
		tween_trazador.tween_property(
			material_trazador, "emission_energy_multiplier", 0.0, duracion_trazador
		)
		tween_trazador.chain().tween_callback(_ocultar_trazador)


func _ocultar_trazador() -> void:
	if trazador != null:
		trazador.visible = false


# El arma recula un pelin hacia atras y vuelve: feedback visual del tiro.
func _retroceso_arma() -> void:
	if tween_arma != null and tween_arma.is_valid():
		tween_arma.kill()
	position = posicion_base
	tween_arma = create_tween()
	tween_arma.tween_property(self, "position", posicion_base + Vector3(0.0, 0.0, 0.03), 0.03)
	tween_arma.tween_property(self, "position", posicion_base, 0.08)


# Chispa en el punto de impacto: se enciende, encoge y se borra. Sirve para ver
# donde ha ido el disparo cuando el blanco esta lejos.
func _chispa(punto: Vector3, normal: Vector3) -> void:
	var contenedor: Node = get_tree().current_scene
	if contenedor == null and get_parent() != null:
		contenedor = get_parent().get_parent()
	if contenedor == null:
		return

	var esfera: SphereMesh = SphereMesh.new()
	esfera.radius = 0.08
	esfera.height = 0.16
	var brillo: StandardMaterial3D = StandardMaterial3D.new()
	brillo.albedo_color = COLOR_DESTELLO
	brillo.emission_enabled = true
	brillo.emission = Color(1.0, 0.85, 0.5)
	brillo.emission_energy_multiplier = 4.0
	esfera.material = brillo

	var chispa: MeshInstance3D = MeshInstance3D.new()
	chispa.mesh = esfera
	contenedor.add_child(chispa)
	chispa.global_position = punto + normal * 0.05

	var tween_chispa: Tween = chispa.create_tween()
	# Escala casi nula, nunca cero: una base con determinante 0 hace fallar al
	# motor al invertirla.
	tween_chispa.tween_property(chispa, "scale", Vector3(0.001, 0.001, 0.001), 0.15)
	tween_chispa.tween_callback(chispa.queue_free)
