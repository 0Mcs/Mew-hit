extends CharacterBody3D
class_name Enemigo

# Enemigo con la minima IA que hace falta para que el combate se pruebe de
# verdad: mira, persigue y AVISA antes de golpear, para que el jugador pueda
# esquivarlo. Sin pathfinding: si el move_and_slide se queda bloqueado un
# rato, se aparta a un lado y vuelve a probar. Al morir se hunde, encoge y
# emite derribado, que es lo que escucha partida.gd.

signal derribado
signal detectado
signal aviso_ataque

enum Estado { QUIETO, PERSIGUIENDO, AVISO, ATACANDO, MUERTO }

@export var vida: int = 100
@export var vida_maxima: int = 100
@export var velocidad: float = 3.5
@export var alcance_deteccion: float = 8.0
@export var alcance_ataque: float = 0.6
@export var dano: int = 20
@export var cooldown_ataque: float = 1.2
@export var duracion_aviso: float = 0.5
@export var gravedad: float = 28.0
@export var frenado: float = 16.0
@export var umbral_bloqueo: float = 0.4
@export var duracion_desvio: float = 1.2
@export var duracion_barra_vida: float = 4.0
@export var altura_barra_vida: float = 0.46
@export var duracion_destello_muerte: float = 0.25

# Disparo a distancia. La precision va de 0 (torpe, se desvia hasta ~0.14 rad)
# a 1 (certera, ~0.012 rad); el enemigo sigue persiguiendo a golpes, pero por
# el camino va tirando. Con dispara_a_distancia en false calla (para tests).
@export var dispara_a_distancia: bool = true
@export var precision: float = 0.5
@export var dano_disparo: int = 8
@export var cooldown_disparo: float = 2.4
@export var alcance_disparo: float = 7.0
@export var velocidad_proyectil: float = 9.0

# Sin melee por ahora: persigue y dispara, pero no entra a golpear (luego).
@export var ataca_cuerpo_a_cuerpo: bool = true
# En QUIETO patrulla en circulo alrededor de su spawn para que la casa
# parezca viva; al detectar al jugador la patrulla se interrumpe.
@export var patrulla_radio: float = 1.2

const MASCARA_ESCENARIO: int = 1
const COLOR_AVISO: Color = Color(4.0, 3.0, 0.4)
const COLOR_IMPACTO: Color = Color(5.0, 1.0, 1.0)
const COLOR_DISPARO: Color = Color(2.6, 2.2, 0.7)
const ESCALA_OCULTA: Vector3 = Vector3(0.001, 0.001, 0.001)

# Barra de vida flotante: dos quads procedurales, la de atras siempre y la de
# delante con el ancho de la vida. Se gira a mano hacia la camara porque el
# billboard del material solo gira su propia malla, no a los hijos.
const ANCHO_BARRA: float = 0.6
const ALTO_BARRA: float = 0.1
const ANCHO_RELLENO: float = 0.56
const ALTO_RELLENO: float = 0.06
const COLOR_BARRA_ALTA: Color = Color(0.35, 0.85, 0.4)
const COLOR_BARRA_BAJA: Color = Color(0.9, 0.2, 0.15)
const COLOR_BARRA_FONDO: Color = Color(0.0, 0.0, 0.0, 0.55)

var estado: int = Estado.QUIETO
var jugador: Node = null
var tiempo_aviso: float = 0.0
var enfriamiento_ataque: float = 0.0
var enfriamiento_disparo: float = 0.0
var pos_guardada: Vector3 = Vector3.ZERO
var angulo_patrulla: float = 0.0
var patrulla_iniciada: bool = false
var tiempo_bloqueado: float = 0.0
var sentido_desvio: float = 0.0
var tiempo_desvio: float = 0.0
var material_cuerpo: StandardMaterial3D = null
var color_base: Color = Color.WHITE
var color_actual: Color = Color.WHITE
var aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()

var barra_vida: Node3D = null
var relleno_barra: MeshInstance3D = null
var material_relleno: StandardMaterial3D = null
var tiempo_barra: float = 0.0


func _ready() -> void:
	aleatorio.seed = int(global_position.x * 37.0 + global_position.z * 11.0)
	jugador = get_tree().get_first_node_in_group("jugador") if get_tree() != null else null
	_preparar_material()
	_crear_barra_vida()
	# El cuchillo solo lo enseñan los naranjas (atacan cuerpo a cuerpo).
	var cuchillo: MeshInstance3D = get_node_or_null("Modelo/Cuchillo") as MeshInstance3D
	if cuchillo != null:
		cuchillo.visible = ataca_cuerpo_a_cuerpo


