extends CharacterBody3D
class_name Jugador

# Controlador del gato. Un nodo, un script: fisica, camara y feedback viven
# aqui para que no haya dos fuentes de verdad compitiendo por la velocidad.

signal dano_recibido(cantidad: int)
signal muerto
signal dash_iniciado

const GRUPO_PARED: String = "pared"
const GRUPO_SUELO: String = "suelo"

# ---------------------------------------------------------------------------
# Movimiento (los de sensacion se cazar desde el inspector)
# ---------------------------------------------------------------------------
@export var velocidad_caminar: float = 2.2
@export var velocidad_correr: float = 4.4
@export var aceleracion_suelo: float = 20.0
@export var aceleracion_aire: float = 5.0
@export var frenado_suelo: float = 24.0
@export var frenado_aire: float = 5.0
@export var agarre_suelo: float = 8.0
@export var agarre_tope: float = 6.0
@export var gravedad: float = 28.0
@export var gravedad_caida: float = 42.0
@export var altura_salto: float = 0.8
@export var velocidad_salto_min: float = 5.0
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.15
@export var fuerza_dash: float = 11.0
@export var duracion_dash: float = 0.18
@export var cooldown_dash: float = 0.8
@export var curva_salida_dash: float = 12.0
@export var velocidad_trepar: float = 3.5
@export var velocidad_trepar_lateral: float = 1.8
@export var alcance_pared: float = 0.5
@export var altura_agachado: float = 0.24
@export var altura_de_pie: float = 1.8
@export var duracion_agacharse: float = 0.12
# Cuanto baja el cuerpo al agacharse (metros, en espacio del jugador) y
# cuanto se pliegan las patas (radianes). La escala NO se toca: el gato se
# agacha de verdad y lo que se apachurra es la hitbox (la capsula).
@export var bajada_agachado: float = 0.06
@export var pliegue_agachado: float = 0.9
@export var velocidad_rotacion: float = 14.0
@export var velocidad_rotar_atras: float = 18.0
@export var amplitud_paso: float = 0.012
@export var umbral_paso: float = 0.12

# ---------------------------------------------------------------------------
# Disparo alineado: mientras se mantiene el disparo el cuerpo se gira hacia
# la mirada; el tiro sale alineado o, como maximo, tras espera_disparo.
# ---------------------------------------------------------------------------
@export var espera_disparo: float = 0.12
@export var umbral_alineacion: float = 0.79
@export var velocidad_girar_disparo: float = 25.0

# ---------------------------------------------------------------------------
# Camara de hombro
# ---------------------------------------------------------------------------
@export var sensibilidad_mouse: float = 0.0022
@export var damping_camara: float = 12.0
@export var angulo_max_vertical: float = 1.35
@export var offset_hombro: float = 0.25
@export var inclinacion_base: float = -0.12
@export var zoom_por_defecto: float = 1.3
@export var zoom_correr: float = 1.45

# ---------------------------------------------------------------------------
# Feedback (se pueden apagar a cero desde el inspector)
# ---------------------------------------------------------------------------
@export var amplitud_retroceso: float = 0.035
@export var amplitud_sacudida_max: float = 0.2
@export var duracion_sacudida: float = 0.15
@export var ganancia_sacudida: float = 0.005
@export var roll_maximo: float = 0.04
@export var ganancia_roll: float = 0.02
@export var ganancia_fov_disparo: float = 5.0
@export var sacudida_disparo: float = 0.016
@export var tiempo_para_maullido: float = 15.0
@export var inclinacion_cabeza: float = 0.65
@export var limite_cabeza: float = 0.5
@export var umbral_particula: float = 1.5
@export var vida_particula: float = 0.45
@export var tamano_particula: float = 0.06
@export var cantidad_polvo: int = 20
@export var cantidad_rastro: int = 24
@export var color_polvo: Color = Color(0.88, 0.83, 0.74, 0.55)
@export var color_rastro: Color = Color(0.62, 0.86, 1.0, 0.7)

# ---------------------------------------------------------------------------
# Nodos. "buscar" mira primero en la raiz y luego bajo "Modelo": verificar.gd
# usa exactamente la misma logica para no poder quedar en verde con un nodo
# en la ruta equivocada.
# ---------------------------------------------------------------------------
@onready var colision: CollisionShape3D = buscar("CollisionShape3D") as CollisionShape3D
@onready var modelo: Node3D = buscar("Modelo") as Node3D
@onready var brazo_camara: SpringArm3D = buscar("SpringArm3D") as SpringArm3D
@onready var camara: Camera3D = buscar("SpringArm3D/Camara3D") as Camera3D
@onready var pistola: Node3D = buscar("Pistola") as Node3D
@onready var raycast_pared: RayCast3D = buscar("RayCastPared") as RayCast3D
@onready var raycast_techo: RayCast3D = buscar("RayCastTecho") as RayCast3D
@onready var cuerpo: MeshInstance3D = buscar("Cuerpo") as MeshInstance3D
@onready var cabeza: MeshInstance3D = buscar("Cabeza") as MeshInstance3D
@onready var cola: MeshInstance3D = buscar("Cola") as MeshInstance3D
@onready var vida_nodo: Node = buscar("Vida")

# Altura base de las patas en la escena y cuanto se recogen al plegarse,
# para que los pies plegados sigan tocando el suelo en vez de hundirse.
const PATA_Y_BASE: float = 0.08
const RECOGIDA_PATAS: float = 0.03

# Estado de fisica
var velocidad_vertical: float = 0.0
var direccion_deseada: Vector3 = Vector3.ZERO
var hay_entrada: bool = false
var en_suelo: bool = false
var trepando: bool = false
var agachado: bool = false
var baja_actual: float = 0.0
var temporizador_coyote: float = 0.0
var buffer_salto: float = 0.0
var enfriamiento_dash: float = 0.0
var tiempo_dash: float = 0.0
var dash_activo: bool = false
var saliendo_dash: bool = false
var direccion_dash: Vector3 = Vector3.ZERO
var forma_capsula: CapsuleShape3D = null
var modelo_y_base: float = 0.0
var bajada_cuerpo: float = 0.0
var pliegue_actual: float = 0.0
var patas_delanteras: Array[Node3D] = []
var patas_traseras: Array[Node3D] = []
var tiempo_paso: float = 0.0
var onda_paso_anterior: float = 0.0
var tiempo_quieto: float = 0.0
var normal_pared: Vector3 = Vector3.ZERO
var pendiente_disparo: float = 0.0

# Camara
var yaw_deseado: float = 0.0
var pitch_deseado: float = 0.0
var yaw_suave: float = 0.0
var pitch_suave: float = 0.0
var zoom_actual: float = 1.3
var yaw_anterior: float = 0.0
var retroceso_camara: float = 0.0
var roll_camara: float = 0.0
var brazo_y_base: float = 0.0
var fov_base: float = 75.0
var fov_kick: float = 0.0

# Feedback
var sacudida_camara: float = 0.0
var tiempo_sacudida: float = 0.0
var amplitud_sacudida_actual: float = 0.0
var raton_capturado: bool = true
var polvo_aterrizar: GPUParticles3D = null
var polvo_correr: GPUParticles3D = null
var rastro_dash: GPUParticles3D = null
# Veces que se ha disparado la ráfaga de polvo al caer. El test lo lee porque
# en headless no hay GPU que simule las particulas.
var rafagas_polvo: int = 0


func buscar(nombre: String) -> Node:
	var n: Node = get_node_or_null(nombre)
	if n == null:
		n = get_node_or_null("Modelo/" + nombre)
	return n