func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTO:
		return

	_paso_barra_vida(delta)

	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y -= gravedad * delta

	enfriamiento_ataque = maxf(enfriamiento_ataque - delta, 0.0)
	enfriamiento_disparo = maxf(enfriamiento_disparo - delta, 0.0)

	match estado:
		Estado.QUIETO:
			_frenar(delta)
			move_and_slide()
			_comprobar_deteccion()
			if estado == Estado.QUIETO:
				_patrullar(delta)
		Estado.PERSIGUIENDO:
			_persiguiendo(delta)
		Estado.AVISO:
			_frenar(delta)
			move_and_slide()
			tiempo_aviso -= delta
			if tiempo_aviso <= 0.0:
				_golpear()
		Estado.ATACANDO:
			_frenar(delta)
			move_and_slide()
			if enfriamiento_ataque <= 0.0:
				estado = Estado.PERSIGUIENDO if _distancia() < alcance_deteccion else Estado.QUIETO

	if estado == Estado.QUIETO or estado == Estado.PERSIGUIENDO:
		_intentar_disparo()

	if estado == Estado.PERSIGUIENDO or estado == Estado.QUIETO:
		_mirar_adelante(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------
func _comprobar_deteccion() -> void:
	if jugador == null or not is_instance_valid(jugador):
		jugador = _buscar_jugador()
		if jugador == null:
			return
	if _distancia() > alcance_deteccion:
		return
	if not _ve_al_jugador():
		return
	estado = Estado.PERSIGUIENDO
	detectado.emit()
	_llamar_sonido("reproducir_enemigo_detecta")


func _persiguiendo(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		estado = Estado.QUIETO
		return

	var dist: float = _distancia()
	if dist <= alcance_ataque * 1.8 and not ataca_cuerpo_a_cuerpo:
		# Sin melee: frena a distancia de tiro y sigue disparando.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if dist > alcance_deteccion * 1.5:
		estado = Estado.QUIETO
		return
	# A golpear solo con vista libre: desde lo alto de un muro o al otro
	# lado no se avisa ni se pega, aunque el plano este pegado. Sin aviso
	# se sigue intentando acercar (codigo de abajo).
	if dist <= alcance_ataque and _ve_al_jugador() and _alcance_vertical():
		estado = Estado.AVISO
		tiempo_aviso = duracion_aviso
		aviso_ataque.emit()
		_pintar(COLOR_AVISO)
		_llamar_sonido("reproducir_enemigo_aviso")
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var direccion: Vector3 = _hacia_jugador()
	if direccion == Vector3.ZERO:
		return

	# Desvio lateral temporal para no quedarse clavado contra un muro.
	if tiempo_desvio > 0.0:
		tiempo_desvio -= delta
		var lateral: Vector3 = direccion.cross(Vector3.UP).normalized() * sentido_desvio
		direccion = (direccion + lateral * 0.8).normalized()
	elif tiempo_desvio <= 0.0:
		sentido_desvio = 0.0

	velocity.x = direccion.x * velocidad
	velocity.z = direccion.z * velocidad

	var antes: Vector2 = Vector2(global_position.x, global_position.z)
	move_and_slide()
	_controlar_bloqueo(delta, antes)


# Patrulla circular lenta alrededor del spawn. La primera vez fija el centro
# donde este (el _ready corre antes de colocar al enemigo en su sitio).
func _patrullar(delta: float) -> void:
	if patrulla_radio <= 0.0:
		return
	if not patrulla_iniciada:
		pos_guardada = global_position
		patrulla_iniciada = true
	angulo_patrulla += delta * 0.6
	var destino: Vector3 = pos_guardada + Vector3(
		cos(angulo_patrulla) * patrulla_radio, 0.0,
		sin(angulo_patrulla) * patrulla_radio
	)
	var plano: Vector3 = destino - global_position
	plano.y = 0.0
	if plano.length() < 0.15:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		plano = plano.normalized()
		velocity.x = plano.x * velocidad * 0.35
		velocity.z = plano.z * velocidad * 0.35
	move_and_slide()


func _golpear() -> void:
	estado = Estado.ATACANDO
	enfriamiento_ataque = cooldown_ataque
	_pintar(color_base)
	if jugador != null and _distancia() <= alcance_ataque * 1.3 and _ve_al_jugador() and _alcance_vertical():
		if jugador.has_method("recibir_dano"):
			jugador.call("recibir_dano", dano)
	_llamar_sonido("reproducir_enemigo_golpe")


# ---------------------------------------------------------------------------
# Disparo a distancia
# ---------------------------------------------------------------------------
# Solo en QUIETO o PERSIGUIENDO (nunca en pleno aviso o golpe), dentro de su
# rango y con vista libre: el rayo de vision usa mascara 1 (paredes), asi que
# un mueble o el muro cortan el tiro.
func _intentar_disparo() -> void:
	if not dispara_a_distancia:
		return
	if enfriamiento_disparo > 0.0:
		return
	if jugador == null or not is_instance_valid(jugador):
		return
	var dist: float = _distancia()
	if dist < alcance_ataque * 1.5 or dist > alcance_disparo:
		return
	if not _ve_al_jugador():
		return
	enfriamiento_disparo = cooldown_disparo
	_disparar()


func _disparar() -> void:
	if get_parent() == null or jugador == null:
		return
	var altura_ojo: Vector3 = global_position + Vector3(0.0, 0.32, 0.0)
	var destino: Vector3 = jugador.global_position + Vector3(0.0, 0.3, 0.0)
	# La boca del arma sale hacia el objetivo: el error se aplica DESPUES,
	# sobre la direccion directa, para que punteria 1.0 sea certera.
	var plano: Vector3 = Vector3(destino.x - altura_ojo.x, 0.0, destino.z - altura_ojo.z)
	if plano.length_squared() < 0.0001:
		plano = -global_transform.basis.z
	plano = plano.normalized()
	var origen: Vector3 = altura_ojo + plano * 0.35
	var direccion_tiro: Vector3 = _direccion_con_error((destino - origen).normalized())

	var proy: Proyectil = Proyectil.new()
	proy.name = "Proyectil"
	proy.direccion = direccion_tiro
	proy.velocidad = velocidad_proyectil
	proy.dano = dano_disparo
	proy.alcance = alcance_disparo
	get_parent().add_child(proy)
	proy.global_position = origen

	# Fogonazo en la boca del enemigo: mismo patrón que _chispa del proyectil,
	# se encoge solo y se borra a los 0.10 s.
	if get_parent() != null:
		var destello: MeshInstance3D = MeshInstance3D.new()
		destello.name = "DestelloBoca"
		var esfera: SphereMesh = SphereMesh.new()
		esfera.radius = 0.03
		esfera.height = 0.06
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(1.0, 0.8, 0.4)
		material.emission_energy_multiplier = 4.0
		esfera.material = material
		destello.mesh = esfera
		get_parent().add_child(destello)
		destello.global_position = origen
		var brillo: Tween = destello.create_tween()
		brillo.set_parallel(true)
		brillo.tween_property(destello, "position", destello.position, 0.10)
		brillo.tween_property(destello, "scale", Vector3(0.001, 0.001, 0.001), 0.10)
		brillo.chain()
		brillo.tween_callback(destello.queue_free)

	_pintar(COLOR_DISPARO)
	_llamar_sonido("reproducir_disparo")


# La punteria: precision 1.0 se desvia como mucho ~0.012 rad (certera a
# cualquier distancia de sala) y precision 0.0 como mucho ~0.19 rad (torpe).
# El RNG propio esta sembrado con la posicion al nacer, asi que cada partida
# sale igual y el test puede fijar la semilla para medirlo.
func _direccion_con_error(base: Vector3) -> Vector3:
	var desvio: float = lerpf(0.14, 0.012, clampf(precision, 0.0, 1.0))
	if desvio <= 0.0001 or base.length_squared() < 0.0001:
		return base
	var e_horizontal: float = aleatorio.randf_range(-desvio, desvio)
	var e_vertical: float = aleatorio.randf_range(-desvio, desvio)
	var derecho: Vector3 = base.cross(Vector3.UP)
	if derecho.length_squared() < 0.0001:
		derecho = Vector3.RIGHT
	derecho = derecho.normalized()
	var arriba: Vector3 = derecho.cross(base).normalized()
	return (base + derecho * e_horizontal + arriba * e_vertical).normalized()


func recibir_dano(cantidad: int) -> void:
	if estado == Estado.MUERTO or cantidad <= 0:
		return
	vida = maxi(vida - cantidad, 0)
	_pintar(COLOR_IMPACTO)
	mostrar_barra_vida()
	if vida <= 0:
		_morir()


# La barra sale al recibir dano y se va sola, para que no ensucie la escena.
func mostrar_barra_vida() -> void:
	tiempo_barra = duracion_barra_vida
	if barra_vida != null:
		barra_vida.visible = true
		_actualizar_relleno_barra()


func vida_actual() -> int:
	return vida


func _morir() -> void:
	estado = Estado.MUERTO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector3.ZERO
	if barra_vida != null:
		barra_vida.visible = false
	derribado.emit()
	_destello_muerte()
	_poof()

	var hundido: Tween = create_tween()
	hundido.set_parallel(true)
	hundido.tween_property(self, "position", position + Vector3(0.0, -0.5, 0.0), 0.9)
	hundido.tween_property(self, "scale", ESCALA_OCULTA, 0.9)
	hundido.chain().tween_callback(queue_free)


# Destello final: el cuerpo se enciende mientras se hunde y la emision se
# apaga sola con `duracion_destello_muerte`.
func _destello_muerte() -> void:
	if material_cuerpo == null:
		return
	material_cuerpo.emission_enabled = true
	material_cuerpo.emission = Color(1.0, 0.92, 0.7)
	material_cuerpo.emission_energy_multiplier = 4.0
	var brillo: Tween = create_tween()
	brillo.tween_property(
		material_cuerpo, "emission_energy_multiplier", 0.0,
		duracion_destello_muerte
	)
	brillo.tween_callback(_apagar_emision_muerte)


func _apagar_emision_muerte() -> void:
	if material_cuerpo != null:
		material_cuerpo.emission_enabled = false


# Poof de la muerte: una nube de bolas que salen en todas direcciones y se
# encogen hasta desaparecer. Malla + tween, NUNCA GPUParticles3D: en headless
# no hay GPU que simule particulas y el test no podria ver el poof.
func _poof() -> void:
	if get_parent() == null:
		return
	var nube: Node3D = Node3D.new()
	nube.name = "Poof"
	get_parent().add_child(nube)
	nube.global_position = global_position + Vector3(0.0, 0.3, 0.0)

	for i: int in 7:
		var bola: MeshInstance3D = MeshInstance3D.new()
		var malla: SphereMesh = SphereMesh.new()
		malla.radius = 0.07
		malla.height = 0.14
		bola.name = "Bola%d" % i
		nube.add_child(bola)

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.95, 0.85)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(1.0, 0.9, 0.7)
		material.emission_energy_multiplier = 2.0
		malla.material = material
		bola.mesh = malla

		var direccion: Vector3 = Vector3(
			aleatorio.randf_range(-1.0, 1.0),
			aleatorio.randf_range(0.2, 1.0),
			aleatorio.randf_range(-1.0, 1.0)
		)
		if direccion.length_squared() < 0.0001:
			direccion = Vector3.UP
		direccion = direccion.normalized()
		var distancia: float = aleatorio.randf_range(0.2, 0.45)

		var salir: Tween = bola.create_tween()
		salir.set_parallel(true)
		salir.tween_property(bola, "position", direccion * distancia, 0.4)
		salir.tween_property(bola, "scale", ESCALA_OCULTA, 0.4)

	var terminar: Tween = nube.create_tween()
	terminar.tween_interval(0.45)
	terminar.tween_callback(nube.queue_free)


# ---------------------------------------------------------------------------
# Utilidades de percepcion y movimiento
# ---------------------------------------------------------------------------
func _buscar_jugador() -> Node:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return null
	return arbol.get_first_node_in_group("jugador")


func _distancia() -> float:
	if jugador == null:
		return INF
	var dx: float = global_position.x - jugador.global_position.x
	var dz: float = global_position.z - jugador.global_position.z
	return sqrt(dx * dx + dz * dz)


func _hacia_jugador() -> Vector3:
	var d: Vector3 = Vector3(
		jugador.global_position.x - global_position.x,
		0.0,
		jugador.global_position.z - global_position.z
	)
	if d.length_squared() < 0.0001:
		return Vector3.ZERO
	return d.normalized()


# Solo escenario en la mascara: no se ve a traves de los muros.
func _ve_al_jugador() -> bool:
	if jugador == null:
		return false
	var mundo: World3D = get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return true
	# Mirada a la altura del hocico de un gato, no de una persona.
	var origen: Vector3 = global_position + Vector3(0.0, 0.4, 0.0)
	var destino: Vector3 = jugador.global_position + Vector3(0.0, 0.35, 0.0)
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origen, destino, MASCARA_ESCENARIO
	)
	return mundo.direct_space_state.intersect_ray(consulta).is_empty()