func _ready() -> void:
	up_direction = Vector3.UP

	# Los sub_resource se comparten entre instancias: duplicamos la capsula
	# antes de tocar su altura.
	if colision != null:
		var forma_original: CapsuleShape3D = colision.shape as CapsuleShape3D
		if forma_original != null:
			forma_capsula = forma_original.duplicate() as CapsuleShape3D
			colision.shape = forma_capsula

	# La altura de pie se LEE de la escena: no hay numero inventado.
	if forma_capsula != null:
		altura_de_pie = forma_capsula.height
	if modelo != null:
		modelo_y_base = modelo.position.y
		for nombre_del: String in ["Pata1", "Pata2"]:
			var pata_del: Node3D = modelo.get_node_or_null(nombre_del) as Node3D
			if pata_del != null:
				patas_delanteras.append(pata_del)
		for nombre_tra: String in ["Pata3", "Pata4"]:
			var pata_tra: Node3D = modelo.get_node_or_null(nombre_tra) as Node3D
			if pata_tra != null:
				patas_traseras.append(pata_tra)

	if brazo_camara != null:
		zoom_actual = brazo_camara.spring_length
		brazo_y_base = brazo_camara.position.y
		yaw_deseado = brazo_camara.rotation.y
		yaw_suave = yaw_deseado
		yaw_anterior = yaw_suave
		pitch_suave = 0.0
		pitch_deseado = 0.0
	if camara != null:
		fov_base = camara.fov

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_colgar_piezas_cabeza()
	_crear_particulas()


# El hocico, los ojos y las orejas se cuelgan de "Cabeza" para que la cabeza
# gira ENTERA cuando el gato mira hacia donde dispara, y no solo la bola del
# craneo. Se hace aqui por codigo: la escena no cambia.
func _colgar_piezas_cabeza() -> void:
	if cabeza == null:
		return
	for nombre: String in ["Hocico", "OjoIzquierdo", "OjoDerecho", "OrejaIzquierda", "OrejaDerecha"]:
		var pieza: Node3D = buscar(nombre) as Node3D
		if pieza == null or pieza.get_parent() == cabeza:
			continue
		pieza.reparent(cabeza, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and raton_capturado:
		yaw_deseado -= (event as InputEventMouseMotion).relative.x * sensibilidad_mouse
		pitch_deseado -= (event as InputEventMouseMotion).relative.y * sensibilidad_mouse

	if event.is_action_pressed("ui_cancel"):
		_cambiar_captura(not raton_capturado)
		return

	if event.is_action_pressed("fire"):
		if not raton_capturado:
			_cambiar_captura(true)
			return
		_pedir_disparo()


# El disparo entra en cola: sale en cuanto el cuerpo mira hacia la mirada
# (o al cabo de espera_disparo, por si algo lo bloquea). Nunca se pierde el
# clic, y nunca sale un tiro del revés.
func _pedir_disparo() -> void:
	pendiente_disparo = espera_disparo


func _disparo_en_curso() -> bool:
	return pendiente_disparo > 0.0 or Input.is_action_pressed("fire")


func _alineado_para_disparo() -> bool:
	if modelo == null or brazo_camara == null:
		return true
	var desvio: float = absf(wrapf(modelo.rotation.y - brazo_camara.rotation.y, -PI, PI))
	return desvio <= umbral_alineacion


func _procesar_tiro(delta: float) -> void:
	if pendiente_disparo <= 0.0:
		return
	pendiente_disparo -= delta
	if _alineado_para_disparo() or pendiente_disparo <= 0.0:
		pendiente_disparo = 0.0
		disparar()


func _cambiar_captura(cap: bool) -> void:
	raton_capturado = cap
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if cap else Input.MOUSE_MODE_VISIBLE


func disparar() -> void:
	if pistola == null or not pistola.has_method("disparar"):
		return
	var listo: bool = true
	if pistola.has_method("puede_disparar"):
		listo = bool(pistola.call("puede_disparar"))
	pistola.call("disparar")
	if not listo:
		return
	retroceso_camara += amplitud_retroceso
	# Feedback del tiro en la camara: el FOV se abre un pelin y la sacudida
	# del disparo solo arranca si no hay otra mas gorda (aterrizaje) en curso.
	fov_kick = ganancia_fov_disparo
	if tiempo_sacudida <= 0.0:
		tiempo_sacudida = duracion_sacudida
		amplitud_sacudida_actual = sacudida_disparo


func recibir_dano(cantidad: int) -> void:
	if vida_nodo != null and vida_nodo.has_method("recibir_dano"):
		vida_nodo.call("recibir_dano", cantidad)
	dano_recibido.emit(cantidad)
	_llamar_sonido("reproducir_maullido_dano")


func vida_actual() -> int:
	if vida_nodo == null:
		return 0
	var valor: Variant = vida_nodo.get("vida")
	return valor as int if valor is int else 0


func _physics_process(delta: float) -> void:
	var en_suelo_antes: bool = is_on_floor()
	en_suelo = en_suelo_antes

	_calcular_direccion()
	_contar_quieto(delta)
	_gravedad_y_salto(delta)
	_trepar(delta)
	_dash(delta)
	_movimiento(delta)

	velocity.y = velocidad_vertical
	var caida: float = velocity.y
	move_and_slide()

	var aterrizado: bool = is_on_floor()
	if aterrizado and not en_suelo_antes and caida < 0.0:
		_al_aterrizar(-caida)
	en_suelo = aterrizado
	if en_suelo and velocidad_vertical < 0.0:
		velocidad_vertical = 0.0

	_agacharse(delta)
	_paso(delta)
	_actualizar_particulas()
	_actualizar_camara(delta)
	_procesar_tiro(delta)


# ---------------------------------------------------------------------------
# Direccion de movimiento, relativa a la camara
# ---------------------------------------------------------------------------
func _adelante_camara() -> Vector3:
	if brazo_camara == null:
		return Vector3.FORWARD
	var v: Vector3 = -brazo_camara.global_transform.basis.z
	v.y = 0.0
	if v.length_squared() < 0.0001:
		return Vector3.FORWARD
	return v.normalized()


func _derecha_camara() -> Vector3:
	if brazo_camara == null:
		return Vector3.RIGHT
	var v: Vector3 = brazo_camara.global_transform.basis.x
	v.y = 0.0
	if v.length_squared() < 0.0001:
		return Vector3.RIGHT
	return v.normalized()


func _calcular_direccion() -> void:
	var entrada: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_back", "move_forward"
	)
	if entrada.length_squared() > 1.0:
		entrada = entrada.normalized()
	direccion_deseada = _adelante_camara() * entrada.y + _derecha_camara() * entrada.x
	if direccion_deseada.length_squared() > 1.0:
		direccion_deseada = direccion_deseada.normalized()
	hay_entrada = direccion_deseada.length_squared() > 0.0001


func _velocidad_objetivo() -> float:
	if not hay_entrada:
		return 0.0
	return velocidad_correr if Input.is_action_pressed("sprint") else velocidad_caminar


# ---------------------------------------------------------------------------
# Movimiento horizontal: acelerar, frenar y el agarre al suelo
# ---------------------------------------------------------------------------
func _movimiento(delta: float) -> void:
	if trepando:
		return
	if dash_activo:
		return

	if saliendo_dash:
		# La salida del dash se interpola: nunca se corta en seco.
		tiempo_dash -= delta
		var destino: Vector3 = direccion_deseada * _velocidad_objetivo()
		var salida: Vector3 = Vector3(velocity.x, 0.0, velocity.z).lerp(
			destino, clampf(curva_salida_dash * delta, 0.0, 1.0)
		)
		velocity.x = salida.x
		velocity.z = salida.z
		if tiempo_dash <= -duracion_dash:
			saliendo_dash = false
		_rotar_cuerpo(delta)
		return

	var actual: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var factor: float = aceleracion_suelo if en_suelo else aceleracion_aire
	var freno: float = frenado_suelo if en_suelo else frenado_aire

	if hay_entrada:
		actual = actual.move_toward(direccion_deseada * _velocidad_objetivo(), factor * delta)
	else:
		actual = actual.move_toward(Vector3.ZERO, freno * delta)

	# Agarre: solo en suelo y solo con entrada. Reduce la residual hacia cero
	# sin anular el movimiento de lado (ese era el bug de v0.1).
	if en_suelo and hay_entrada:
		var residual: Vector3 = actual - direccion_deseada * _velocidad_objetivo()
		residual = residual.move_toward(Vector3.ZERO, minf(agarre_suelo, agarre_tope) * delta)
		actual = direccion_deseada * _velocidad_objetivo() + residual

	velocity.x = actual.x
	velocity.z = actual.z
	_rotar_cuerpo(delta)