# A melee solo llega a su misma altura: en vertical hay vista libre, asi
# que sin esta puerta pegarian desde un muro o una plataforma.
func _alcance_vertical() -> bool:
	if jugador == null or not (jugador is Node3D):
		return false
	return absf((jugador as Node3D).global_position.y - global_position.y) <= 0.7


func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, frenado * delta)
	velocity.z = move_toward(velocity.z, 0.0, frenado * delta)


# Si va hacia el jugador y avanza mucho menos de lo esperado, algo le tapa:
# apartarse un rato a un lado.
func _controlar_bloqueo(delta: float, antes: Vector2) -> void:
	var recorrido: float = antes.distance_to(Vector2(global_position.x, global_position.z))
	var esperado: float = velocidad * delta
	if recorrido < esperado * 0.45:
		tiempo_bloqueado += delta
	else:
		tiempo_bloqueado = maxf(tiempo_bloqueado - delta * 2.0, 0.0)

	if tiempo_bloqueado >= umbral_bloqueo and tiempo_desvio <= 0.0:
		sentido_desvio = 1.0 if aleatorio.randf() < 0.5 else -1.0
		tiempo_desvio = duracion_desvio
		tiempo_bloqueado = 0.0


func _mirar_adelante(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	var d: Vector3 = _hacia_jugador()
	if d == Vector3.ZERO:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(9.0 * delta, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Material y sonido
# ---------------------------------------------------------------------------
func _preparar_material() -> void:
	var malla: MeshInstance3D = get_node_or_null("Modelo/Cuerpo")
	if malla == null:
		return
	var base: Material = malla.get_active_material(0)
	if base is StandardMaterial3D:
		material_cuerpo = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	if material_cuerpo == null:
		material_cuerpo = StandardMaterial3D.new()
	color_base = material_cuerpo.albedo_color
	color_actual = color_base
	malla.material_override = material_cuerpo


func _pintar(color: Color) -> void:
	if material_cuerpo == null:
		return
	color_actual = color
	material_cuerpo.albedo_color = color
	# Vuelve solo al color base en el proximo golpe o al salir del aviso.
	if color != color_base:
		var vuelta: Tween = create_tween()
		vuelta.tween_property(material_cuerpo, "albedo_color", color_base, 0.35)


func _llamar_sonido(metodo: String) -> void:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return
	var candidatos: Array[Node] = arbol.get_nodes_in_group("sonido")
	if candidatos.is_empty():
		return
	if candidatos[0].has_method(metodo):
		candidatos[0].call(metodo)


# ---------------------------------------------------------------------------
# Barra de vida flotante
# ---------------------------------------------------------------------------
func _crear_barra_vida() -> void:
	barra_vida = Node3D.new()
	barra_vida.name = "BarraVida"
	add_child(barra_vida)
	barra_vida.position = Vector3(0.0, altura_barra_vida, 0.0)
	barra_vida.visible = false

	var fondo: MeshInstance3D = _quad_barra(ANCHO_BARRA, ALTO_BARRA, COLOR_BARRA_FONDO)
	fondo.name = "Fondo"
	barra_vida.add_child(fondo)

	var relleno: MeshInstance3D = _quad_barra(ANCHO_RELLENO, ALTO_RELLENO, COLOR_BARRA_ALTA)
	relleno.name = "Relleno"
	barra_vida.add_child(relleno)
	relleno_barra = relleno
	material_relleno = (relleno.mesh as QuadMesh).material as StandardMaterial3D


func _quad_barra(ancho: float, alto: float, color: Color) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(ancho, alto)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	# Sin cull: la barra se gira hacia la camara y da igual que lado mire.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	var malla: MeshInstance3D = MeshInstance3D.new()
	malla.mesh = quad
	return malla


func _paso_barra_vida(delta: float) -> void:
	if barra_vida == null or not barra_vida.visible:
		return
	tiempo_barra = maxf(tiempo_barra - delta, 0.0)
	if tiempo_barra <= 0.0:
		barra_vida.visible = false
		return
	_actualizar_relleno_barra()

	var vista: Viewport = get_viewport()
	var camara: Camera3D = vista.get_camera_3d() if vista != null else null
	if camara == null:
		return
	var hacia: Vector3 = camara.global_position - barra_vida.global_position
	if hacia.length_squared() < 0.0001:
		return
	# Si la camara esta casi justo encima, look_at se vuelve inestable:
	# mejor no girar ese frame.
	if absf(hacia.normalized().dot(Vector3.UP)) > 0.995:
		return
	barra_vida.look_at(camara.global_position, Vector3.UP)


func _actualizar_relleno_barra() -> void:
	if relleno_barra == null or material_relleno == null:
		return
	var maxima: int = maxi(vida_maxima, 1)
	var ratio: float = clampf(float(vida) / float(maxima), 0.0, 1.0)
	# Escala casi nula, nunca cero: una base con determinante 0 hace fallar
	# al motor al invertirla.
	relleno_barra.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
	relleno_barra.position.x = -ANCHO_RELLENO * (1.0 - ratio) * 0.5
	material_relleno.albedo_color = COLOR_BARRA_ALTA.lerp(COLOR_BARRA_BAJA, 1.0 - ratio)