# Strafe: el cuerpo sigue a la camara y solo gira 180 al correr de espaldas.
# Mientras se dispara, en cambio, se gira SIEMPRE hacia la mirada.
func _rotar_cuerpo(delta: float) -> void:
	if modelo == null:
		return
	var yaw_cam: float = brazo_camara.rotation.y if brazo_camara != null else 0.0
	var objetivo: float = yaw_cam
	var velocidad: float = velocidad_rotacion
	var disparando: bool = _disparo_en_curso()

	if dash_activo and direccion_dash.length_squared() > 0.0001:
		objetivo = atan2(-direccion_dash.x, -direccion_dash.z)
		velocidad = velocidad_rotar_atras
	elif hay_entrada and direccion_deseada.dot(_adelante_camara()) < -0.4:
		if disparando:
			objetivo = yaw_cam
			velocidad = velocidad_girar_disparo
		else:
			objetivo = yaw_cam + PI
			velocidad = velocidad_rotar_atras
	elif disparando:
		velocidad = velocidad_girar_disparo

	modelo.rotation.y = lerp_angle(
		modelo.rotation.y, objetivo, clampf(velocidad * delta, 0.0, 1.0)
	)
	# El arma cuelga del hombro del MODELO: compensamos su giro (y el pitch
	# de la camara) para que el canon siga apuntando a la mirada.
	if pistola != null:
		pistola.rotation.y = wrapf(yaw_cam - modelo.rotation.y, -PI, PI)
		pistola.rotation.x = pitch_suave


# ---------------------------------------------------------------------------
# Gravedad y salto
# ---------------------------------------------------------------------------
func _gravedad_y_salto(delta: float) -> void:
	if en_suelo and not trepando:
		temporizador_coyote = coyote_time
	else:
		temporizador_coyote = maxf(temporizador_coyote - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		buffer_salto = jump_buffer
	else:
		buffer_salto = maxf(buffer_salto - delta, 0.0)

	if buffer_salto > 0.0 and temporizador_coyote > 0.0 and not trepando:
		velocidad_vertical = sqrt(2.0 * gravedad * altura_salto)
		buffer_salto = 0.0
		temporizador_coyote = 0.0

	if Input.is_action_just_released("jump") and velocidad_vertical > velocidad_salto_min:
		velocidad_vertical = velocidad_salto_min

	if trepando or en_suelo:
		return
	var g: float = gravedad_caida if velocidad_vertical < 0.0 else gravedad
	velocidad_vertical -= g * delta


# ---------------------------------------------------------------------------
# Dash
# ---------------------------------------------------------------------------
func _dash(delta: float) -> void:
	enfriamiento_dash = maxf(enfriamiento_dash - delta, 0.0)

	if dash_activo:
		tiempo_dash -= delta
		velocity.x = direccion_dash.x * fuerza_dash
		velocity.z = direccion_dash.z * fuerza_dash
		if tiempo_dash <= 0.0:
			dash_activo = false
			saliendo_dash = true
		return

	if Input.is_action_just_pressed("dash") and enfriamiento_dash <= 0.0 and not trepando:
		var dir: Vector3 = direccion_deseada
		if dir.length_squared() < 0.0001:
			dir = _adelante_camara()
		if dir.length_squared() < 0.0001:
			return
		direccion_dash = dir
		dash_activo = true
		tiempo_dash = duracion_dash
		enfriamiento_dash = cooldown_dash
		saliendo_dash = false
		dash_iniciado.emit()
		_llamar_sonido("reproducir_dash")


# ---------------------------------------------------------------------------
# Trepar
# ---------------------------------------------------------------------------
func _trepar(_delta: float) -> void:
	if raycast_pared == null:
		return

	var quiere_climb: bool = Input.is_action_pressed("climb")

	# Hacia donde empuja el jugador; sin entrada, hacia donde mira la camara.
	var apuntar: Vector3 = direccion_deseada if hay_entrada else _adelante_camara()

	var hay_pared: bool = false
	normal_pared = Vector3.ZERO

	if apuntar.length_squared() > 0.0001:
		# El rayo apunta por su -Z local, igual que una camara.
		raycast_pared.rotation.y = atan2(-apuntar.x, -apuntar.z)
		raycast_pared.target_position = Vector3(0.0, 0.0, -alcance_pared)
		raycast_pared.force_raycast_update()
		if raycast_pared.is_colliding():
			var col: Object = raycast_pared.get_collider()
			if col is Node and (col as Node).is_in_group(GRUPO_PARED):
				var n: Vector3 = raycast_pared.get_collision_normal()
				if absf(n.y) < 0.3:
					hay_pared = true
					normal_pared = n

	var empuja: bool = hay_pared and direccion_deseada.dot(-normal_pared) > 0.3

	if trepando:
		if not hay_pared or en_suelo or not (quiere_climb or empuja):
			trepando = false
		else:
			_mantener_trepada()
			return

	# Empezar: con climb se puede desde el suelo; empujando la pared solo en aire.
	if hay_pared and (quiere_climb or (empuja and not en_suelo)):
		trepando = true
		dash_activo = false
		saliendo_dash = false
		_llamar_sonido("reproducir_trepar")
		_mantener_trepada()


func _mantener_trepada() -> void:
	velocidad_vertical = velocidad_trepar
	var hacia_pared: Vector3 = -normal_pared
	hacia_pared.y = 0.0
	if hacia_pared.length_squared() > 0.0001:
		hacia_pared = hacia_pared.normalized()

	# Desplazamiento sobre el plano de la pared + empuje de contacto.
	var plano: Vector3 = direccion_deseada - normal_pared * direccion_deseada.dot(normal_pared)
	plano.y = 0.0
	velocity.x = plano.x * velocidad_trepar_lateral + hacia_pared.x * velocidad_trepar_lateral
	velocity.z = plano.z * velocidad_trepar_lateral + hacia_pared.z * velocidad_trepar_lateral


# ---------------------------------------------------------------------------
# Agacharse: la capsula se mueve a velocidad constante (termina EXACTAMENTE
# en el objetivo tras duracion_agacharse) y el gato se agacha DE VERDAD: el
# cuerpo baja y las patas se pliegan bajo el (delanteras hacia atras,
# traseras hacia adelante). La escala no se toca: lo que se apachurra es la
# hitbox, que es lo que tiene sentido.
# ---------------------------------------------------------------------------
func _agacharse(delta: float) -> void:
	if forma_capsula == null or colision == null:
		return
	var quiere: bool = Input.is_action_pressed("crouch")
	var nuevo: bool = quiere or not _puede_levantarse()
	agachado = nuevo
	var altura_objetivo: float = altura_agachado if agachado else altura_de_pie

	var velocidad_alto: float = absf(altura_de_pie - altura_agachado) / maxf(
		duracion_agacharse, 0.01
	)
	forma_capsula.height = move_toward(
		forma_capsula.height, altura_objetivo, velocidad_alto * delta
	)
	colision.position.y = forma_capsula.height * 0.5
	baja_actual = (altura_de_pie - forma_capsula.height) * 0.5

	# Cuerpo y patas a la misma velocidad constante que la capsula.
	var bajada_objetivo: float = bajada_agachado if agachado else 0.0
	var pliegue_objetivo: float = pliegue_agachado if agachado else 0.0
	var velocidad_bajada: float = bajada_agachado / maxf(duracion_agacharse, 0.01)
	var velocidad_pliegue: float = pliegue_agachado / maxf(duracion_agacharse, 0.01)
	bajada_cuerpo = move_toward(bajada_cuerpo, bajada_objetivo, velocidad_bajada * delta)
	pliegue_actual = move_toward(pliegue_actual, pliegue_objetivo, velocidad_pliegue * delta)
	var recogida: float = RECOGIDA_PATAS * (pliegue_actual / maxf(pliegue_agachado, 0.01))
	for pata_del: Node3D in patas_delanteras:
		pata_del.rotation.x = -pliegue_actual
		pata_del.position.y = PATA_Y_BASE + recogida
	for pata_tra: Node3D in patas_traseras:
		pata_tra.rotation.x = pliegue_actual
		pata_tra.position.y = PATA_Y_BASE + recogida


func _puede_levantarse() -> bool:
	if raycast_techo == null:
		return true
	raycast_techo.force_raycast_update()
	if not raycast_techo.is_colliding():
		return true
	var origen_y: float = raycast_techo.global_position.y
	var necesaria: float = altura_de_pie - origen_y
	var altura_golpe: float = raycast_techo.get_collision_point().y - origen_y
	return altura_golpe > necesaria


# ---------------------------------------------------------------------------
# Paso: oscilacion ligada a los metros recorridos (un ciclo cada 2 m)
# ---------------------------------------------------------------------------
func _paso(delta: float) -> void:
	if modelo == null:
		return
	# El modelo baja lo que manda el agachado (nada de aplastar la escala);
	# la camara baja via baja_actual. Los pies plegados ya quedan recogidos.
	var y: float = modelo_y_base - bajada_cuerpo
	var vel_h: float = Vector2(velocity.x, velocity.z).length()

	if en_suelo and not trepando and vel_h > umbral_paso:
		tiempo_paso += delta * vel_h
		var onda: float = sin(tiempo_paso * PI)
		y += onda * amplitud_paso
		if onda < 0.0 and onda_paso_anterior >= 0.0:
			_llamar_sonido("reproducir_paso")
		onda_paso_anterior = onda

	modelo.position.y = y


func _al_aterrizar(fuerza: float) -> void:
	tiempo_sacudida = duracion_sacudida
	amplitud_sacudida_actual = -minf(fuerza * ganancia_sacudida, amplitud_sacudida_max)
	if polvo_aterrizar != null:
		polvo_aterrizar.restart()
		polvo_aterrizar.emitting = true
		rafagas_polvo += 1


func _contar_quieto(delta: float) -> void:
	if hay_entrada or trepando or dash_activo:
		tiempo_quieto = 0.0
		return
	tiempo_quieto += delta
	if tiempo_quieto >= tiempo_para_maullido:
		tiempo_quieto = 0.0
		_llamar_sonido("reproducir_maullido")


# ---------------------------------------------------------------------------
# Particulas: polvo al aterrizar y al correr, y rastro al dash. Se generan
# aqui, igual que el sonido, sin un solo archivo en el proyecto.
# ---------------------------------------------------------------------------
func _crear_particulas() -> void:
	# Ráfaga de los pies al caer: sube y cae de nuevo.
	polvo_aterrizar = _nueva_particula("PolvoAterrizaje", cantidad_polvo, 0.4, true)
	_configurar_particula(
		polvo_aterrizar, Vector3.UP, 75.0, 0.6, 1.4, Vector3(0.0, -6.0, 0.0), color_polvo
	)

	# Polvo mientras corre por el suelo, encendido y apagado segun la velocidad.
	polvo_correr = _nueva_particula("PolvoCorrer", maxi(cantidad_polvo / 2, 4), 0.3, false)
	_configurar_particula(
		polvo_correr, Vector3.UP, 45.0, 0.25, 0.55, Vector3(0.0, -2.5, 0.0), color_polvo
	)

	# Rastro del dash: sale hacia detras del gato.
	rastro_dash = _nueva_particula("RastroDash", cantidad_rastro, 0.35, false)
	_configurar_particula(
		rastro_dash, Vector3.BACK, 55.0, 1.0, 2.2, Vector3(0.0, -1.2, 0.0), color_rastro
	)


func _nueva_particula(nombre: String, cantidad: int, vida: float, un_tiro: bool) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = nombre
	p.amount = maxi(cantidad, 1)
	p.lifetime = maxf(vida, 0.05)
	p.one_shot = un_tiro
	p.explosiveness = 1.0 if un_tiro else 0.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8.0, -3.0, -8.0), Vector3(16.0, 8.0, 16.0))
	p.draw_pass_1 = _malla_polvo()
	add_child(p)
	p.position = Vector3(0.0, 0.05, 0.0)
	return p


func _configurar_particula(
	p: GPUParticles3D, direccion: Vector3, apertura: float,
	vel_min: float, vel_max: float, gravedad: Vector3, color: Color
) -> void:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = direccion
	material.spread = apertura
	material.initial_velocity_min = vel_min
	material.initial_velocity_max = vel_max
	material.gravity = gravedad
	material.scale_min = 0.55
	material.scale_max = 1.3
	material.color = color
	p.process_material = material


# Cuadradito translucido que se tiñe con el color del process material.
func _malla_polvo() -> QuadMesh:
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(tamano_particula, tamano_particula)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	malla.material = material
	return malla


func _actualizar_particulas() -> void:
	var vel_h: float = Vector2(velocity.x, velocity.z).length()
	if polvo_correr != null:
		polvo_correr.emitting = (
			trepando
			or (en_suelo and not trepando and not agachado and vel_h > umbral_particula)
		)
	if rastro_dash != null:
		rastro_dash.emitting = dash_activo


# ---------------------------------------------------------------------------
# Camara: damping sobre el ACUMULADO del raton, nunca sobre el resultado
# ---------------------------------------------------------------------------
func _actualizar_camara(delta: float) -> void:
	if brazo_camara == null:
		return

	var factor: float = clampf(damping_camara * delta, 0.0, 1.0)
	yaw_suave = lerp_angle(yaw_suave, yaw_deseado, factor)
	pitch_suave = lerpf(
		pitch_suave,
		clampf(pitch_deseado, -angulo_max_vertical, angulo_max_vertical),
		factor
	)

	# Roll: cambio real de yaw por frame, con wrapf, limitado y sin restaurar.
	var delta_yaw: float = wrapf(yaw_suave - yaw_anterior, -PI, PI)
	yaw_anterior = yaw_suave
	var roll_deseado: float = clampf(
		delta_yaw / maxf(delta, 0.0001) * ganancia_roll, -roll_maximo, roll_maximo
	)
	roll_camara = lerpf(roll_camara, roll_deseado, factor)

	retroceso_camara = lerpf(retroceso_camara, 0.0, factor)

	if tiempo_sacudida > 0.0:
		tiempo_sacudida = maxf(tiempo_sacudida - delta, 0.0)
		var t: float = tiempo_sacudida / maxf(duracion_sacudida, 0.001)
		sacudida_camara = amplitud_sacudida_actual * t
	else:
		sacudida_camara = 0.0

	brazo_camara.rotation.y = yaw_suave
	brazo_camara.rotation.x = pitch_suave + inclinacion_base + retroceso_camara + sacudida_camara
	brazo_camara.rotation.z = roll_camara
	# El hombro se aplica en el espacio de la MIRADA, no del cuerpo: la raiz
	# nunca gira, y con el offset crudo en X la camara pasaba al otro lado de
	# la pantalla al girar 180. Y baja al agacharse para no meterse en los muebles.
	brazo_camara.position = Vector3(
		offset_hombro, brazo_y_base - baja_actual, 0.0
	).rotated(Vector3.UP, yaw_suave)

	# La cabeza sigue la camara: el gato levanta la mira cuando apunta
	# arriba y la baja cuando apunta al suelo. Mismo damping que la camara.
	if cabeza != null:
		var cabeza_deseada: float = clampf(
			pitch_suave * inclinacion_cabeza, -limite_cabeza, limite_cabeza
		)
		cabeza.rotation.x = lerpf(cabeza.rotation.x, cabeza_deseada, factor)

	var zoom_objetivo: float = zoom_correr if Input.is_action_pressed("sprint") else zoom_por_defecto
	zoom_actual = lerpf(zoom_actual, zoom_objetivo, factor)
	brazo_camara.spring_length = zoom_actual

	# El abreboca del tiro: sube de golpe al disparar y vuelve a fov_base
	# con el mismo damping que el resto de la camara.
	fov_kick = lerpf(fov_kick, 0.0, factor)
	if camara != null:
		camara.fov = fov_base + fov_kick


# ---------------------------------------------------------------------------
# Sonido: el nodo del grupo "sonido" manda, y todo se llama con guarda para
# que funcione aunque todavia no exista.
# ---------------------------------------------------------------------------
func _obtener_sonido() -> Node:
	var arbol: SceneTree = get_tree()
	if arbol == null:
		return null
	var candidatos: Array[Node] = arbol.get_nodes_in_group("sonido")
	if candidatos.size() > 0:
		return candidatos[0]
	return null


func _llamar_sonido(metodo: String) -> void:
	var s: Node = _obtener_sonido()
	if s != null and s.has_method(metodo):
		s.call(metodo)
