extends SceneTree

# Test estructural de scenes/test_level.tscn y scenes/player.tscn
# Uso: godot --headless --path . -s res://verificar.gd
# Imprime OK o FALTA por cada punto y cierra con 0 o 1.
# Regla: cada punto tiene que poder FALLAR. Si un comprobador no puede
# fallar, no sirve (eso fue lo que tapo los bugs de v0.1).

const RUTA_NIVEL: String = "res://scenes/test_level.tscn"
const RUTA_JUGADOR: String = "res://scenes/player.tscn"
const RUTA_SCRIPTS: String = "res://scripts"
const RUTA_VIDA: String = "res://scripts/vida.gd"

# Scripts que la estructura del plan manda que existan. Se amplia en cada tanda.
const SCRIPTS_ESPERADOS: Array[String] = [
	"res://scripts/player.gd",
	"res://scripts/pistol.gd",
	"res://scripts/vida.gd",
	"res://scripts/objetivo.gd",
	"res://scripts/hud.gd",
	"res://scripts/sonido.gd",
	"res://scripts/partida.gd",
	"res://scripts/enemigo.gd",
	"res://scripts/gato.gd",
	"res://scripts/proyectil.gd",
]

# Nodos directos del nivel (se amplia en cada tanda).
const NODOS_NIVEL: Array[String] = ["Suelo", "Luz", "Entorno"]

# Nodos que player.gd localiza con su funcion auxiliar "buscar": primero en la
# raiz del jugador y luego bajo "Modelo". Este test usa EXACTAMENTE la misma
# logica: si los dos caminos no coinciden, el test tiene que fallar.
const NODOS_OBLIGATORIOS: Array[String] = [
	"CollisionShape3D", "Modelo", "SpringArm3D", "Pistola",
	"RayCastPared", "RayCastTecho", "Vida",
]
const NODOS_OPCIONALES: Array[String] = [
	"Cuerpo", "Cabeza", "Cola", "Pata1", "Pata2", "Pata3", "Pata4",
]

# Capas del apartado 2bis del plan.
const CAPA_JUGADOR: int = 2
const MASCARA_JUGADOR: int = 9
const MASCARA_PISTOLA: int = 13
const MASCARA_BRAZO: int = 1

var errores: int = 0
var avisos: int = 0
var nivel_instanciado: Node = null


func _initialize() -> void:
	_comprobar_scripts()
	_comprobar_escena()
	_comprobar_jugador()
	await _prueba_juego()
	_resumen()


# ---------------------------------------------------------------------------
# Punto 1: todos los scripts del proyecto compilan.
# load() devuelve null o un GDScript que no puede instanciarse ante un error
# de parseo. Este punto es el que le da dientes al comando 1 del plan.
# ---------------------------------------------------------------------------
func _comprobar_scripts() -> void:
	var encontrados: Array[String] = _scripts_del_proyecto()

	for esperado: String in SCRIPTS_ESPERADOS:
		if not encontrados.has(esperado):
			_falta(1, "Scripts del proyecto", ["no existe %s" % esperado])

	if encontrados.is_empty():
		_falta(1, "Scripts del proyecto", ["no hay ningun .gd en %s" % RUTA_SCRIPTS])
		return

	var rotos: Array[String] = []
	for ruta: String in encontrados:
		var recurso: Resource = load(ruta)
		if recurso == null:
			rotos.append("%s (load() -> null)" % ruta.get_file())
			continue
		var guion: GDScript = recurso as GDScript
		if guion == null:
			rotos.append("%s (no es GDScript)" % ruta.get_file())
		elif not guion.can_instantiate():
			rotos.append("%s (can_instantiate() -> false)" % ruta.get_file())

	if rotos.is_empty():
		_ok(1, "%d scripts compilan" % encontrados.size())
	else:
		_falta(1, "Scripts del proyecto", rotos)


# ---------------------------------------------------------------------------
# Punto 2 a 4: la escena principal carga, se instancia y tiene su geometria.
# ---------------------------------------------------------------------------
func _comprobar_escena() -> void:
	var escena: PackedScene = load(RUTA_NIVEL) as PackedScene
	if escena == null:
		_falta(2, "La escena %s carga" % RUTA_NIVEL, ["load() -> null"])
		_falta(3, "Grupos 'suelo' y 'pared'", ["no hay escena"])
		_falta(4, "Nodos basicos del nivel", ["no hay escena"])
		return

	var nivel: Node = escena.instantiate()
	if nivel == null:
		_falta(2, "La escena %s carga" % RUTA_NIVEL, ["instantiate() -> null"])
		return

	root.add_child(nivel)
	nivel_instanciado = nivel
	_ok(2, "La escena %s carga y se instancia" % RUTA_NIVEL)

	var n_suelo: int = _contar_grupo(nivel, "suelo")
	var n_pared: int = _contar_grupo(nivel, "pared")
	var faltan_grupos: Array[String] = []
	if n_suelo < 1:
		faltan_grupos.append("al menos 1 en 'suelo' (hay %d)" % n_suelo)
	if n_pared < 3:
		faltan_grupos.append("al menos 3 en 'pared' (hay %d)" % n_pared)
	_reportar(3, "Grupos 'suelo' (>=1) y 'pared' (>=3)", faltan_grupos)

	var faltan_nivel: Array[String] = []
	for nombre: String in NODOS_NIVEL:
		if nivel.get_node_or_null(nombre) == null:
			faltan_nivel.append(nombre)
	_reportar(4, "Nodos basicos del nivel", faltan_nivel)


# ---------------------------------------------------------------------------
# Punto 5 a 10: el jugador.
# ---------------------------------------------------------------------------
func _comprobar_jugador() -> void:
	var escena: PackedScene = load(RUTA_JUGADOR) as PackedScene
	if escena == null:
		_falta(5, "La escena %s carga" % RUTA_JUGADOR, ["load() -> null"])
		_falta(6, "Nodos del jugador (raiz y Modelo)", ["no hay escena"])
		_falta(7, "Camara3D bajo SpringArm3D", ["no hay escena"])
		_falta(8, "Pistola con disparar() y RayCast3D con mascara 13", ["no hay escena"])
		_falta(9, "Capas del jugador: layer %d / mask %d" % [CAPA_JUGADOR, MASCARA_JUGADOR], ["no hay escena"])
		_falta(10, "Nodo Vida con scripts/vida.gd y recibir_dano()", ["no hay escena"])
		return

	var jugador: Node = escena.instantiate()
	if jugador == null:
		_falta(5, "La escena %s carga" % RUTA_JUGADOR, ["instantiate() -> null"])
		return
	root.add_child(jugador)
	_ok(5, "La escena %s carga y se instancia" % RUTA_JUGADOR)

	# Punto 6: nodos en la raiz o bajo Modelo, con la misma logica que buscar().
	var faltan: Array[String] = []
	for nombre: String in NODOS_OBLIGATORIOS:
		if _buscar_en(jugador, nombre) == null:
			faltan.append(nombre)
	for nombre: String in NODOS_OPCIONALES:
		if _buscar_en(jugador, nombre) == null:
			faltan.append("%s (opcional)" % nombre)
	_reportar(6, "Nodos del jugador en la raiz o bajo Modelo", faltan)

	# Punto 7: la camara cuelga del brazo elastico y solo mira el escenario.
	var brazo: Node = jugador.get_node_or_null("SpringArm3D")
	var faltan_cam: Array[String] = []
	if brazo == null:
		faltan_cam.append("SpringArm3D")
	else:
		if brazo.get_node_or_null("Camara3D") == null:
			faltan_cam.append("Camara3D bajo SpringArm3D")
		if brazo.get("collision_mask") != MASCARA_BRAZO:
			faltan_cam.append("collision_mask del brazo es %s y debe ser %d" % [str(brazo.get("collision_mask")), MASCARA_BRAZO])
	_reportar(7, "Camara3D bajo SpringArm3D", faltan_cam)

	# Punto 8: la pistola, su rayo y su mascara.
	var faltan_pistola: Array[String] = []
	var pistola: Node = _buscar_en(jugador, "Pistola")
	if pistola == null:
		faltan_pistola.append("Pistola")
	else:
		if not pistola.has_method("disparar"):
			faltan_pistola.append("metodo disparar()")
		var rayo: Node = pistola.get_node_or_null("RayCast3D")
		if rayo == null:
			faltan_pistola.append("hijo RayCast3D")
		else:
			var mascara: int = int(rayo.get("collision_mask"))
			if mascara != MASCARA_PISTOLA:
				faltan_pistola.append("collision_mask del rayo es %d y debe ser %d" % [mascara, MASCARA_PISTOLA])
	_reportar(8, "Pistola con disparar() y RayCast3D con mascara 13", faltan_pistola)

	# Punto 9: capas del cuerpo del jugador.
	var faltan_capas: Array[String] = []
	if jugador.get("collision_layer") != CAPA_JUGADOR:
		faltan_capas.append("collision_layer es %s y debe ser %d" % [str(jugador.get("collision_layer")), CAPA_JUGADOR])
	if jugador.get("collision_mask") != MASCARA_JUGADOR:
		faltan_capas.append("collision_mask es %s y debe ser %d" % [str(jugador.get("collision_mask")), MASCARA_JUGADOR])
	_reportar(9, "Capas del jugador: layer 2 / mask 9", faltan_capas)

	# Punto 10: el nodo Vida, su script y su metodo de dano.
	var faltan_vida: Array[String] = []
	var vida: Node = _buscar_en(jugador, "Vida")
	if vida == null:
		faltan_vida.append("nodo Vida")
	else:
		var guion: Script = vida.get_script() as Script
		if guion == null:
			faltan_vida.append("Vida no lleva script")
		elif String(guion.resource_path) != RUTA_VIDA:
			faltan_vida.append("el script de Vida es %s y debe ser %s" % [guion.resource_path, RUTA_VIDA])
		if not vida.has_method("recibir_dano"):
			faltan_vida.append("Vida no expone recibir_dano()")
		if not vida.has_signal("vida_cambiada"):
			faltan_vida.append("Vida no emite vida_cambiada")
	_reportar(10, "Nodo Vida con scripts/vida.gd y recibir_dano()", faltan_vida)

	# Este jugador es solo una prueba estructural y hay que borrarlo ya: si se
	# queda en el arbol, su Camara3D (current = true) le roba el turno a la
	# camara del nivel y los disparos salen desde otro sitio.
	jugador.free()


# Igual que la funcion "buscar" de player.gd: raiz, luego Modelo.
func _buscar_en(jugador: Node, nombre: String) -> Node:
	var nodo: Node = jugador.get_node_or_null(nombre)
	if nodo == null:
		nodo = jugador.get_node_or_null("Modelo/" + nombre)
	return nodo


# ---------------------------------------------------------------------------
# Punto 11 a 15: prueba de juego. Simula el teclado y comprueba que el gato
# hace lo que debe: aterrizar, caminar, no girar al strafear, girar 180 al
# correr de espaldas y saltar. Un test que no puede fallar no sirve.
# ---------------------------------------------------------------------------
func _prueba_juego() -> void:
	if nivel_instanciado == null or nivel_instanciado.get_node_or_null("Jugador") == null:
		var detalle: Array[String] = ["no hay nodo Jugador en el nivel"]
		_falta(11, "El jugador aterriza y se queda en el suelo", detalle)
		_falta(12, "El jugador avanza al mantener W", detalle)
		_falta(13, "El cuerpo NO gira al strafear (A)", detalle)
		_falta(14, "El cuerpo gira 180 al correr de espaldas (S)", detalle)
		_falta(15, "El jugador salta con Espacio", detalle)
		_falta(16, "El dash impulsa a la fuerza exportada", detalle)
		_falta(17, "Agacharse de verdad: el cuerpo baja y las patas se pliegan", detalle)
		_falta(18, "El jugador trepa la pared (climb)", detalle)
		_falta(19, "El raton gira la camara", detalle)
		_falta(20, "El raton esta bien montado (capa 4, Vida, recibir_dano)", detalle)
		_falta(21, "El disparo desde la camara hace dano al blanco", detalle)
		_falta(22, "Cuatro disparos destruyen el blanco", detalle)
		_falta(23, "HUD: reticula que se abre al disparar y barra de vida", detalle)
		_falta(24, "HUD: destello de dano y barra que baja", detalle)
		_falta(25, "Sonido generado por codigo (12 flujos WAV)", detalle)
		_falta(26, "Partida conectada: cuenta los blancos destruidos", detalle)
		_falta(27, "La escena res://scenes/enemigo.tscn esta bien montada", detalle)
		_falta(28, "El enemigo persigue, golpea y se abate (derribado)", detalle)
		_falta(29, "Siete enemigos en el nivel, repartidos y en el suelo", detalle)
		_falta(30, "Contadores de enemigos abatidos y restantes en el HUD", detalle)
		_falta(31, "Victoria al limpiar todos los enemigos", detalle)
		_falta(32, "Derrota al llegar a cero la vida, barra y color de alarma", detalle)
		_falta(33, "El reproductor 3D del impacto se borra solo", detalle)
		_falta(34, "Particulas de polvo (correr, aterrizar) y rastro del dash", detalle)
		_falta(35, "Sonido de enemigo (3 avisos) y viento ambiente en bucle", detalle)
		_falta(36, "Fase 8: mira con color y recarga del dash en el HUD", detalle)
		_falta(37, "La mira refleja el rayo (blanco, muro o aire)", detalle)
		_falta(38, "La cabeza del gato gira entera y sigue la camara", detalle)
		_falta(39, "Barra de vida flotante del enemigo", detalle)
		_falta(40, "La camara de hombro se queda siempre del mismo lado", detalle)
		_falta(41, "La pistola cuelga del Modelo y el canon sigue a la mirada", detalle)
		_falta(42, "Disparo alineado: gira hacia la mirada y nunca se pierde el tiro", detalle)
		_falta(43, "Gato compartido cuadrupeda a escala con pinta propia", detalle)
		_falta(44, "Pulido del disparo: escala de gato, fogonazo, trazador y retroceso", detalle)
		_falta(45, "HUD: marcador X, pop del anillo y tick al danar", detalle)
		_falta(46, "Camara: FOV del tiro y sacudida que se apagan solas", detalle)
		_falta(47, "Muerte del enemigo: destello que se apaga y poof que se borra", detalle)
		_falta(48, "Casa completa: bano, dos ventanas, siete huecos y SSAO", detalle)
		_falta(49, "Disparo a distancia con punteria buena y mala", detalle)
		_falta(50, "Ambiente PSX: niebla, cielo, ventanas y filtro", detalle)
		_falta(51, "Decorado 2D y destello del enemigo", detalle)
		_falta(52, "GUI: cuarto actual y minimapa en el HUD", detalle)
		_falta(53, "Mapa dinamico: patrulla enemiga y ratones que huyen", detalle)
		_falta(54, "Rojos a distancia y naranjas a cuchillo", detalle)
		_falta(55, "Casa grande y viva: puertas, pelota y cortinas", detalle)
		_falta(56, "Menu dev de iluminacion: presets, filtros y ayuda", detalle)
		_falta(57, "El melee no atraviesa muros ni alturas", detalle)
		return

	var jugador: Node = nivel_instanciado.get_node_or_null("Jugador")
	var n3: Node3D = jugador.get_node_or_null("Modelo") as Node3D

	# Los siete enemigos del nivel se quedan quietos durante la prueba: si no,
	# llegarian al jugador en los 10 s que dura el test y arruinarian las
	# comprobaciones de vida del HUD. La IA se prueba aparte con el 28.
	# OJO: justo despues de add_child(), get_nodes_in_group() todavia esta
	# vacio (se llena en el primer frame), asi que se busca por is_in_group()
	# nodo a nodo, que si esta listo desde el instante cero.
	for hijo: Node in nivel_instanciado.get_children():
		if hijo.is_in_group("enemigo"):
			hijo.process_mode = Node.PROCESS_MODE_DISABLED

	# 11. Asentar en el suelo.
	await _frames(60)
	var faltan: Array[String] = []
	var altura: Vector3 = jugador.global_position
	if not bool(jugador.call("is_on_floor")):
		faltan.append("no esta apoyado tras 60 frames")
	if not is_finite(altura.y) or altura.y < -2.0 or altura.y > 3.0:
		faltan.append("altura %.2f fuera de rango" % altura.y)
	_reportar(11, "El jugador aterriza y se queda en el suelo", faltan)

	# 12. W avanza.
	var antes: Vector3 = jugador.global_position
	Input.action_press("move_forward")
	await _frames(45)
	Input.action_release("move_forward")
	await _frames(5)
	var faltan_w: Array[String] = []
	var distancia: float = antes.distance_to(jugador.global_position)
	if distancia < 1.0:
		faltan_w.append("solo %.2f m en 45 frames" % distancia)
	_reportar(12, "El jugador avanza al mantener W", faltan_w)

	# 13. A strafea sin girar el cuerpo.
	Input.action_press("move_left")
	await _frames(45)
	Input.action_release("move_left")
	var faltan_a: Array[String] = []
	if n3 == null:
		faltan_a.append("no hay nodo Modelo")
	else:
		var giro_a: float = absf(n3.rotation.y)
		if giro_a > 0.3:
			faltan_a.append("el cuerpo gira %.2f rad al strafear" % giro_a)
	_reportar(13, "El cuerpo NO gira al strafear (A)", faltan_a)

	# 14. S corre de espaldas: el cuerpo gira 180.
	Input.action_press("move_back")
	await _frames(45)
	Input.action_release("move_back")
	var faltan_s: Array[String] = []
	if n3 == null:
		faltan_s.append("no hay nodo Modelo")
	else:
		var giro_s: float = absf(n3.rotation.y)
		if absf(giro_s - PI) > 0.6:
			faltan_s.append("el cuerpo esta a %.2f rad, esperado ~3.14" % giro_s)
	_reportar(14, "El cuerpo gira 180 al correr de espaldas (S)", faltan_s)

	# 15. Espacio salta.
	await _frames(40)
	var suelo_y: float = jugador.global_position.y
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	var max_y: float = suelo_y
	for i: int in 45:
		await physics_frame
		max_y = maxf(max_y, jugador.global_position.y)
	Input.action_release("move_back")
	var faltan_salto: Array[String] = []
	var altura_salto_real: float = max_y - suelo_y
	var salto_min15: float = float(jugador.get("altura_salto")) * 0.7
	if altura_salto_real < salto_min15:
		faltan_salto.append(
			"solo subio %.2f m (minimo %.2f)" % [altura_salto_real, salto_min15]
		)
	_reportar(15, "El jugador salta con Espacio", faltan_salto)

	# 16. Dash: la velocidad pica a fuerza_dash (20 m/s).
	await _frames(40)
	Input.action_press("dash")
	await _frames(3)
	var faltan_dash: Array[String] = []
	var vel: Vector3 = jugador.get("velocity")
	var fuerza16: float = float(jugador.get("fuerza_dash"))
	if vel.length() < fuerza16 * 0.75:
		faltan_dash.append(
			"velocidad %.2f m/s, esperado ~%.1f" % [vel.length(), fuerza16]
		)
	Input.action_release("dash")
	_reportar(16, "El dash impulsa a la fuerza exportada", faltan_dash)
	await _frames(45)

	# 17. Agacharse DE VERDAD: el cuerpo baja y las patas se pliegan (la
	# escala no se toca: lo que se apachurra es la hitbox). Agachado cabe
	# bajo la cama, y al soltar todo vuelve a su sitio.
	var forma: CapsuleShape3D = jugador.get("forma_capsula")
	var alto_pie17: float = float(jugador.get("altura_de_pie"))
	var alto_agach17: float = float(jugador.get("altura_agachado"))
	var bajada17: float = float(jugador.get("bajada_agachado"))
	var pliegue17: float = float(jugador.get("pliegue_agachado"))
	var base17: float = float(jugador.get("modelo_y_base"))
	var modelo17: Node3D = jugador.get("modelo") as Node3D
	var escala_antes17: float = 0.8
	if modelo17 != null:
		escala_antes17 = modelo17.scale.y
	var faltan_agachado: Array[String] = []
	Input.action_press("crouch")
	await _frames(3)
	if forma != null:
		# A los 3 frames la capsula tiene que ir EN CAMINO (proporcion del
		# recorrido), nunca llegada: eso distingue una transicion de un salto
		# en seco.
		var rango17: float = alto_pie17 - alto_agach17
		var parte17: float = (alto_pie17 - forma.height) / maxf(rango17, 0.001)
		if parte17 < 0.15 or parte17 > 0.85:
			faltan_agachado.append(
				"transicion en seco: %.0f%% del recorrido a los 3 frames (%.3f de %.3f)" % [
					parte17 * 100.0, alto_pie17 - forma.height, rango17
				]
			)
	await _frames(12)
	if forma == null:
		faltan_agachado.append("no hay forma_capsula")
	else:
		if absf(forma.height - alto_agach17) > 0.05:
			faltan_agachado.append(
				"capsula a %.2f, esperado %.2f" % [forma.height, alto_agach17]
			)
		if not bool(jugador.get("agachado")):
			faltan_agachado.append("agachado sigue en false")
		# Agachado tiene que caber bajo la cama (hueco del tablon).
		var cama17: Node = nivel_instanciado.get_node_or_null("Cama")
		var tablon17: CollisionShape3D = null
		if cama17 != null:
			tablon17 = cama17.get_node_or_null("Tablon") as CollisionShape3D
		if tablon17 == null or tablon17.shape == null:
			faltan_agachado.append("no se puede medir el hueco de la cama")
		else:
			var hueco17: float = tablon17.position.y - (tablon17.shape as BoxShape3D).size.y * 0.5
			if alto_agach17 >= hueco17 - 0.02:
				faltan_agachado.append(
					"agachado a %.2f no cabe bajo la cama (hueco %.2f)" % [alto_agach17, hueco17]
				)
	if modelo17 == null:
		faltan_agachado.append("no hay modelo")
	else:
		# El cuerpo BAJA (no se aplasta) y las patas SE PLIEGAN.
		var bajada_real17: float = base17 - modelo17.position.y
		if bajada_real17 < bajada17 * 0.6:
			faltan_agachado.append(
				"el cuerpo no baja (%.3f -> %.3f, esperado %.3f)" % [
					base17, modelo17.position.y, bajada17
				]
			)
		var pata17: Node3D = modelo17.get_node_or_null("Pata1") as Node3D
		if pata17 == null:
			faltan_agachado.append("el modelo no tiene Pata1")
		elif absf(pata17.rotation.x) < pliegue17 * 0.6:
			faltan_agachado.append(
				"las patas no se pliegan (rot.x=%.2f)" % pata17.rotation.x
			)
		if absf(modelo17.scale.y - escala_antes17) > 0.03:
			faltan_agachado.append("el cuerpo se apachurra (scale.y=%.2f)" % modelo17.scale.y)
	Input.action_release("crouch")
	await _frames(15)
	if forma != null and absf(forma.height - alto_pie17) > 0.05:
		faltan_agachado.append("no vuelve a ponerse de pie (%.2f)" % forma.height)
	if modelo17 != null:
		if absf(modelo17.position.y - base17) > 0.03:
			faltan_agachado.append("el cuerpo no vuelve a su altura (%.3f)" % modelo17.position.y)
		var pata_vuelta17: Node3D = modelo17.get_node_or_null("Pata1") as Node3D
		if pata_vuelta17 != null and absf(pata_vuelta17.rotation.x) > 0.1:
			faltan_agachado.append("las patas no se despliegan (rot.x=%.2f)" % pata_vuelta17.rotation.x)
	_reportar(17, "Agacharse de verdad: el cuerpo baja y las patas se pliegan", faltan_agachado)

	# 18. Trepar: el armario del dormitorio, empujandolo con D + climb.
	jugador.global_position = Vector3(1.35, 0, -0.3)
	await _frames(12)
	Input.action_press("move_right")
	Input.action_press("climb")
	await _frames(30)
	Input.action_release("climb")
	Input.action_release("move_right")
	var faltan_trepar: Array[String] = []
	var subida: float = jugador.global_position.y
	if subida < 1.0:
		faltan_trepar.append("solo llego a %.2f m, esperado ~1.6" % subida)
	_reportar(18, "El jugador trepa la pared (climb)", faltan_trepar)
	await _frames(45)

	# 19. Camara: el raton gira el brazo.
	var brazo: Node3D = jugador.get_node_or_null("SpringArm3D") as Node3D
	var faltan_camara: Array[String] = []
	if brazo == null:
		faltan_camara.append("no hay SpringArm3D")
	else:
		var yaw_antes: float = brazo.rotation.y
		var raton: InputEventMouseMotion = InputEventMouseMotion.new()
		raton.relative = Vector2(300, 0)
		Input.parse_input_event(raton)
		await _frames(30)
		var esperado: float = yaw_antes - 300.0 * 0.0022
		var girado: float = brazo.rotation.y
		if absf(girado - esperado) > 0.1:
			faltan_camara.append("yaw %.2f, esperado %.2f" % [girado, esperado])
	_reportar(19, "El raton gira la camara", faltan_camara)

	# 20. Blancos bien montados (instancia propia: el nivel ya no trae).
	var faltan_blancos: Array[String] = []
	var escena_blanco20: PackedScene = load("res://scenes/objetivo.tscn") as PackedScene
	if escena_blanco20 == null:
		faltan_blancos.append("no carga res://scenes/objetivo.tscn")
	else:
		var blanco0: Node = escena_blanco20.instantiate()
		if blanco0 == null:
			faltan_blancos.append("instantiate() -> null")
		else:
			if not blanco0.has_method("recibir_dano"):
				faltan_blancos.append("no tiene recibir_dano()")
			if blanco0.get_node_or_null("Vida") == null:
				faltan_blancos.append("no tiene nodo Vida")
			if int(blanco0.get("collision_layer")) != 4:
				faltan_blancos.append("capa %d, esperado 4" % int(blanco0.get("collision_layer")))
			if int(blanco0.get("collision_mask")) != 1:
				faltan_blancos.append("mascara %d, esperado 1" % int(blanco0.get("collision_mask")))

			# C2: es un raton de juguete de 0.25 m a escala de gato, con la caja
			# apoyada en el suelo, no un poste de 2.4 m para gente.
			var col_raton: CollisionShape3D = blanco0.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col_raton == null:
				faltan_blancos.append("falta CollisionShape3D")
			else:
				var caja_raton: BoxShape3D = col_raton.shape as BoxShape3D
				if caja_raton == null:
					faltan_blancos.append("la caja del blanco no es BoxShape3D")
				else:
					var lado_raton: float = maxf(
						caja_raton.size.x, maxf(caja_raton.size.y, caja_raton.size.z)
					)
					if lado_raton > 0.35:
						faltan_blancos.append("caja de %.2f m: no es un raton de 0.25" % lado_raton)
				if col_raton.position.y > 0.2:
					faltan_blancos.append("centro a %.2f: el raton va por el suelo" % col_raton.position.y)
			if blanco0.get_node_or_null("Cabeza") == null:
				faltan_blancos.append("falta la cabeza del raton")
			blanco0.free()
	_reportar(20, "El raton esta bien montado (capa 4, Vida, recibir_dano)", faltan_blancos)

	# 21 y 22. Disparo desde la camara: primero baja la vida, cuatro disparos
	# acaban con el blanco (instancia propia: el nivel ya no trae).
	var faltan_disparo: Array[String] = []
	var faltan_muerte: Array[String] = []
	var blanco: Node = _crear_raton(Vector3(0, 0.1, 0.5))
	if blanco == null:
		faltan_disparo.append("no se puede instanciar el raton")
		faltan_muerte.append("no se puede instanciar el raton")
		_reportar(21, "El disparo desde la camara hace dano al blanco", faltan_disparo)
		_reportar(22, "Cuatro disparos destruyen el blanco", faltan_muerte)
	else:
		var pistola: Node = _buscar_en(jugador, "Pistola")
		var camara: Camera3D = jugador.get_node_or_null("SpringArm3D/Camara3D") as Camera3D
		if pistola == null or camara == null:
			faltan_disparo.append("falta la pistola o la camara")
			faltan_muerte.append("falta la pistola o la camara")
		else:
			jugador.global_position = Vector3(0, 1, 0.5)
			# Camara a cero: en el cuarto pequeno la vista tiene que quedar
			# mirando al corredor central, o el rayo de 1 m pega en un mueble.
			jugador.set("yaw_deseado", 0.0)
			jugador.set("yaw_suave", 0.0)
			# 30 frames: 14 de caida + amortiguacion de la camara. Con el
			# blanco tan pequeno, si la camara se mueve al colocarlo, el tiro
			# ya no pasa por el raton.
			await _frames(30)
			_colocar_blanco_en_punteria(blanco, camara)
			await _frames(3)

			var vida_antes: int = int(blanco.call("vida_actual"))
			pistola.call("disparar")
			await _frames(4)
			var vida_despues: int = int(blanco.call("vida_actual"))
			if vida_despues >= vida_antes:
				faltan_disparo.append("vida %d -> %d: no bajo" % [vida_antes, vida_despues])
			_reportar(21, "El disparo desde la camara hace dano al blanco", faltan_disparo)

			var contador: Array[int] = []
			blanco.connect("destruido", func() -> void: contador.append(1))
			# El raton es fisica de verdad y cae al suelo: re-encarar antes de
			# cada tiro o los siguientes pasarian por encima.
			for i: int in 3:
				await _frames(16)
				_colocar_blanco_en_punteria(blanco, camara)
				await _frames(2)
				pistola.call("disparar")
			await _frames(6)
			if not bool(blanco.get("muerto")):
				faltan_muerte.append("sigue vivo con vida %d" % int(blanco.call("vida_actual")))
			if contador.is_empty():
				faltan_muerte.append("no emitio la senal destruido")
		_reportar(22, "Cuatro disparos destruyen el blanco", faltan_muerte)
		blanco.queue_free()
		await _frames(2)

	# 23. HUD: la reticula se abre con UN tween al disparar y la barra pinta
	# la vida completa antes de recibir dano.
	var faltan_hud: Array[String] = []
	var hud: Node = nivel_instanciado.get_node_or_null("HUD/Reticula")
	var pistola_hud: Node = _buscar_en(jugador, "Pistola")
	if hud == null:
		faltan_hud.append("falta el nodo HUD/Reticula en el nivel")
	elif pistola_hud == null:
		faltan_hud.append("falta la pistola del jugador")
	else:
		await _frames(20)
		var prop_antes: float = float(hud.get("prop_vida"))
		pistola_hud.call("disparar")
		await _frames(2)
		if float(hud.get("apertura")) <= 0.0:
			faltan_hud.append("la reticula no se abre al disparar")
		if absf(prop_antes - 1.0) > 0.01:
			faltan_hud.append("la barra arranca en %.2f y debe ser 1.0" % prop_antes)
	_reportar(23, "HUD: reticula que se abre al disparar y barra de vida", faltan_hud)

	# 24. HUD: destello al recibir dano y barra que baja al 70%.
	var faltan_dano_hud: Array[String] = []
	if hud == null:
		faltan_dano_hud.append("no hay HUD")
	else:
		jugador.call("recibir_dano", 30)
		await _frames(2)
		if float(hud.get("destello_dano")) <= 0.0:
			faltan_dano_hud.append("no hay destello de dano")
		var prop_dano: float = float(hud.get("prop_vida"))
		if absf(prop_dano - 0.7) > 0.02:
			faltan_dano_hud.append("la barra marca %.2f y deberia ser 0.70" % prop_dano)
	_reportar(24, "HUD: destello de dano y barra que baja", faltan_dano_hud)

	# 25. Sonido: nodo en el grupo, todos los metodos y flujos WAV con datos.
	var faltan_sonido: Array[String] = []
	var sonido: Node = null
	for candidato: Node in get_nodes_in_group("sonido"):
		sonido = candidato
		break
	if sonido == null:
		faltan_sonido.append("no hay ningun nodo en el grupo sonido")
	else:
		var metodos: Array[String] = [
			"reproducir_disparo", "reproducir_paso", "reproducir_dash",
			"reproducir_trepar", "reproducir_maullido", "reproducir_maullido_dano",
			"reproducir_impacto", "reproducir_ambiente"
		]
		for metodo: String in metodos:
			if not sonido.has_method(metodo):
				faltan_sonido.append("falta %s()" % metodo)
		var flujos: Dictionary = sonido.get("flujos")
		if flujos.is_empty():
			faltan_sonido.append("no ha generado ningun AudioStreamWAV")
		else:
			for nombre: String in flujos:
				var flujo: AudioStreamWAV = flujos[nombre] as AudioStreamWAV
				if flujo == null or flujo.data.is_empty():
					faltan_sonido.append("el flujo %s esta vacio" % nombre)
				elif flujo.data.size() < 1000:
					faltan_sonido.append("el flujo %s solo tiene %d bytes" % [nombre, flujo.data.size()])
		# Que suene de verdad, sin explotar.
		sonido.call("reproducir_disparo")
		sonido.call("reproducir_paso")
		sonido.call("reproducir_maullido")
		sonido.call("reproducir_impacto", Vector3.ZERO)
		await _frames(3)
	_reportar(25, "Sonido generado por codigo (12 flujos WAV)", faltan_sonido)

	# 26. Partida: conectada al jugador y contando lo que se destruye.
	var faltan_partida: Array[String] = []
	var partida: Node = nivel_instanciado.get_node_or_null("Partida")
	if partida == null:
		faltan_partida.append("falta el nodo Partida en el nivel")
	else:
		if not partida.has_method("reiniciar"):
			faltan_partida.append("no tiene reiniciar()")
		if partida.get("vida_jugador") == null:
			faltan_partida.append("no ha conectado la vida del jugador")
		var raton_a26: Node = _crear_raton(Vector3(0, 0.1, -1.0))
		var raton_b26: Node = _crear_raton(Vector3(0.5, 0.1, -1.0))
		if raton_a26 == null or raton_b26 == null:
			faltan_partida.append("no se pueden instanciar ratones")
		else:
			raton_a26.connect("destruido", Callable(partida, "_al_destruir_blanco"))
			raton_b26.connect("destruido", Callable(partida, "_al_destruir_blanco"))
			var conteo_antes: int = int(partida.get("blancos_destruidos"))
			raton_b26.call("recibir_dano", 9999)
			await _frames(6)
			var conteo_despues: int = int(partida.get("blancos_destruidos"))
			if conteo_despues != conteo_antes + 1:
				faltan_partida.append("blancos_destruidos %d -> %d" % [conteo_antes, conteo_despues])
			raton_a26.queue_free()
			raton_b26.queue_free()
			await _frames(2)
	_reportar(26, "Partida conectada: cuenta los blancos destruidos", faltan_partida)

	# 27. La escena del enemigo esta bien montada (capas, grupos, senales).
	var faltan_enemigo: Array[String] = []
	var escena_enemigo: PackedScene = load("res://scenes/enemigo.tscn") as PackedScene
	if escena_enemigo == null:
		faltan_enemigo.append("load() -> null")
	else:
		var prueba_enemigo: Node = escena_enemigo.instantiate()
		if prueba_enemigo == null:
			faltan_enemigo.append("instantiate() -> null")
		else:
			var cuerpo: PhysicsBody3D = prueba_enemigo as PhysicsBody3D
			if cuerpo == null:
				faltan_enemigo.append("la raiz no es un PhysicsBody3D")
			else:
				if cuerpo.collision_layer != 8:
					faltan_enemigo.append("capa %d, esperado 8" % cuerpo.collision_layer)
				if cuerpo.collision_mask != 3:
					faltan_enemigo.append("mascara %d, esperado 3" % cuerpo.collision_mask)
			if not prueba_enemigo.is_in_group("enemigo"):
				faltan_enemigo.append("no esta en el grupo enemigo")
			for metodo: String in ["recibir_dano", "vida_actual"]:
				if not prueba_enemigo.has_method(metodo):
					faltan_enemigo.append("falta %s()" % metodo)
			if not prueba_enemigo.has_signal("derribado"):
				faltan_enemigo.append("no tiene la senal derribado")
			if int(prueba_enemigo.get("estado")) != 0:
				faltan_enemigo.append("estado inicial %s (deberia ser QUIETO)" % str(prueba_enemigo.get("estado")))
			if prueba_enemigo.get_node_or_null("Modelo/Cuerpo") == null:
				faltan_enemigo.append("falta la malla Modelo/Cuerpo")

			# C1: el enemigo es el MISMO gato del jugador (gato.tscn), con
			# capsula de su escala, rangos de gato y la barra a lomo.
			var modelo_en: Node = prueba_enemigo.get_node_or_null("Modelo")
			if modelo_en == null:
				faltan_enemigo.append("falta el nodo Modelo")
			elif modelo_en.get_script() == null or not String(
				(modelo_en.get_script() as Script).resource_path
			).ends_with("gato.gd"):
				faltan_enemigo.append("el Modelo no es el gato compartido gato.gd")
			var colision_en: Node = prueba_enemigo.get_node_or_null("Colision")
			if colision_en == null:
				faltan_enemigo.append("falta la capsula Colision")
			else:
				var forma_en: CapsuleShape3D = (colision_en as CollisionShape3D).shape as CapsuleShape3D
				if forma_en == null:
					faltan_enemigo.append("Colision no tiene CapsuleShape3D")
				elif absf(forma_en.height - 0.34) > 0.015:
					faltan_enemigo.append("capsula a %.2f, el gato enemigo mide 0.34" % forma_en.height)
			var deteccion_en: float = float(prueba_enemigo.get("alcance_deteccion"))
			if absf(deteccion_en - 8.0) > 0.01:
				faltan_enemigo.append("deteccion %.1f m, esperado 8 (escala de gato)" % deteccion_en)
			var ataque_en: float = float(prueba_enemigo.get("alcance_ataque"))
			if absf(ataque_en - 0.6) > 0.01:
				faltan_enemigo.append("ataque %.1f m, esperado 0.6 (escala de gato)" % ataque_en)
			if float(prueba_enemigo.get("altura_barra_vida")) > 0.8:
				faltan_enemigo.append(
					"barra a %.2f: no esta sobre el lomo" % float(prueba_enemigo.get("altura_barra_vida"))
				)
			prueba_enemigo.free()
	_reportar(27, "La escena res://scenes/enemigo.tscn esta bien montada", faltan_enemigo)

	# 28. La IA minima: se acerca, avisa y golpea, y al morir emite derribado.
	var faltan_ia: Array[String] = []
	if escena_enemigo == null:
		faltan_ia.append("no carga res://scenes/enemigo.tscn")
	else:
		var enemigo: Node = escena_enemigo.instantiate()
		nivel_instanciado.add_child(enemigo)
		var posicion_inicial: Vector3 = jugador.global_position + Vector3(0.0, 0.5, -2.3)
		enemigo.global_position = posicion_inicial

		# Debe cerrar la distancia solo, sin ayuda.
		await _frames(40)
		var dist_enemigo: float = Vector2(
			enemigo.global_position.x - jugador.global_position.x,
			enemigo.global_position.z - jugador.global_position.z
		).length()
		if dist_enemigo >= 1.5:
			faltan_ia.append("seguia a 2.3 m y sigue a %.1f m (no persigue)" % dist_enemigo)

		# Pegado al jugador: aviso y golpe. A 0.8 m le entra de nuevo en el
		# rango de ataque, y se reinicia el estado para que el enfriamiento
		# del golpe anterior no congele la prueba entera.
		enemigo.global_position = jugador.global_position + Vector3(0.8, 0.5, 0.0)
		enemigo.set("estado", 1)
		enemigo.set("enfriamiento_ataque", 0.0)
		enemigo.set("tiempo_aviso", 0.0)
		var vida_antes: int = int(jugador.call("vida_actual"))
		await _frames(60)
		var vida_despues: int = int(jugador.call("vida_actual"))
		if vida_despues >= vida_antes:
			faltan_ia.append("vida del jugador %d -> %d: no golpeo" % [vida_antes, vida_despues])

		# Y al acabar con el, emite derribado.
		var abatidos: Array[int] = []
		enemigo.connect("derribado", func() -> void: abatidos.append(1))
		enemigo.call("recibir_dano", 9999)
		await _frames(3)
		if abatidos.is_empty():
			faltan_ia.append("no emitio la senal derribado")
		if int(enemigo.call("vida_actual")) != 0:
			faltan_ia.append("sigue con vida %d" % int(enemigo.call("vida_actual")))
		enemigo.queue_free()
		await _frames(2)
	_reportar(28, "El enemigo persigue, golpea y se abate (derribado)", faltan_ia)

	# 29. Los siete enemigos del nivel, repartidos y con los pies en el suelo.
	var faltan_cinco: Array[String] = []
	var del_nivel: Array[Node] = []
	for candidato: Node in get_nodes_in_group("enemigo"):
		if is_instance_valid(candidato) and candidato.get_parent() == nivel_instanciado:
			del_nivel.append(candidato)
	if del_nivel.size() != 7:
		faltan_cinco.append("hay %d enemigos en el nivel (se esperaban 7)" % del_nivel.size())
	# Tipos: rojos a distancia, naranjas a cuchillo (de poco dano).
	var tipos29: Dictionary = {
		"Enemigo1": [false, true], "Enemigo2": [true, false],
		"Enemigo3": [false, true], "Enemigo4": [true, false],
		"Enemigo5": [false, true], "Enemigo6": [false, true],
		"Enemigo7": [true, false],
	}
	for enemigo_nivel29: Node in del_nivel:
		var esperado29: Array = tipos29.get(enemigo_nivel29.name, []) as Array
		if esperado29.is_empty():
			faltan_cinco.append("%s no es un enemigo conocido" % enemigo_nivel29.name)
		else:
			if bool(enemigo_nivel29.get("ataca_cuerpo_a_cuerpo")) != bool(esperado29[0]):
				faltan_cinco.append("%s con melee distinto al suyo" % enemigo_nivel29.name)
			if bool(enemigo_nivel29.get("dispara_a_distancia")) != bool(esperado29[1]):
				faltan_cinco.append("%s con disparo distinto al suyo" % enemigo_nivel29.name)
	for i: int in del_nivel.size():
		var enemigo_nivel: Node = del_nivel[i]
		if enemigo_nivel.global_position.y < -0.5 or enemigo_nivel.global_position.y > 2.0:
			faltan_cinco.append("%s esta a y=%.2f (deberia tocar el suelo)" % [
				enemigo_nivel.name, enemigo_nivel.global_position.y
			])
		for j: int in range(i + 1, del_nivel.size()):
			var a: Vector3 = enemigo_nivel.global_position
			var b: Vector3 = del_nivel[j].global_position
			var dist: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
			if dist < 1.2:
				faltan_cinco.append("%s y %s estan a %.1f m (pegadisimos, sin aire)" % [
					enemigo_nivel.name, del_nivel[j].name, dist
				])
	_reportar(29, "Siete enemigos en el nivel, repartidos y en el suelo", faltan_cinco)

	# 30. Contadores: la partida sabe cuantos enemigos hay y el HUD los refleja.
	var faltan_contadores: Array[String] = []
	if partida == null or hud == null:
		faltan_contadores.append("falta Partida o HUD")
	else:
		if int(partida.get("enemigos_totales")) != 7:
			faltan_contadores.append("enemigos_totales=%d (deberia ser 7)" % int(partida.get("enemigos_totales")))
		if hud.get("partida") == null:
			faltan_contadores.append("el HUD no ha encontrado Partida")
		var vivos: Array[Node] = []
		for hijo: Node in nivel_instanciado.get_children():
			if hijo.is_in_group("enemigo") and is_instance_valid(hijo):
				vivos.append(hijo)
		if vivos.is_empty():
			faltan_contadores.append("no queda ningun enemigo vivo")
		else:
			(vivos[0] as Node).call("recibir_dano", 9999)
			await _frames(6)
			if int(partida.get("enemigos_abatidos")) != 1:
				faltan_contadores.append("enemigos_abatidos=%d" % int(partida.get("enemigos_abatidos")))
			if int(hud.get("enemigos_abatidos")) != 1 or int(hud.get("enemigos_totales")) != 7:
				faltan_contadores.append("el HUD marca %d de %d abatidos" % [
					int(hud.get("enemigos_abatidos")), int(hud.get("enemigos_totales"))
				])
			if int(hud.get("fin_partida")) != 0:
				faltan_contadores.append("el HUD da la partida por terminada con enemigos vivos")
	_reportar(30, "Contadores de enemigos abatidos y restantes en el HUD", faltan_contadores)

	# 31. Victoria: abatir a todos cierra la partida y cambia la pantalla.
	var faltan_victoria: Array[String] = []
	if partida == null or hud == null:
		faltan_victoria.append("falta Partida o HUD")
	else:
		for hijo: Node in nivel_instanciado.get_children():
			if hijo.is_in_group("enemigo") and is_instance_valid(hijo):
				hijo.call("recibir_dano", 9999)
		await _frames(6)
		if not bool(partida.get("partida_ganada")):
			faltan_victoria.append("partida_ganada sigue en false")
		if int(partida.get("enemigos_abatidos")) != int(partida.get("enemigos_totales")):
			faltan_victoria.append("abatidos %d de %d" % [
				int(partida.get("enemigos_abatidos")), int(partida.get("enemigos_totales"))
			])
		if int(hud.get("fin_partida")) != 1:
			faltan_victoria.append("el HUD marca fin_partida=%d (deberia ser 1)" % int(hud.get("fin_partida")))
	_reportar(31, "Victoria al limpiar todos los enemigos", faltan_victoria)

	# 32. Derrota: vida a cero, partida cerrada, barra a cero y color de alarma.
	var faltan_derrota: Array[String] = []
	if partida == null or hud == null:
		faltan_derrota.append("falta Partida o HUD")
	else:
		jugador.call("recibir_dano", 9999)
		await _frames(6)
		if not bool(partida.get("partida_perdida")):
			faltan_derrota.append("partida_perdida sigue en false")
		if int(hud.get("fin_partida")) != 2:
			faltan_derrota.append("el HUD marca fin_partida=%d (deberia ser 2)" % int(hud.get("fin_partida")))
		if absf(float(hud.get("prop_vida")) - 0.0) > 0.02:
			faltan_derrota.append("la barra se queda en %.2f" % float(hud.get("prop_vida")))
		var prop_guardada: float = float(hud.get("prop_vida"))
		hud.set("prop_vida", 1.0)
		var color_lleno: Color = hud.call("color_vida")
		hud.set("prop_vida", 0.0)
		var color_vacio: Color = hud.call("color_vida")
		hud.set("prop_vida", prop_guardada)
		if color_lleno == color_vacio:
			faltan_derrota.append("la barra no cambia de color con la vida")
	_reportar(32, "Derrota al llegar a cero la vida, barra y color de alarma", faltan_derrota)

	# 33. El reproductor 3D temporal del impacto se borra solo. En headless
	# la senal "finished" no llega nunca, asi que sin la red de seguridad se
	# acumula uno por impacto y Godot cierra con un ObjectDB leak.
	var faltan_pista: Array[String] = []
	var nodo_sonido: Node = null
	for candidato: Node in get_nodes_in_group("sonido"):
		nodo_sonido = candidato
		break
	if nodo_sonido == null:
		faltan_pista.append("no hay ningun nodo en el grupo sonido")
	else:
		var reproductores_antes: int = _contar_reproductores3d(nodo_sonido)
		nodo_sonido.call("reproducir_impacto", Vector3.ZERO)
		var reproductores_ahora: int = _contar_reproductores3d(nodo_sonido)
		if reproductores_ahora != reproductores_antes + 1:
			faltan_pista.append("no ha creado el reproductor temporal")
		await _frames(60)
		var reproductores_despues: int = _contar_reproductores3d(nodo_sonido)
		if reproductores_despues != reproductores_antes:
			faltan_pista.append("quedan %d reproductores acumulados" % (
				reproductores_despues - reproductores_antes
			))
	_reportar(33, "El reproductor 3D del impacto se borra solo", faltan_pista)

	# 34. Particulas: los tres emisores existen, estan montados y reaccionan.
	# Se comprueba el ENCHUFADO (emitting), no la simulacion: en headless no
	# hay GPU que mueva las particulas.
	var faltan_particulas: Array[String] = []
	var emisores: Dictionary = {}
	for nombre: String in ["PolvoAterrizaje", "PolvoCorrer", "RastroDash"]:
		var emisor: Node = jugador.get_node_or_null(nombre)
		if emisor == null:
			emisor = jugador.get_node_or_null("Modelo/" + nombre)
		if emisor == null:
			faltan_particulas.append("falta %s" % nombre)
			continue
		var sistema: GPUParticles3D = emisor as GPUParticles3D
		if sistema == null:
			faltan_particulas.append("%s no es GPUParticles3D" % nombre)
			continue
		if sistema.process_material == null:
			faltan_particulas.append("%s sin process material" % nombre)
		if sistema.draw_pass_1 == null:
			faltan_particulas.append("%s sin malla de dibujo" % nombre)
		if sistema.visibility_aabb.size.x <= 0.0:
			faltan_particulas.append("%s con visibility_aabb vacia" % nombre)
		emisores[nombre] = sistema

	# Polvo al correr: en el centro del dormitorio, despejado.
	jugador.global_position = Vector3(0.0, 1.0, 1.0)
	await _frames(30)
	if emisores.has("PolvoCorrer"):
		Input.action_press("move_forward")
		await _frames(25)
		var polvo_al_correr: bool = (emisores["PolvoCorrer"] as GPUParticles3D).emitting
		Input.action_release("move_forward")
		await _frames(15)
		var polvo_parado: bool = (emisores["PolvoCorrer"] as GPUParticles3D).emitting
		if not polvo_al_correr:
			faltan_particulas.append("no echa polvo mientras corre")
		if polvo_parado:
			faltan_particulas.append("sigue echando polvo con el jugador parado")

	# Ráfaga de polvo al caer desde altura.
	if emisores.has("PolvoAterrizaje"):
		var rafagas_antes: int = int(jugador.get("rafagas_polvo"))
		jugador.global_position = Vector3(0.0, 4.0, 0.0)
		await _frames(45)
		var rafagas_despues: int = int(jugador.get("rafagas_polvo"))
		if rafagas_despues <= rafagas_antes:
			faltan_particulas.append("no echa polvo al aterrizar")

	# Rastro encendido durante el dash y apagado al terminar.
	if emisores.has("RastroDash"):
		await _frames(20)
		Input.action_press("dash")
		await _frames(3)
		var rastro_encendido: bool = (emisores["RastroDash"] as GPUParticles3D).emitting
		Input.action_release("dash")
		await _frames(30)
		var rastro_apagado: bool = (emisores["RastroDash"] as GPUParticles3D).emitting
		if not rastro_encendido:
			faltan_particulas.append("no enciende el rastro durante el dash")
		if rastro_apagado:
			faltan_particulas.append("el rastro no se apaga al terminar el dash")
	_reportar(34, "Particulas de polvo (correr, aterrizar) y rastro del dash", faltan_particulas)

	# 35. Sonido de enemigo (los tres avisos que llama enemigo.gd) y el
	# viento ambiente, que tiene que estar sonando desde que arranca el nivel.
	var faltan_ambiente: Array[String] = []
	if sonido == null:
		faltan_ambiente.append("no hay nodo sonido")
	else:
		for senal_llamada: String in [
			"reproducir_enemigo_detecta", "reproducir_enemigo_aviso", "reproducir_enemigo_golpe"
		]:
			if not sonido.has_method(senal_llamada):
				faltan_ambiente.append("falta %s()" % senal_llamada)
		var flujos_nuevos: Dictionary = sonido.get("flujos")
		for clave: String in ["enemigo_detecta", "enemigo_aviso", "enemigo_golpe"]:
			if not flujos_nuevos.has(clave):
				faltan_ambiente.append("no genera el flujo %s" % clave)
			else:
				var bytes_flujo: int = (flujos_nuevos[clave] as AudioStreamWAV).data.size()
				if bytes_flujo < 1000:
					faltan_ambiente.append("el flujo %s solo tiene %d bytes" % [clave, bytes_flujo])

		var pistolas_nuevas: Dictionary = sonido.get("pistolas")
		if not pistolas_nuevas.has("ambiente"):
			faltan_ambiente.append("no hay pista de ambiente")
		else:
			var viento: AudioStreamPlayer = pistolas_nuevas["ambiente"] as AudioStreamPlayer
			if viento == null or not viento.playing:
				faltan_ambiente.append("el viento no esta sonando")
		if not pistolas_nuevas.has("enemigo_detecta"):
			faltan_ambiente.append("no hay pista para el aviso del enemigo")
		else:
			sonido.call("reproducir_enemigo_detecta")
			await _frames(3)
			var aviso: AudioStreamPlayer = pistolas_nuevas["enemigo_detecta"] as AudioStreamPlayer
			if aviso == null or not aviso.playing:
				faltan_ambiente.append("el aviso del enemigo no suena al llamarlo")
	_reportar(35, "Sonido de enemigo (3 avisos) y viento ambiente en bucle", faltan_ambiente)

	# 36. Fase 8 en el HUD: la mira cambia de color segun lo que hay delante
	# (aire, blanco o muro) y el enfriamiento del dash se copia del jugador.
	var faltan_fase8: Array[String] = []
	if hud == null:
		faltan_fase8.append("no hay HUD")
	elif pistola_hud == null:
		faltan_fase8.append("no hay pistola")
	elif not hud.has_method("color_reticula"):
		faltan_fase8.append("el HUD no tiene color_reticula()")
	else:
		pistola_hud.set("apuntando_blanco", false)
		pistola_hud.set("apuntando_muro", false)
		var color_aire: Color = hud.call("color_reticula")
		pistola_hud.set("apuntando_blanco", true)
		var color_blanco: Color = hud.call("color_reticula")
		pistola_hud.set("apuntando_blanco", false)
		pistola_hud.set("apuntando_muro", true)
		var color_muro: Color = hud.call("color_reticula")
		pistola_hud.set("apuntando_muro", false)
		if color_aire.a <= 0.0:
			faltan_fase8.append("la reticula por defecto no se ve")
		if color_aire == color_blanco:
			faltan_fase8.append("la mira no cambia de color con un blanco")
		if color_aire == color_muro:
			faltan_fase8.append("la mira no cambia de color con un muro")
		if color_blanco == color_muro:
			faltan_fase8.append("blanco y muro dan el mismo color")
		if not hud.has_method("_dibujar_dash"):
			faltan_fase8.append("el HUD no dibuja la recarga del dash")

		jugador.set("enfriamiento_dash", 5.0)
		await _frames(2)
		var enf_hud: float = float(hud.get("enfriamiento_dash"))
		if absf(enf_hud - 5.0) > 0.2:
			faltan_fase8.append("el HUD no copia el enfriamiento del dash (%.2f)" % enf_hud)
		jugador.set("enfriamiento_dash", 0.0)
	_reportar(36, "Fase 8: mira con color y recarga del dash en el HUD", faltan_fase8)

	# 37. La mira tiene que reflejar el rayo de verdad, y tiene que
	# ACTUALIZARSE cada frame. Tres comprobaciones: coherencia con el rayo,
	# mirar al suelo (muro) y apuntar a mano a un blanco.
	var faltan_mira: Array[String] = []
	if pistola_hud == null:
		faltan_mira.append("no hay pistola")
	else:
		await _frames(3)
		var rayo_mira: RayCast3D = pistola_hud.get("rayo") as RayCast3D
		if rayo_mira == null:
			faltan_mira.append("la pistola no tiene rayo")
		elif not pistola_hud.has_method("_evaluar_mira"):
			faltan_mira.append("la pistola no tiene _evaluar_mira()")
		else:
			# Coherencia: lo que dice la pistola es lo que choca su rayo.
			rayo_mira.force_raycast_update()
			var golpea_mira: bool = rayo_mira.is_colliding()
			var destructible: bool = false
			if golpea_mira:
				var col_mira: Object = rayo_mira.get_collider()
				if col_mira is Node:
					var nodo_mira: Node = col_mira as Node
					destructible = nodo_mira.has_method("recibir_dano")
					if not destructible:
						for hijo_mira: Node in nodo_mira.get_children():
							if hijo_mira.has_method("recibir_dano"):
								destructible = true
			if bool(pistola_hud.get("apuntando_blanco")) != (golpea_mira and destructible):
				faltan_mira.append("apuntando_blanco no coincide con lo que choca el rayo")
			if bool(pistola_hud.get("apuntando_muro")) != (golpea_mira and not destructible):
				faltan_mira.append("apuntando_muro no coincide con lo que choca el rayo")

			# Mirar al suelo: el rayo pega en el escenario, la mira dice muro.
			jugador.set("pitch_deseado", -1.3)
			await _frames(20)
			if not bool(pistola_hud.get("apuntando_muro")):
				faltan_mira.append("apuntando al suelo la mira no dice muro")
			if bool(pistola_hud.get("apuntando_blanco")):
				faltan_mira.append("el suelo sale como blanco")
			jugador.set("pitch_deseado", 0.0)

			# Apuntar a mano a un blanco propio (el nivel ya no trae): la rama
			# destructible tiene que encender la mira.
			var mira_blanco: Node = _crear_raton(Vector3(0, 0, -1.0))
			if mira_blanco == null:
				faltan_mira.append("no hay blancos para apuntar")
			else:
				# El nodo del blanco esta en el suelo: hay que apuntar al
				# centro de su caja de colision, no al origen del nodo.
				var centro_blanco: float = 1.2
				var colision_b: CollisionShape3D = mira_blanco.get_node_or_null("CollisionShape3D")
				if colision_b != null:
					centro_blanco = colision_b.position.y
				var punto_blanco: Vector3 = (mira_blanco as Node3D).global_position + Vector3(0.0, centro_blanco, 0.0)
				rayo_mira.global_position = punto_blanco + Vector3(0.0, 0.0, 1.2)
				rayo_mira.target_position = rayo_mira.to_local(punto_blanco)
				pistola_hud.call("_evaluar_mira")
				if not bool(pistola_hud.get("apuntando_blanco")):
					faltan_mira.append("apuntando a un blanco la mira no lo reconoce")
				if bool(pistola_hud.get("apuntando_muro")):
					faltan_mira.append("un blanco sale como muro")
				mira_blanco.queue_free()
				await _frames(2)
	_reportar(37, "La mira refleja el rayo (blanco, muro o aire)", faltan_mira)

	# 38. La cabeza del gato gira ENTERA (hocico, ojos y orejas colgados de
	# Cabeza) y sigue la camara: arriba levanta la cabeza, abajo la baja.
	var faltan_cabeza: Array[String] = []
	if jugador == null:
		faltan_cabeza.append("no hay jugador")
	else:
		var cabeza_n3: Node3D = jugador.get_node_or_null("Modelo/Cabeza") as Node3D
		if cabeza_n3 == null:
			faltan_cabeza.append("falta Modelo/Cabeza")
		else:
			for parte_cab: String in ["Hocico", "OjoIzquierdo", "OjoDerecho", "OrejaIzquierda", "OrejaDerecha"]:
				if cabeza_n3.get_node_or_null(parte_cab) == null:
					faltan_cabeza.append("%s no esta colgada de la cabeza" % parte_cab)
			var hocico_n3: Node3D = cabeza_n3.get_node_or_null("Hocico") as Node3D
			if hocico_n3 == null:
				faltan_cabeza.append("falta el hocico para comprobar la posicion")
			else:
				# Al colgarlo tiene que quedar donde estaba (reparent conservando).
				# Con el modelo de gato el hocico cuelga ya de la cabeza.
				var local_hocico: Vector3 = hocico_n3.position
				if local_hocico.distance_to(Vector3(0.0, -0.03, -0.09)) > 0.01:
					faltan_cabeza.append("el hocico se ha movido al colgarlo: %s" % str(local_hocico))

			jugador.set("pitch_deseado", 1.3)
			await _frames(25)
			var girada_arriba: float = cabeza_n3.rotation.x
			if girada_arriba <= 0.05:
				faltan_cabeza.append("al mirar arriba la cabeza no se levanta (%.3f)" % girada_arriba)

			jugador.set("pitch_deseado", -1.3)
			await _frames(25)
			var girada_abajo: float = cabeza_n3.rotation.x
			if girada_abajo >= -0.05:
				faltan_cabeza.append("al mirar abajo la cabeza no baja (%.3f)" % girada_abajo)
			jugador.set("pitch_deseado", 0.0)
	_reportar(38, "La cabeza del gato gira entera y sigue la camara", faltan_cabeza)

	# 39. Barra de vida flotante del enemigo: oculta al nacer, sale al
	# recibir dano, refleja la vida, se apaga sola y desaparece al morir.
	var faltan_barra: Array[String] = []
	var escena_barra: PackedScene = load("res://scenes/enemigo.tscn") as PackedScene
	if escena_barra == null:
		faltan_barra.append("no carga res://scenes/enemigo.tscn")
	else:
		var enemigo_barra: Node = escena_barra.instantiate()
		nivel_instanciado.add_child(enemigo_barra)
		enemigo_barra.global_position = jugador.global_position + Vector3(0.6, 0.5, 1.3)
		var barra_n3: Node3D = enemigo_barra.get_node_or_null("BarraVida") as Node3D
		if barra_n3 == null:
			faltan_barra.append("el enemigo no crea el nodo BarraVida")
		else:
			if barra_n3.visible:
				faltan_barra.append("la barra arranca visible sin haber recibido dano")
			enemigo_barra.set("duracion_barra_vida", 0.15)
			enemigo_barra.call("recibir_dano", 30)
			if not barra_n3.visible:
				faltan_barra.append("al recibir dano la barra no se muestra")
			var relleno_n3: Node3D = barra_n3.get_node_or_null("Relleno") as Node3D
			if relleno_n3 == null:
				faltan_barra.append("la barra no tiene el relleno Relleno")
			else:
				var vida_barra: int = int(enemigo_barra.get("vida"))
				var maxima_barra: int = maxi(int(enemigo_barra.get("vida_maxima")), 1)
				var esperado_relleno: float = float(vida_barra) / float(maxima_barra)
				if absf(relleno_n3.scale.x - esperado_relleno) > 0.02:
					faltan_barra.append(
						"el relleno marca %.2f y deberia ser %.2f" % [relleno_n3.scale.x, esperado_relleno]
					)
			await _frames(25)
			if barra_n3.visible:
				faltan_barra.append("la barra no se apaga sola")
			enemigo_barra.call("mostrar_barra_vida")
			if not barra_n3.visible:
				faltan_barra.append("mostrar_barra_vida no la enciende")
			enemigo_barra.call("recibir_dano", 9999)
			if barra_n3.visible:
				faltan_barra.append("al morir la barra sigue visible")
		enemigo_barra.queue_free()
	_reportar(39, "Barra de vida flotante del enemigo", faltan_barra)

	# 40. La camara de hombro se queda SIEMPRE en el mismo lado de la mirada,
	# vaya como vaya la vista. Antes el offset estaba en el espacio del cuerpo
	# (que nunca gira): al girar 180 la camara cruzaba al otro lado de la
	# pantalla. Ademas baja al agacharse para no clavarse en los muebles.
	var faltan_hombro: Array[String] = []
	if jugador == null:
		faltan_hombro.append("no hay jugador")
	else:
			var brazo_hombro: Node3D = jugador.get("brazo_camara") as Node3D
			var cam_hombro: Camera3D = jugador.get_node_or_null("SpringArm3D/Camara3D") as Camera3D
			if brazo_hombro == null or cam_hombro == null:
				faltan_hombro.append("falta el brazo o la camara")
			else:
				var mitad_hombro40: float = float(jugador.get("offset_hombro")) * 0.5
				for yaw_prueba: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
					jugador.set("yaw_deseado", yaw_prueba)
					await _frames(30)
					var derecha: Vector3 = cam_hombro.global_transform.basis.x
					derecha.y = 0.0
					var lado: float = (cam_hombro.global_position - jugador.global_position).dot(
						derecha.normalized()
					)
					if lado < mitad_hombro40:
						faltan_hombro.append(
							"con la vista a %.2f rad la camara queda a la izquierda (lado=%.2f)" % [
								yaw_prueba, lado
							]
						)
			jugador.set("yaw_deseado", 0.0)
			await _frames(30)

			# Y el brazo baja el tiempo que dura el agachado.
			var alto_pie40: float = float(jugador.get("altura_de_pie"))
			var alto_agach40: float = float(jugador.get("altura_agachado"))
			var baja_esp40: float = (alto_pie40 - alto_agach40) * 0.5
			var altura_base: float = brazo_hombro.position.y
			Input.action_press("crouch")
			await _frames(8)
			if altura_base - brazo_hombro.position.y < baja_esp40 * 0.6:
				faltan_hombro.append(
					"agachado no baja la camara (%.2f -> %.2f, esperado %.2f)" % [
						altura_base, brazo_hombro.position.y, baja_esp40
					]
				)
			Input.action_release("crouch")
			await _frames(8)
	_reportar(40, "La camara de hombro se queda siempre del mismo lado", faltan_hombro)

	# 41. La pistola cuelga del MODELO: se va con el cuerpo (agachado incluido)
	# pero el canon sigue apuntando a la mirada aunque el gato corra de espaldas.
	var faltan_arma41: Array[String] = []
	if jugador == null:
		faltan_arma41.append("no hay jugador")
	else:
		var pist_a2: Node3D = _buscar_en(jugador, "Pistola") as Node3D
		var modelo_a2: Node3D = jugador.get("modelo") as Node3D
		var brazo_a2: Node3D = jugador.get("brazo_camara") as Node3D
		if pist_a2 == null or modelo_a2 == null or brazo_a2 == null:
			faltan_arma41.append("falta pistola, modelo o brazo")
		else:
			jugador.set("yaw_deseado", 2.0)
			await _frames(30)
			if pist_a2.get_parent() != modelo_a2:
				faltan_arma41.append("la pistola no cuelga del Modelo")

			# El canon cancela el giro del cuerpo: desvio local entre
			# (modelo + arma) y la mirada de la camara.
			var ali_a2: float = wrapf(
				(modelo_a2.rotation.y + pist_a2.rotation.y) - brazo_a2.rotation.y,
				-PI, PI
			)
			if absf(ali_a2) > 0.2:
				faltan_arma41.append("el canon no sigue a la mirada (%.2f rad)" % ali_a2)

			# De espaldas: el cuerpo se da la vuelta pero el arma sigue al aire.
			Input.action_press("move_back")
			await _frames(30)
			var atras_a2: float = absf(wrapf(
				modelo_a2.rotation.y - brazo_a2.rotation.y, -PI, PI
			))
			if atras_a2 < 2.5:
				faltan_arma41.append("el cuerpo no se dio la vuelta (%.2f rad)" % atras_a2)
			var ali_atras_a2: float = wrapf(
				(modelo_a2.rotation.y + pist_a2.rotation.y) - brazo_a2.rotation.y,
				-PI, PI
			)
			if absf(ali_atras_a2) > 0.2:
				faltan_arma41.append(
					"de espaldas el canon se desvia de la mirada (%.2f rad)" % ali_atras_a2
				)
			Input.action_release("move_back")
			await _frames(30)

			# Agachado: el arma baja lo mismo que el cuerpo.
			var bajada_a2: float = float(jugador.get("bajada_agachado"))
			var y_antes_a2: float = pist_a2.global_position.y
			Input.action_press("crouch")
			await _frames(8)
			var y_despues_a2: float = pist_a2.global_position.y
			Input.action_release("crouch")
			if y_antes_a2 - y_despues_a2 < bajada_a2 * 0.6:
				faltan_arma41.append(
					"agachado no baja el arma (%.2f -> %.2f, esperado %.2f)" % [
						y_antes_a2, y_despues_a2, bajada_a2
					]
				)
			jugador.set("yaw_deseado", 0.0)
			await _frames(30)
	_reportar(41, "La pistola cuelga del Modelo y el canon sigue a la mirada", faltan_arma41)

	# 42. Disparo alineado: de espaldas el gato NO tira hasta que el cuerpo se
	# gira hacia la mirada, el tiro sale igualmente (el clic no se pierde) y
	# al soltar el disparo vuelve el giro de 180 al seguir de espaldas.
	var faltan_tiro42: Array[String] = []
	if jugador == null:
		faltan_tiro42.append("no hay jugador")
	else:
		var pist42: Node = _buscar_en(jugador, "Pistola")
		var modelo42: Node3D = jugador.get("modelo") as Node3D
		var brazo42: Node3D = jugador.get("brazo_camara") as Node3D
		if pist42 == null or modelo42 == null or brazo42 == null:
			faltan_tiro42.append("falta pistola, modelo o brazo")
		else:
			jugador.global_position = Vector3(0.0, 1.0, 0.6)
			jugador.set("yaw_deseado", 0.0)
			await _frames(30)

			Input.action_press("move_back")
			await _frames(30)
			var desvio_a42: float = absf(wrapf(
				modelo42.rotation.y - brazo42.rotation.y, -PI, PI
			))
			if desvio_a42 < 2.5:
				faltan_tiro42.append("el cuerpo no esta de espaldas (%.2f rad)" % desvio_a42)

			# Pulsar disparar con el cuerpo al revés: a los 2 frames el cuerpo
			# aun esta girando y NO tiene que haber salido nada. action_press()
			# solo marca el estado de polling y no llega a _unhandled_input,
			# asi que el evento se inyecta a mano.
			var disparos_a42: int = int(pist42.get("disparos"))
			var ev_tiro42: InputEventAction = InputEventAction.new()
			ev_tiro42.action = "fire"
			ev_tiro42.pressed = true
			Input.parse_input_event(ev_tiro42)
			Input.flush_buffered_events()
			await _frames(2)
			if int(pist42.get("disparos")) > disparos_a42:
				faltan_tiro42.append("tiro de espaldas a los 2 frames")

			# En cuanto se alinea, el tiro sale.
			var tiro42: bool = false
			for i42: int in 16:
				await physics_frame
				if int(pist42.get("disparos")) > disparos_a42:
					tiro42 = true
					break
			if not tiro42:
				faltan_tiro42.append("el tiro nunca salio tras 16 frames")
			var desvio_final42: float = absf(wrapf(
				modelo42.rotation.y - brazo42.rotation.y, -PI, PI
			))
			if tiro42 and desvio_final42 > 0.9:
				faltan_tiro42.append("el tiro salio desviado (%.2f rad)" % desvio_final42)

			# Al soltar el disparo, seguir de espaldas hace girar 180 otra vez.
			ev_tiro42.pressed = false
			Input.parse_input_event(ev_tiro42)
			Input.flush_buffered_events()
			await _frames(30)
			var desvio_atras42: float = absf(wrapf(
				modelo42.rotation.y - brazo42.rotation.y, -PI, PI
			))
			if desvio_atras42 < 2.5:
				faltan_tiro42.append("al soltar no vuelve a girar 180 (%.2f rad)" % desvio_atras42)
			Input.action_release("move_back")
			await _frames(20)
	_reportar(42, "Disparo alineado: gira hacia la mirada y nunca se pierde el tiro", faltan_tiro42)

	# 43. El gato compartido: scenes/gato.tscn existe, es CUADRUPEDA (cuerpo
	# horizontal, cabeza baja; un biped tenia la cabeza a 0.85), el jugador
	# lo usa de verdad con capsula de gato y el pelaje se tiñe por instancia.
	var faltan_gato43: Array[String] = []
	var escena_gato43: PackedScene = load("res://scenes/gato.tscn") as PackedScene
	if escena_gato43 == null:
		faltan_gato43.append("no carga res://scenes/gato.tscn")
	else:
		var gato43: Node = escena_gato43.instantiate()
		if gato43 == null:
			faltan_gato43.append("instantiate() -> null")
		else:
			var guion43: Script = gato43.get_script() as Script
			if guion43 == null or not String(guion43.resource_path).ends_with("gato.gd"):
				faltan_gato43.append("la raiz no lleva scripts/gato.gd")
			# v0.5: el gato baja a 0.80 para que la casa le quede grande de verdad.
			var escala43: Vector3 = (gato43 as Node3D).scale
			if absf(escala43.x - 0.8) > 0.01 or absf(escala43.y - 0.8) > 0.01 or absf(escala43.z - 0.8) > 0.01:
				faltan_gato43.append("el gato escala %s (deberia ser 0.80)" % str(escala43))
			for nombre43: String in ["Cuerpo", "Cabeza", "Cola", "Pata1", "Pata2", "Pata3", "Pata4"]:
				if gato43.get_node_or_null(nombre43) == null:
					faltan_gato43.append("falta %s" % nombre43)
			var cabeza43: Node3D = gato43.get_node_or_null("Cabeza") as Node3D
			var cuerpo43: MeshInstance3D = gato43.get_node_or_null("Cuerpo") as MeshInstance3D
			if cuerpo43 == null:
				faltan_gato43.append("falta la malla Cuerpo")
			else:
				var malla43: BoxMesh = cuerpo43.mesh as BoxMesh
				if malla43 == null:
					faltan_gato43.append("el cuerpo no es una caja")
				elif malla43.size.z <= malla43.size.y:
					faltan_gato43.append(
						"el cuerpo no es horizontal (size %s)" % str(malla43.size)
					)
			if cabeza43 != null and cabeza43.position.y > 0.5:
				faltan_gato43.append(
					"la cabeza a %.2f: no es la proporcion de un gato" % cabeza43.position.y
				)
			gato43.free()

	# El jugador lo usa de verdad.
	if jugador == null:
		faltan_gato43.append("no hay jugador")
	else:
		var forma43: CapsuleShape3D = jugador.get("forma_capsula") as CapsuleShape3D
		if forma43 == null:
			faltan_gato43.append("el jugador no tiene capsula")
		else:
			if absf(forma43.height - 0.32) > 0.015:
				faltan_gato43.append("capsula a %.2f, un gato a escala 0.80 mide 0.32" % forma43.height)
			if forma43.radius > 0.12:
				faltan_gato43.append("capsula ancha %.2f" % forma43.radius)
		var modelo_g43: Node3D = jugador.get("modelo") as Node3D
		if modelo_g43 == null:
			faltan_gato43.append("el jugador no tiene modelo")
		else:
			if modelo_g43.get_script() == null:
				faltan_gato43.append("el modelo del jugador no lleva script")
			var cuerpo_g43: MeshInstance3D = modelo_g43.get_node_or_null("Cuerpo") as MeshInstance3D
			if cuerpo_g43 == null:
				faltan_gato43.append("el modelo del jugador no tiene Cuerpo")
			elif cuerpo_g43.material_override == null:
				faltan_gato43.append("el pelaje no se tiñe por instancia (sin override)")
	_reportar(43, "Gato compartido cuadrupeda a escala con pinta propia", faltan_gato43)

	# 44. Pulido del disparo: el arma mide para un gato, el fogonazo se
	# enciende y se apaga con el tiro, el trazador va del canon al impacto
	# y se borra, y el arma da su retroceso y vuelve.
	var faltan_pulido44: Array[String] = []
	var pist44: Node = _buscar_en(jugador, "Pistola")
	if pist44 == null:
		faltan_pulido44.append("no hay pistola")
	else:
		var fog44: MeshInstance3D = pist44.get_node_or_null("Fogonazo") as MeshInstance3D
		var luz44: OmniLight3D = pist44.get_node_or_null("LuzFogonazo") as OmniLight3D
		var traz44: MeshInstance3D = pist44.get_node_or_null("Trazador") as MeshInstance3D
		if fog44 == null:
			faltan_pulido44.append("falta el Fogonazo")
		if luz44 == null:
			faltan_pulido44.append("falta la LuzFogonazo")
		if traz44 == null:
			faltan_pulido44.append("falta el Trazador")
		var cuerpo44: MeshInstance3D = pist44.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if cuerpo44 == null:
			faltan_pulido44.append("falta el cuerpo del arma")
		else:
			var caja44: BoxMesh = cuerpo44.mesh as BoxMesh
			if caja44 == null:
				faltan_pulido44.append("el cuerpo del arma no es una caja")
			else:
				var lado44: float = maxf(caja44.size.x, maxf(caja44.size.y, caja44.size.z))
				if lado44 > 0.16:
					faltan_pulido44.append("arma de %.2f m: no es escala de pata" % lado44)
		var cam44: Camera3D = jugador.get_node_or_null("SpringArm3D/Camara3D") as Camera3D
		var diana44: Node = _crear_raton(Vector3(0, 0.1, 0.5))
		if cam44 == null or diana44 == null:
			faltan_pulido44.append("no hay camara o blancos para probar el trazador")
		elif fog44 != null and traz44 != null:
			_colocar_blanco_en_punteria(diana44, cam44)
			await _frames(3)
			var base44: Vector3 = (pist44 as Node3D).position
			pist44.call("disparar")
			await physics_frame
			await physics_frame
			if not fog44.visible:
				faltan_pulido44.append("el fogonazo no se enciende al disparar")
			if not traz44.visible:
				faltan_pulido44.append("el trazador no aparece al impactar")
			if (pist44 as Node3D).position.z <= base44.z + 0.005:
				faltan_pulido44.append("el arma no recua hacia atras")
			await _frames(45)
			if fog44.visible:
				faltan_pulido44.append("el fogonazo no se apaga")
			if traz44.visible:
				faltan_pulido44.append("el trazador no se borra")
			if absf((pist44 as Node3D).position.z - base44.z) > 0.01:
				faltan_pulido44.append(
					"el arma no vuelve de su retroceso (%.3f)" % (
						(pist44 as Node3D).position.z - base44.z
					)
				)
			diana44.queue_free()
			await _frames(2)
	_reportar(44, "Pulido del disparo: escala de gato, fogonazo, trazador y retroceso", faltan_pulido44)

	# 45. Pulido del HUD: la X del marcador y el pop del anillo cuando el
	# rayo dania a algo (no al pegar en un muro), con su tick de sonido, y
	# los dos se borran solos con el tiempo.
	var faltan_marcador45: Array[String] = []
	var hud45: HUD = nivel_instanciado.get_node_or_null("HUD/Reticula") as HUD
	if hud45 == null:
		faltan_marcador45.append("falta el HUD del nivel")
	var sonido45: Node = null
	for candidato45: Node in get_nodes_in_group("sonido"):
		sonido45 = candidato45
		break
	if sonido45 == null or not sonido45.has_method("reproducir_marcador"):
		faltan_marcador45.append("falta reproducir_marcador()")
	else:
		var flujos45: Dictionary = sonido45.get("flujos")
		if not flujos45.has("marcador"):
			faltan_marcador45.append("no hay flujo WAV marcador")
	var cam45: Camera3D = jugador.get_node_or_null("SpringArm3D/Camara3D") as Camera3D
	var diana45: Node = _crear_raton(Vector3(0, 0.1, 0.5))
	if hud45 != null and cam45 != null and diana45 != null:
		_colocar_blanco_en_punteria(diana45, cam45)
		await _frames(18)
		var pist45: Node = _buscar_en(jugador, "Pistola")
		if pist45 == null:
			faltan_marcador45.append("no hay pistola")
		else:
			hud45.marcador = 0.0
			hud45.pop = 0.0
			# El raton cae al suelo con la fisica: re-encarar justo antes del
			# tiro o el rayo pasaria por encima.
			_colocar_blanco_en_punteria(diana45, cam45)
			await _frames(2)
			pist45.call("disparar")
			await _frames(3)
			if float(hud45.get("pop")) <= 0.0:
				faltan_marcador45.append("no hay pop al conectar el rayo")
			if float(hud45.get("marcador")) <= 0.0:
				faltan_marcador45.append("el marcador no aparece al danar")
			await _frames(30)
			if float(hud45.get("marcador")) > 0.0:
				faltan_marcador45.append("el marcador no se borra con el tiempo")
			if float(hud45.get("pop")) > 0.0:
				faltan_marcador45.append("el pop no se borra con el tiempo")
			diana45.queue_free()
			await _frames(2)
	elif diana45 != null:
		diana45.queue_free()
		await _frames(2)
	_reportar(45, "HUD: marcador X, pop del anillo y tick al danar", faltan_marcador45)

	# 46. El disparo mueve la camara: el FOV se abre un pelin con el tiro y
	# vuelve solo, y la sacudida del disparo arranca y se apaga sola.
	var faltan_cam46: Array[String] = []
	var cam46: Camera3D = jugador.get_node_or_null("SpringArm3D/Camara3D") as Camera3D
	if cam46 == null:
		faltan_cam46.append("falta la camara del jugador")
	else:
		jugador.set("tiempo_sacudida", 0.0)
		jugador.set("fov_kick", 0.0)
		var fov_antes46: float = cam46.fov
		jugador.call("disparar")
		await _frames(2)
		if float(jugador.get("fov_kick")) <= 0.05:
			faltan_cam46.append("el FOV no reacciona al disparar")
		if float(jugador.get("tiempo_sacudida")) <= 0.0:
			faltan_cam46.append("no hay sacudida al disparar")
		if cam46.fov <= fov_antes46 + 0.5:
			faltan_cam46.append("el FOV no se abre con el tiro (%.2f)" % cam46.fov)
		await _frames(45)
		if float(jugador.get("fov_kick")) > 0.05:
			faltan_cam46.append("el FOV no vuelve a su sitio")
		if float(jugador.get("tiempo_sacudida")) > 0.0:
			faltan_cam46.append("la sacudida no se apaga")
		if absf(cam46.fov - fov_antes46) > 0.05:
			faltan_cam46.append(
				"el FOV se queda en %.2f y deberia volver a %.2f" % [cam46.fov, fov_antes46]
			)
	_reportar(46, "Camara: FOV del tiro y sacudida que se apagan solas", faltan_cam46)

	# 47. Destello y poof de la muerte: el cuerpo se enciende con el ultimo
	# golpe, sale una nube de bolas donde cae el enemigo y todo se borra solo.
	var faltan_poof47: Array[String] = []
	var escena_enem47: PackedScene = load("res://scenes/enemigo.tscn") as PackedScene
	if escena_enem47 == null:
		faltan_poof47.append("load() -> null")
	elif nivel_instanciado == null or jugador == null:
		faltan_poof47.append("no hay nivel o jugador")
	else:
		if nivel_instanciado.get_node_or_null("Poof") != null:
			faltan_poof47.append("queda un poof sin borrar de antes")
		var enem47: Node = escena_enem47.instantiate()
		nivel_instanciado.add_child(enem47)
		(enem47 as Node3D).global_position = (
			(jugador as Node3D).global_position + Vector3(-0.6, 0.5, 1.3)
		)
		await _frames(3)
		var pos47: Vector3 = (enem47 as Node3D).global_position
		var mat47: StandardMaterial3D = enem47.get("material_cuerpo") as StandardMaterial3D
		if mat47 == null:
			faltan_poof47.append("no hay material del cuerpo")
		enem47.call("recibir_dano", 9999)
		await _frames(2)
		if mat47 != null and (not mat47.emission_enabled or mat47.emission_energy_multiplier <= 0.1):
			faltan_poof47.append("el cuerpo no se enciende al morir")
		var poof47: Node = nivel_instanciado.get_node_or_null("Poof")
		if poof47 == null:
			faltan_poof47.append("no hay poof al morir")
		else:
			var nube47: Node3D = poof47 as Node3D
			if nube47.get_child_count() < 4:
				faltan_poof47.append("el poof solo tiene %d bolas" % nube47.get_child_count())
			var salto47: Vector2 = Vector2(
				nube47.global_position.x - pos47.x,
				nube47.global_position.z - pos47.z
			)
			if salto47.length() > 0.1:
				faltan_poof47.append("el poof sale a %.2f m de donde cae" % salto47.length())
		await _frames(35)
		if mat47 != null and mat47.emission_enabled:
			faltan_poof47.append("el destello no se apaga solo")
		if nivel_instanciado.get_node_or_null("Poof") != null:
			faltan_poof47.append("el poof no se borra solo")
		enem47.queue_free()
	_reportar(47, "Muerte del enemigo: destello que se apaga y poof que se borra", faltan_poof47)

	# 48. La casa completa: el dormitorio queda intacto y alrededor hay salon,
	# pasillo y cocina, con los seis huecos de paso (cuatro puertas y dos
	# ventanas de verdad), suelos, luz que llega a todos los rincones y SSAO
	# recargado para que las esquinas se marquen.
	var faltan_casa48: Array[String] = []
	if nivel_instanciado == null:
		faltan_casa48.append("no hay nivel")
	else:
		if nivel_instanciado.get_node_or_null("Casa") == null:
			faltan_casa48.append("falta la instancia Casa")
		for nombre48: String in [
			"Suelo", "SueloSalon", "SueloPasillo", "SueloCocina", "SueloBano",
			"MuroNorteOeste", "AntepechoNorte", "DintelVentanaNorte", "MuroNorteEste",
			"CristalNorte", "MuroOeste", "MuroSurOeste", "DintelSur", "MuroSurEste",
			"MuroEsteN", "DintelEste", "MuroEsteS",
			"MuroOesteSalon", "MuroSurSalonOeste", "AntepechoSur", "DintelVentanaSur",
			"MuroSurSalonEste", "CristalSur", "MuroEsteSalonA", "DintelSalonCocina",
			"MuroEsteSalonB", "MuroPasilloNorteA", "DintelBano", "MuroPasilloNorteB",
			"MuroPasilloSurA",
			"DintelPasilloCocina", "MuroPasilloSurB", "MuroPasilloEste",
			"MuroCocinaSur", "MuroCocinaEste",
			"MuroBanoNorte", "MuroBanoOeste", "MuroBanoEste",
		]:
			var nodo48: Node = _buscar48(nombre48)
			if nodo48 == null:
				faltan_casa48.append("falta %s" % nombre48)
			elif nombre48.begins_with("Suelo") and not nodo48.is_in_group("suelo"):
				faltan_casa48.append("%s no esta en el grupo suelo" % nombre48)

		# Los cuatro suelos suman casa entera: si se pierde un ala, el area cae.
		var area48: float = 0.0
		for nombre_suelo48: String in ["Suelo", "SueloSalon", "SueloPasillo", "SueloCocina", "SueloBano"]:
			var caja_suelo48: Vector4 = _caja48(_buscar48(nombre_suelo48))
			if caja_suelo48 != Vector4.ZERO:
				area48 += caja_suelo48.z * caja_suelo48.w
		if area48 < 60.0:
			faltan_casa48.append("los suelos suman %.1f m2 (deberian ser 60 o mas)" % area48)

		# Los siete huecos de paso: minimo 0.7 m para que pase un gato.
		var huecos48: Array = [
			["sur del dormitorio", "MuroSurOeste", "MuroSurEste", 0],
			["este del dormitorio", "MuroEsteN", "MuroEsteS", 1],
			["del salon a la cocina", "MuroEsteSalonA", "MuroEsteSalonB", 1],
			["del pasillo a la cocina", "MuroPasilloSurA", "MuroPasilloSurB", 0],
			["ventana del dormitorio", "MuroNorteOeste", "MuroNorteEste", 0],
			["ventana del salon", "MuroSurSalonOeste", "MuroSurSalonEste", 0],
			["al bano", "MuroPasilloNorteA", "MuroPasilloNorteB", 0],
		]
		for hueco48: Array in huecos48:
			var lado_a48: Vector4 = _caja48(_buscar48(hueco48[1] as String))
			var lado_b48: Vector4 = _caja48(_buscar48(hueco48[2] as String))
			if lado_a48 == Vector4.ZERO or lado_b48 == Vector4.ZERO:
				faltan_casa48.append("no se puede medir el hueco %s" % str(hueco48[0]))
				continue
			var ancho_hueco48: float
			if int(hueco48[3]) == 0:
				ancho_hueco48 = (lado_b48.x - lado_b48.z * 0.5) - (lado_a48.x + lado_a48.z * 0.5)
			else:
				ancho_hueco48 = (lado_b48.y - lado_b48.w * 0.5) - (lado_a48.y + lado_a48.w * 0.5)
			if ancho_hueco48 < 0.7:
				faltan_casa48.append("el hueco %s mide %.2f m" % [str(hueco48[0]), ancho_hueco48])

		# Las ventanas son huecos de verdad: el antepecho llega a la cintura
		# del cuarto (1.2) y el dintel deja el hueco abierto por arriba (2.0).
		for datos_ventana48: Array in [
			["del dormitorio", "AntepechoNorte", "DintelVentanaNorte", "MarcoVentanaNorte", -2.0, "CristalNorte"],
			["del salon", "AntepechoSur", "DintelVentanaSur", "MarcoVentanaSur", 6.4, "CristalSur"],
		]:
			var antepecho48: Node = _buscar48(str(datos_ventana48[1]))
			var dintel_ventana48: Node = _buscar48(str(datos_ventana48[2]))
			if antepecho48 == null or dintel_ventana48 == null:
				faltan_casa48.append("no se puede medir la ventana %s" % str(datos_ventana48[0]))
				continue
			var col_ante48: CollisionShape3D = antepecho48.get_node_or_null("CollisionShape3D") as CollisionShape3D
			var col_dintel48: CollisionShape3D = dintel_ventana48.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col_ante48 == null or col_dintel48 == null or col_ante48.shape == null or col_dintel48.shape == null:
				faltan_casa48.append("la ventana %s no tiene caja" % str(datos_ventana48[0]))
				continue
			var borde_ante48: float = (antepecho48 as Node3D).global_position.y + (col_ante48.shape as BoxShape3D).size.y * 0.5
			var borde_dintel48: float = (dintel_ventana48 as Node3D).global_position.y - (col_dintel48.shape as BoxShape3D).size.y * 0.5
			if borde_ante48 > 1.3:
				faltan_casa48.append("el antepecho %s sube a %.2f" % [str(datos_ventana48[0]), borde_ante48])
			if borde_dintel48 < 1.9:
				faltan_casa48.append("el dintel %s baja a %.2f" % [str(datos_ventana48[0]), borde_dintel48])
			# La repisa corona el antepecho (nada coplanar ni hundido) y
			# asoma al cuarto. Cara = plano interior del muro de la ventana.
			var marco48: Node = _buscar48(str(datos_ventana48[3]))
			var repisa48: Node3D = null
			if marco48 != null:
				repisa48 = marco48.get_node_or_null("Repisa") as Node3D
			if repisa48 == null:
				faltan_casa48.append("la ventana %s no tiene repisa" % str(datos_ventana48[0]))
			else:
				var repisa_top48: float = repisa48.global_position.y + 0.03
				if repisa_top48 < borde_ante48 + 0.005:
					faltan_casa48.append(
						"la repisa %s esta hundida (%.2f vs antepecho %.2f)" % [
							str(datos_ventana48[0]), repisa_top48, borde_ante48
						]
					)
				var cara48: float = float(datos_ventana48[4])
				var asoma48: float = absf(repisa48.global_position.z - cara48)
				if asoma48 < 0.08:
					faltan_casa48.append("la repisa %s no asoma al cuarto" % str(datos_ventana48[0]))
			# El marco vive DENTRO del hueco (medio muro = 0.5), sin meterse
			# en el muro ni rozar el cristal.
			var jamb_izq48: Node3D = null
			var jamb_der48: Node3D = null
			var frente48: MeshInstance3D = null
			if marco48 != null:
				jamb_izq48 = marco48.get_node_or_null("JambaIzq") as Node3D
				jamb_der48 = marco48.get_node_or_null("JambaDer") as Node3D
				frente48 = marco48.get_node_or_null("Frente") as MeshInstance3D
			if jamb_izq48 == null or jamb_der48 == null:
				faltan_casa48.append("el marco %s no tiene jambas" % str(datos_ventana48[0]))
			elif absf(jamb_izq48.position.x) > 0.5 or absf(jamb_der48.position.x) > 0.5:
				faltan_casa48.append("las jambas %s estan dentro del muro" % str(datos_ventana48[0]))
			if frente48 == null:
				faltan_casa48.append("el marco %s no tiene frente" % str(datos_ventana48[0]))
			else:
				var frente_malla48: BoxMesh = frente48.mesh as BoxMesh
				if frente_malla48 == null or frente_malla48.size.x > 1.0:
					faltan_casa48.append("el frente %s invade el muro" % str(datos_ventana48[0]))
			var cristal48: Node = _buscar48(str(datos_ventana48[5]))
			var col_cristal48: CollisionShape3D = null
			if cristal48 != null:
				col_cristal48 = cristal48.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col_cristal48 == null or col_cristal48.shape == null:
				faltan_casa48.append("la ventana %s no tiene cristal" % str(datos_ventana48[0]))
			elif (col_cristal48.shape as BoxShape3D).size.x > 0.8:
				faltan_casa48.append("el cristal %s roza el marco" % str(datos_ventana48[0]))

		# SSAO con radio de sala y luz ambiente que llegue a los tres rincones.
		var entorno48: WorldEnvironment = nivel_instanciado.get_node_or_null("Entorno") as WorldEnvironment
		if entorno48 == null or entorno48.environment == null:
			faltan_casa48.append("falta Entorno o su environment")
		else:
			if not entorno48.environment.ssao_enabled:
				faltan_casa48.append("el SSAO esta apagado")
			elif entorno48.environment.ssao_radius < 0.6:
				faltan_casa48.append(
					"radio SSAO %.2f (deberia cubrir la casa, 0.6 o mas)" % entorno48.environment.ssao_radius
				)
		var luz48: OmniLight3D = nivel_instanciado.get_node_or_null("LuzAmbiente") as OmniLight3D
		if luz48 == null:
			faltan_casa48.append("falta LuzAmbiente")
		elif luz48.omni_range < 10.0:
			faltan_casa48.append("LuzAmbiente ilumina solo %.1f m" % luz48.omni_range)

		# La puerta del dormitorio esta abierta hacia dentro, con su hoja.
		var puerta48: Node = nivel_instanciado.get_node_or_null("Puerta")
		if puerta48 == null:
			faltan_casa48.append("falta la puerta")
		else:
			if puerta48.get_node_or_null("Hoja") == null:
				faltan_casa48.append("la puerta no tiene la hoja")
			if absf((puerta48 as Node3D).rotation.y) <= 0.5:
				faltan_casa48.append(
					"la puerta esta a %.2f rad (deberia estar abierta)" % (puerta48 as Node3D).rotation.y
				)
	_reportar(48, "Casa completa: bano, dos ventanas, siete huecos y SSAO", faltan_casa48)

	# 49. El disparo a distancia: el enemigo tira bala con punteria buena
	# (certera) y con punteria mala (se desvia de sala entera), y con la
	# bandera dispara_a_distancia en false no dispara ni en 30 frames.
	var faltan_disparo49: Array[String] = []
	if escena_enemigo == null:
		faltan_disparo49.append("no carga res://scenes/enemigo.tscn")
	elif nivel_instanciado == null or jugador == null:
		faltan_disparo49.append("no hay nivel o jugador")
	else:
		if load("res://scripts/proyectil.gd") as Script == null:
			faltan_disparo49.append("no carga res://scripts/proyectil.gd")

		# El enemigo tiene los seis mandos del disparo.
		var propiedades49: Dictionary = {}
		var enem_prueba49: Node = escena_enemigo.instantiate()
		for prop49: Dictionary in enem_prueba49.get_property_list():
			propiedades49[String(prop49.get("name", ""))] = true
		for nombre_prop49: String in [
			"dispara_a_distancia", "precision", "dano_disparo",
			"cooldown_disparo", "alcance_disparo", "velocidad_proyectil",
		]:
			if not propiedades49.has(nombre_prop49):
				faltan_disparo49.append("falta el export %s" % nombre_prop49)
		enem_prueba49.free()

		# Revivimos al jugador (la prueba 32 lo dejo en cero) y lo plantamos
		# en la linea de tiro: el enemigo esta a 2.1 m, dentro de rango y con
		# vista libre por el centro del dormitorio.
		var vida_nodo49: Node = jugador.get_node_or_null("Vida")
		if vida_nodo49 == null:
			faltan_disparo49.append("el jugador no tiene nodo Vida")
		else:
			vida_nodo49.call("reiniciar")
		(jugador as Node3D).global_position = Vector3(0, 0.1, 0.5)
		await _frames(5)
		var vida_antes49: int = int(jugador.call("vida_actual"))
		if vida_antes49 <= 0:
			faltan_disparo49.append("la vida no revive (%d)" % vida_antes49)

		# Un enemigo certero al fondo: la bala sale, cuelga del nivel y avanza.
		var enem49: Node = escena_enemigo.instantiate()
		enem49.set("precision", 1.0)
		nivel_instanciado.add_child(enem49)
		(enem49 as Node3D).global_position = Vector3(0, 0.1, -1.6)
		await _frames(6)
		var bolas49: Array[Node] = _buscar_proyectil()
		if bolas49.is_empty():
			faltan_disparo49.append("no salio ninguna bala tras 6 frames")
		else:
			if bolas49[0].get_parent() != nivel_instanciado:
				faltan_disparo49.append("la bala no cuelga del nivel")
			var pos_bola49: Vector3 = (bolas49[0] as Node3D).global_position
			await _frames(3)
			var bolas2_49: Array[Node] = _buscar_proyectil()
			if bolas2_49.is_empty():
				faltan_disparo49.append("la bala desaparecio antes de tiempo")
			else:
				var movida49: float = (bolas2_49[0] as Node3D).global_position.distance_to(pos_bola49)
				if movida49 < 0.2:
					faltan_disparo49.append("la bala solo avanzo %.2f m en 3 frames" % movida49)

		# Con punteria 1.0 la bala tiene que llegar: la vida baja en el plazo
		# del tiro (unos 16 frames) y el golpe a distancia mas tardio (aviso
		# incluido) no llega hasta el frame 56, asi que solo pudo ser la bala.
		await _frames(22)
		var vida_despues49: int = int(jugador.call("vida_actual"))
		if vida_despues49 >= vida_antes49:
			faltan_disparo49.append(
				"vida %d -> %d: la bala no dio al jugador" % [vida_antes49, vida_despues49]
			)

		# La punteria medida con la semilla fija: 1.0 casi sin desvio y 0.0
		# con desvio de sala entera (el mismo numero en cada corrida).
		if enem49 != null and is_instance_valid(enem49):
			var rng49: RandomNumberGenerator = enem49.get("aleatorio") as RandomNumberGenerator
			if rng49 == null:
				faltan_disparo49.append("el enemigo no tiene su RNG")
			else:
				var base49: Vector3 = Vector3.FORWARD
				enem49.set("precision", 1.0)
				rng49.seed = 99
				var max_buena49: float = 0.0
				for i_buena49: int in 12:
					var d_buena49: Vector3 = enem49.call("_direccion_con_error", base49)
					max_buena49 = maxf(max_buena49, acos(clampf(d_buena49.dot(base49), -1.0, 1.0)))
				if max_buena49 >= 0.03:
					faltan_disparo49.append("punteria 1.0 se desvia %.3f rad" % max_buena49)
				enem49.set("precision", 0.0)
				rng49.seed = 99
				var max_mala49: float = 0.0
				for i_mala49: int in 12:
					var d_mala49: Vector3 = enem49.call("_direccion_con_error", base49)
					max_mala49 = maxf(max_mala49, acos(clampf(d_mala49.dot(base49), -1.0, 1.0)))
				if max_mala49 <= 0.08:
					faltan_disparo49.append("punteria 0.0 solo se desvia %.3f rad" % max_mala49)
			enem49.queue_free()
			await _frames(3)

		# Con la bandera en false no dispara en NINGUN momento de los 30
		# frames. Se muestrea cada 6 frames porque la bala dura ~16: un unico
		# chequeo tardio no la veria nunca y ese comprobador no podria fallar.
		var enem_callado49: Node = escena_enemigo.instantiate()
		enem_callado49.set("dispara_a_distancia", false)
		nivel_instanciado.add_child(enem_callado49)
		(enem_callado49 as Node3D).global_position = Vector3(0, 0.1, -1.6)
		for i_callado49: int in 5:
			await _frames(6)
			if not _buscar_proyectil().is_empty():
				faltan_disparo49.append("dispara aunque dispara_a_distancia esta en false")
				break
		enem_callado49.queue_free()
		await _frames(3)

		# Al acabar no queda ninguna bala volando (anti ObjectDB leak).
		var sobras49: Array[Node] = _buscar_proyectil()
		if not sobras49.is_empty():
			faltan_disparo49.append("quedan %d proyectiles sin borrar" % sobras49.size())
	_reportar(49, "Disparo a distancia con punteria buena y mala", faltan_disparo49)

	# 50. Ambiente PSX: niebla de profundidad, cielo atardecer (no el
	# default), ventanas con su luz entrante, filtro fullscreen que no come
	# input y motas ambientales encendidas.
	var faltan_ambiente50: Array[String] = []
	if nivel_instanciado == null:
		faltan_ambiente50.append("no hay nivel")
	else:
		var entorno50: WorldEnvironment = nivel_instanciado.get_node_or_null("Entorno") as WorldEnvironment
		if entorno50 == null or entorno50.environment == null:
			faltan_ambiente50.append("falta Entorno o su environment")
		else:
			var env50: Environment = entorno50.environment
			if not env50.fog_enabled:
				faltan_ambiente50.append("la niebla esta apagada")
			if env50.fog_depth_begin < 8.0:
				faltan_ambiente50.append(
					"la niebla empieza a %.1f m (deberia respetar las salas)" % env50.fog_depth_begin
				)
			if env50.fog_depth_end < 30.0:
				faltan_ambiente50.append("la niebla acaba a %.1f m" % env50.fog_depth_end)
			# La niebla es gris fria, no un tinte naranja sobre todo.
			if absf(env50.fog_light_color.r - env50.fog_light_color.b) > 0.15:
				faltan_ambiente50.append(
					"la niebla tira a naranja (%s)" % str(env50.fog_light_color)
				)
			var cielo50: ProceduralSkyMaterial = null
			if env50.sky != null:
				cielo50 = env50.sky.sky_material as ProceduralSkyMaterial
			if cielo50 == null:
				faltan_ambiente50.append("el cielo no es un ProceduralSkyMaterial")
			else:
				if cielo50.sky_top_color.b < 0.5:
					faltan_ambiente50.append("el cenit no es azul (%s)" % str(cielo50.sky_top_color))
				var luz_h50: float = (
					cielo50.sky_horizon_color.r + cielo50.sky_horizon_color.g + cielo50.sky_horizon_color.b
				) / 3.0
				if luz_h50 < 0.6:
					faltan_ambiente50.append("el horizonte esta apagado (%s)" % str(cielo50.sky_horizon_color))
		for nombre_luz50: String in ["LuzVentanaNorte", "LuzVentanaSur"]:
			var luz50: OmniLight3D = _buscar48(nombre_luz50) as OmniLight3D
			if luz50 == null:
				faltan_ambiente50.append("falta %s" % nombre_luz50)
			elif luz50.light_energy <= 0.2:
				faltan_ambiente50.append("%s apagada (%.2f)" % [nombre_luz50, luz50.light_energy])
		var hud50: Node = nivel_instanciado.get_node_or_null("HUD")
		var filtro50: ColorRect = null
		if hud50 != null:
			filtro50 = hud50.get_node_or_null("FiltroPSX") as ColorRect
		if filtro50 == null:
			faltan_ambiente50.append("falta el FiltroPSX del HUD")
		else:
			if filtro50.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				faltan_ambiente50.append("el filtro se come el input")
			if filtro50.material == null:
				faltan_ambiente50.append("el filtro no tiene material")
		for nombre_mota50: String in ["Motas/MotasDormitorio", "Motas/MotasSalon"]:
			var mota50: GPUParticles3D = nivel_instanciado.get_node_or_null(nombre_mota50) as GPUParticles3D
			if mota50 == null:
				faltan_ambiente50.append("falta %s" % nombre_mota50)
			elif not mota50.emitting:
				faltan_ambiente50.append("%s apagadas" % nombre_mota50)
	_reportar(50, "Ambiente PSX: niebla, cielo, ventanas y filtro", faltan_ambiente50)

	# 51. Decorado 2D y destello del enemigo: cuadros con textura generada,
	# zocalos y marcos en su grupo, y al disparar el enemigo se le enciende
	# la boca y se apaga sola.
	var faltan_decorado51: Array[String] = []
	if nivel_instanciado == null:
		faltan_decorado51.append("no hay nivel")
	else:
		var conteo51: int = 0
		for nodo51: Node in get_nodes_in_group("decorado"):
			if is_instance_valid(nodo51):
				conteo51 += 1
		if conteo51 < 9:
			faltan_decorado51.append("solo hay %d piezas de decorado (deberian ser 9 o mas)" % conteo51)
		var cuadro51: MeshInstance3D = nivel_instanciado.get_node_or_null("Decorado/CuadroPez") as MeshInstance3D
		if cuadro51 == null:
			faltan_decorado51.append("falta el CuadroPez del dormitorio")
		else:
			var mat51: StandardMaterial3D = cuadro51.get_active_material(0) as StandardMaterial3D
			if mat51 == null or mat51.albedo_texture == null:
				faltan_decorado51.append("el cuadro no tiene textura generada")
		# El destello de la boca al disparar: sale con el tiro y se borra.
		if escena_enemigo == null:
			faltan_decorado51.append("no carga res://scenes/enemigo.tscn")
		elif jugador == null:
			faltan_decorado51.append("no hay jugador")
		else:
			(jugador as Node3D).global_position = Vector3(0, 0.1, 0.5)
			var enem51: Node = escena_enemigo.instantiate()
			enem51.set("precision", 1.0)
			nivel_instanciado.add_child(enem51)
			(enem51 as Node3D).global_position = Vector3(0, 0.1, -1.6)
			await _frames(3)
			if nivel_instanciado.get_node_or_null("DestelloBoca") == null:
				faltan_decorado51.append("al disparar no sale el destello de la boca")
			await _frames(12)
			if nivel_instanciado.get_node_or_null("DestelloBoca") != null:
				faltan_decorado51.append("el destello no se borra solo")
			enem51.queue_free()
			await _frames(3)
			var sobras51: Array[Node] = _buscar_proyectil()
			if not sobras51.is_empty():
				faltan_decorado51.append("quedan %d proyectiles sin borrar" % sobras51.size())
	_reportar(51, "Decorado 2D y destello del enemigo", faltan_decorado51)

	# 52. GUI con sentido: el HUD dice en que cuarto estas y pinta un
	# minimapa con el jugador, los enemigos y los ratones.
	var faltan_radar52: Array[String] = []
	var hud52: HUD = nivel_instanciado.get_node_or_null("HUD/Reticula") as HUD
	if hud52 == null:
		faltan_radar52.append("falta el HUD del nivel")
	else:
		if not bool(hud52.get("minimapa")):
			faltan_radar52.append("el minimapa esta apagado")
		if hud52.call("zona_de", Vector3(0, 0, 0.5)) != "Dormitorio":
			faltan_radar52.append("el dormitorio no sale como Dormitorio")
		if hud52.call("zona_de", Vector3(0, 0, 5.0)) != "Salón":
			faltan_radar52.append("el salon no sale como Salón")
		if hud52.call("zona_de", Vector3(5.0, 0, 0.0)) != "Pasillo":
			faltan_radar52.append("el pasillo no sale como Pasillo")
		if hud52.call("zona_de", Vector3(5.0, 0, 3.0)) != "Cocina":
			faltan_radar52.append("la cocina no sale como Cocina")
		if str(hud52.get("zona_actual")) != "Dormitorio":
			faltan_radar52.append(
				"la zona actual es %s y el jugador esta en el dormitorio" % str(hud52.get("zona_actual"))
			)
	_reportar(52, "GUI: cuarto actual y minimapa en el HUD", faltan_radar52)

	# 53. Mapa dinamico: los enemigos patrullan en QUIETO sin golpear, y los
	# ratones huyen del jugador en movimiento.
	var faltan_dinamico53: Array[String] = []
	if escena_enemigo == null:
		faltan_dinamico53.append("no carga res://scenes/enemigo.tscn")
	elif nivel_instanciado == null or jugador == null:
		faltan_dinamico53.append("no hay nivel o jugador")
	else:
		# Patrulla: casi ciego y lejos, sigue en QUIETO pero se mueve.
		var enem53: Node = escena_enemigo.instantiate()
		enem53.set("alcance_deteccion", 0.5)
		nivel_instanciado.add_child(enem53)
		(enem53 as Node3D).global_position = Vector3(3.0, 0.1, 3.0)
		await _frames(5)
		var pos_antes53: Vector3 = (enem53 as Node3D).global_position
		await _frames(60)
		var movido53: float = Vector2(
			(enem53 as Node3D).global_position.x - pos_antes53.x,
			(enem53 as Node3D).global_position.z - pos_antes53.z
		).length()
		if int(enem53.get("estado")) != 0:
			faltan_dinamico53.append("el enemigo salio de QUIETO sin detectar nada")
		if movido53 < 0.3:
			faltan_dinamico53.append("el enemigo no patrulla (solo %.2f m en 60 frames)" % movido53)
		enem53.queue_free()
		await _frames(3)
		# Huida: con el jugador en marcha cerca, el raton corre (instancia
		# propia: el nivel ya no trae). Se asienta primero al jugador (en el
		# aire no corre) y se muestrea hasta cazarlo.
		var fugitivo53: Node = _crear_raton(Vector3(0.6, 0.0, 0.5))
		if fugitivo53 == null:
			faltan_dinamico53.append("no se puede instanciar el raton")
		else:
			(jugador as Node3D).global_position = Vector3(0, 0.1, 0.5)
			(fugitivo53 as Node3D).global_position = Vector3(0.6, 0.0, 0.5)
			await _frames(10)
			Input.action_press("move_forward")
			var corre53: Vector3 = Vector3.ZERO
			for i_huida53: int in 15:
				await _frames(2)
				corre53 = fugitivo53.get("velocity") as Vector3
				if corre53 != null and Vector2(corre53.x, corre53.z).length() >= 1.5:
					break
			Input.action_release("move_forward")
			if corre53 == null or Vector2(corre53.x, corre53.z).length() < 1.5:
				faltan_dinamico53.append("el raton no huye del jugador en marcha")
			fugitivo53.queue_free()
			await _frames(3)
	_reportar(53, "Mapa dinamico: patrulla enemiga y ratones que huyen", faltan_dinamico53)

	# 54. Dos tipos de enemigos: rojos a distancia y naranjas a cuchillo.
	var faltan_tipos54: Array[String] = []
	if nivel_instanciado == null:
		faltan_tipos54.append("no hay nivel")
	else:
		var rojos54: Array[String] = ["Enemigo1", "Enemigo3", "Enemigo5", "Enemigo6"]
		var naranjas54: Array[String] = ["Enemigo2", "Enemigo4", "Enemigo7"]
		var rojo54: Color = Color(0.5, 0.09, 0.14, 1)
		var naranja54: Color = Color(0.95, 0.5, 0.12, 1)
		for nombre54: String in rojos54:
			var rojo_nodo54: Node = nivel_instanciado.get_node_or_null(nombre54)
			if rojo_nodo54 == null:
				faltan_tipos54.append("falta %s" % nombre54)
				continue
			var modelo_rojo54: Node = rojo_nodo54.get_node_or_null("Modelo")
			if modelo_rojo54 == null or (modelo_rojo54.get("color_pelo") as Color) != rojo54:
				faltan_tipos54.append("%s no es rojo" % nombre54)
			var cuchillo_rojo54: Node3D = rojo_nodo54.get_node_or_null("Modelo/Cuchillo") as Node3D
			if cuchillo_rojo54 == null:
				faltan_tipos54.append("%s no tiene cuchillo" % nombre54)
			elif cuchillo_rojo54.visible:
				faltan_tipos54.append("%s ensena el cuchillo y es rojo" % nombre54)
		for nombre54: String in naranjas54:
			var naranja_nodo54: Node = nivel_instanciado.get_node_or_null(nombre54)
			if naranja_nodo54 == null:
				faltan_tipos54.append("falta %s" % nombre54)
				continue
			var modelo_naranja54: Node = naranja_nodo54.get_node_or_null("Modelo")
			if modelo_naranja54 == null or (modelo_naranja54.get("color_pelo") as Color) != naranja54:
				faltan_tipos54.append("%s no es naranja" % nombre54)
			var cuchillo_naranja54: Node3D = naranja_nodo54.get_node_or_null("Modelo/Cuchillo") as Node3D
			if cuchillo_naranja54 == null or not cuchillo_naranja54.visible:
				faltan_tipos54.append("%s no ensena el cuchillo" % nombre54)
			if int(naranja_nodo54.get("dano")) != 8:
				faltan_tipos54.append("%s pega %d (el cuchillo hace poco)" % [nombre54, int(naranja_nodo54.get("dano"))])
	_reportar(54, "Rojos a distancia y naranjas a cuchillo", faltan_tipos54)

	# 55. Casa grande y viva: puertas anchas, segunda pelota y cortinas que
	# se balancean solas.
	var faltan_viva55: Array[String] = []
	if nivel_instanciado == null:
		faltan_viva55.append("no hay nivel")
	else:
		var anchas55: Array = [
			["sur del dormitorio", "MuroSurOeste", "MuroSurEste", 0],
			["este del dormitorio", "MuroEsteN", "MuroEsteS", 1],
			["del salon a la cocina", "MuroEsteSalonA", "MuroEsteSalonB", 1],
			["del pasillo a la cocina", "MuroPasilloSurA", "MuroPasilloSurB", 0],
		]
		for hueco55: Array in anchas55:
			var lado_a55: Vector4 = _caja48(_buscar48(hueco55[1] as String))
			var lado_b55: Vector4 = _caja48(_buscar48(hueco55[2] as String))
			if lado_a55 == Vector4.ZERO or lado_b55 == Vector4.ZERO:
				faltan_viva55.append("no se puede medir la puerta %s" % str(hueco55[0]))
				continue
			var ancho55: float
			if int(hueco55[3]) == 0:
				ancho55 = (lado_b55.x - lado_b55.z * 0.5) - (lado_a55.x + lado_a55.z * 0.5)
			else:
				ancho55 = (lado_b55.y - lado_b55.w * 0.5) - (lado_a55.y + lado_a55.w * 0.5)
			if ancho55 < 1.0:
				faltan_viva55.append("la puerta %s mide %.2f m" % [str(hueco55[0]), ancho55])
		if nivel_instanciado.get_node_or_null("Pelota2") == null:
			faltan_viva55.append("falta la segunda pelota")
		var deco55: Node = nivel_instanciado.get_node_or_null("Decorado")
		if deco55 == null:
			faltan_viva55.append("falta el Decorado del dormitorio")
		elif float(deco55.get("tiempo_cortina")) <= 0.0:
			faltan_viva55.append("las cortinas no se balancean")
	_reportar(55, "Casa grande y viva: puertas, pelota y cortinas", faltan_viva55)

	# 56. Menu dev de iluminacion: presets que se aplican de verdad, ciclo
	# de AO que vuelve al inicio, ciclo de filtros, ciclo de niebla y ayuda,
	# todo con aviso.
	var faltan_dev56: Array[String] = []
	if nivel_instanciado == null:
		faltan_dev56.append("no hay nivel")
	else:
		var dev56: Node = nivel_instanciado.get_node_or_null("DevLuces")
		if dev56 == null:
			faltan_dev56.append("falta el nodo DevLuces")
		elif not dev56.has_method("aplicar_preset"):
			faltan_dev56.append("DevLuces no tiene aplicar_preset()")
		else:
			var presets56: Array = dev56.get("PRESETS") as Array
			if presets56 == null or presets56.size() < 3:
				faltan_dev56.append("menos de 3 presets de ambiente")
			else:
				dev56.call("aplicar_preset", 2)
				if int(dev56.get("preset_actual")) != 2:
					faltan_dev56.append("el preset no cambia al 2")
				var entorno56: WorldEnvironment = nivel_instanciado.get_node_or_null("Entorno") as WorldEnvironment
				var cielo56: ProceduralSkyMaterial = entorno56.environment.sky.sky_material as ProceduralSkyMaterial
				var quiere56: Color = (presets56[2] as Dictionary).get("cenit", Color.BLACK)
				if not cielo56.sky_top_color.is_equal_approx(quiere56):
					faltan_dev56.append("el preset 2 no pinta el cenit")
				dev56.call("aplicar_preset", 0)
			var env56: Environment = (nivel_instanciado.get_node_or_null("Entorno") as WorldEnvironment).environment
			var inicio_ssao56: bool = env56.ssao_enabled
			var inicio_ssil56: bool = env56.ssil_enabled
			for i56: int in 4:
				dev56.call("siguiente_modo_ao")
			if env56.ssao_enabled != inicio_ssao56 or env56.ssil_enabled != inicio_ssil56:
				faltan_dev56.append("el ciclo de AO no vuelve al inicio")
			dev56.call("siguiente_modo_ao")
			if env56.ssao_enabled == inicio_ssao56 and env56.ssil_enabled == inicio_ssil56:
				faltan_dev56.append("el modo AO no cambia al ciclar")
			for i56: int in 3:
				dev56.call("siguiente_modo_ao")
			# Filtros: 4 modos que vuelven al inicio (Nada) y cambian al ciclar.
			var hud56: Node = nivel_instanciado.get_node_or_null("HUD")
			var filtro56: CanvasItem = null
			if hud56 != null:
				filtro56 = hud56.get_node_or_null("FiltroPSX") as CanvasItem
			if filtro56 == null:
				faltan_dev56.append("falta el FiltroPSX")
			else:
				for i56: int in 4:
					dev56.call("siguiente_filtro")
				if filtro56.visible:
					faltan_dev56.append("el ciclo de filtros no vuelve a Nada")
				dev56.call("siguiente_filtro")
				if not filtro56.visible:
					faltan_dev56.append("el filtro no se enciende al ciclar")
				for i56: int in 3:
					dev56.call("siguiente_filtro")
				if filtro56.visible:
					faltan_dev56.append("el filtro no vuelve a Nada")
			# Niebla: 3 niveles que vuelven al inicio (Suave).
			var inicio_niebla56: bool = env56.fog_enabled
			var inicio_iso56: float = env56.fog_depth_begin
			for i56: int in 3:
				dev56.call("siguiente_niebla")
			if env56.fog_enabled != inicio_niebla56:
				faltan_dev56.append("el ciclo de niebla no vuelve al inicio")
			dev56.call("siguiente_niebla")
			if env56.fog_enabled == inicio_niebla56 and env56.fog_depth_begin == inicio_iso56:
				faltan_dev56.append("la niebla no cambia al ciclar")
			for i56: int in 2:
				dev56.call("siguiente_niebla")
			# Ayuda: toggle por llamada.
			var hud_r56: Node = nivel_instanciado.get_node_or_null("HUD/Reticula")
			if hud_r56 == null or not hud_r56.has_method("alternar_ayuda"):
				faltan_dev56.append("el HUD no tiene alternar_ayuda()")
			else:
				hud_r56.call("alternar_ayuda")
				if not bool(hud_r56.get("mostrar_ayuda")):
					faltan_dev56.append("la ayuda no se enciende")
				hud_r56.call("alternar_ayuda")
				if bool(hud_r56.get("mostrar_ayuda")):
					faltan_dev56.append("la ayuda no se apaga")
	_reportar(56, "Menu dev de iluminacion: presets, filtros y ayuda", faltan_dev56)

	# 57. El melee no atraviesa: desde lo alto de un muro o al otro lado,
	# aunque el plano este pegado, no hay aviso ni golpe (falta vista libre).
	var faltan_muro57: Array[String] = []
	if escena_enemigo == null:
		faltan_muro57.append("no carga res://scenes/enemigo.tscn")
	elif nivel_instanciado == null or jugador == null:
		faltan_muro57.append("no hay nivel o jugador")
	else:
		var vida_nodo57: Node = jugador.get_node_or_null("Vida")
		if vida_nodo57 == null:
			faltan_muro57.append("el jugador no tiene nodo Vida")
		else:
			vida_nodo57.call("reiniciar")
			# A: jugador en lo alto del muro sur, naranja debajo.
			(jugador as Node3D).global_position = Vector3(0.95, 2.5, 2.2)
			await _frames(10)
			var enem_alto57: Node = escena_enemigo.instantiate()
			enem_alto57.set("ataca_cuerpo_a_cuerpo", true)
			enem_alto57.set("dispara_a_distancia", false)
			nivel_instanciado.add_child(enem_alto57)
			(enem_alto57 as Node3D).global_position = Vector3(0.95, 0.1, 0.5)
			var vida_antes57: int = int(jugador.call("vida_actual"))
			await _frames(90)
			if int(jugador.call("vida_actual")) != vida_antes57:
				faltan_muro57.append("desde el muro le pegaron igual (%d -> %d)" % [vida_antes57, int(jugador.call("vida_actual"))])
			if int(enem_alto57.get("estado")) == 2 or int(enem_alto57.get("estado")) == 3:
				faltan_muro57.append("el enemigo avisa o golpea sin ver al jugador")
			enem_alto57.queue_free()
			await _frames(3)
			# B: pegados a caras opuestas del mismo muro.
			(jugador as Node3D).global_position = Vector3(0.95, 0.1, 2.5)
			await _frames(10)
			var enem_muro57: Node = escena_enemigo.instantiate()
			enem_muro57.set("ataca_cuerpo_a_cuerpo", true)
			enem_muro57.set("dispara_a_distancia", false)
			nivel_instanciado.add_child(enem_muro57)
			(enem_muro57 as Node3D).global_position = Vector3(0.95, 0.1, 1.9)
			enem_muro57.set("estado", 1)
			var vida_antes_b57: int = int(jugador.call("vida_actual"))
			await _frames(60)
			if int(jugador.call("vida_actual")) != vida_antes_b57:
				faltan_muro57.append("a traves del muro le pegaron igual")
			if int(enem_muro57.get("estado")) == 2 or int(enem_muro57.get("estado")) == 3:
				faltan_muro57.append("el enemigo avisa a traves del muro")
			enem_muro57.queue_free()
			await _frames(3)
			# C: justo encima, con vista libre pero fuera de alcance vertical.
			(jugador as Node3D).global_position = Vector3(0, 2.8, 0.5)
			var enem_alto57b: Node = escena_enemigo.instantiate()
			enem_alto57b.set("ataca_cuerpo_a_cuerpo", true)
			enem_alto57b.set("dispara_a_distancia", false)
			nivel_instanciado.add_child(enem_alto57b)
			(enem_alto57b as Node3D).global_position = Vector3(0, 0.1, 0.5)
			var vida_antes_c57: int = int(jugador.call("vida_actual"))
			await _frames(8)
			if int(jugador.call("vida_actual")) != vida_antes_c57:
				faltan_muro57.append("desde abajo le pegaron igual")
			if int(enem_alto57b.get("estado")) == 2 or int(enem_alto57b.get("estado")) == 3:
				faltan_muro57.append("el enemigo avisa en vertical sin alcance")
			enem_alto57b.queue_free()
			await _frames(3)
	_reportar(57, "El melee no atraviesa muros ni alturas", faltan_muro57)


func _frames(cantidad: int) -> void:
	for i: int in cantidad:
		await physics_frame


# Deja el blanco en la linea de punteria de la camara, a 1 m (dentro del
# dormitorio de 5x4: a 2 m el rayo chocaria con el muro norte antes de
# llegar), con la caja de colision centrada en el punto de mira.
func _colocar_blanco_en_punteria(blanco: Node, camara: Camera3D) -> void:
	var punteria: Vector3 = camara.global_position - camara.global_transform.basis.z * 1.0
	var centro: float = 1.2
	var colision: CollisionShape3D = blanco.get_node_or_null("CollisionShape3D")
	if colision != null:
		centro = colision.position.y
	blanco.global_position = Vector3(punteria.x, maxf(punteria.y - centro, 0.0), punteria.z)


# Raton propio para los tests (desde v0.9 el nivel ya no trae blancos):
# instancia objetivo.tscn, lo cuelga del nivel y lo coloca. El que llama
# lo libera con queue_free.
func _crear_raton(pos: Vector3) -> Node:
	var escena: PackedScene = load("res://scenes/objetivo.tscn") as PackedScene
	if escena == null or nivel_instanciado == null:
		return null
	var raton: Node = escena.instantiate()
	nivel_instanciado.add_child(raton)
	(raton as Node3D).global_position = pos
	return raton


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
func _scripts_del_proyecto() -> Array[String]:
	var salida: Array[String] = []
	var dir: DirAccess = DirAccess.open(RUTA_SCRIPTS)
	if dir == null:
		return salida
	for archivo: String in dir.get_files():
		if archivo.ends_with(".gd"):
			salida.append(RUTA_SCRIPTS + "/" + archivo)
	salida.sort()
	return salida


func _contar_grupo(nodo: Node, grupo: String) -> int:
	var total: int = 1 if nodo.is_in_group(grupo) else 0
	for hijo: Node in nodo.get_children():
		total += _contar_grupo(hijo, grupo)
	return total


# Cuenta los reproductores 3D (los temporales del impacto) bajo un nodo.
func _contar_reproductores3d(nodo: Node) -> int:
	var total: int = 0
	for hijo: Node in nodo.get_children():
		if hijo is AudioStreamPlayer3D:
			total += 1
	return total


# Localiza los proyectiles vivos colgando ahora mismo del nivel.
func _buscar_proyectil() -> Array[Node]:
	var salida: Array[Node] = []
	if nivel_instanciado == null:
		return salida
	for hijo: Node in nivel_instanciado.get_children():
		var guion: Script = hijo.get_script()
		if guion != null and String(guion.resource_path).ends_with("proyectil.gd"):
			salida.append(hijo)
	return salida


# Localiza un nodo del nivel: los del dormitorio cuelgan directo y los de la
# casa cuelgan de la instancia Casa, asi que se busca en los dos sitios.
func _buscar48(nombre: String) -> Node:
	if nivel_instanciado == null:
		return null
	var nodo: Node = nivel_instanciado.get_node_or_null(nombre)
	if nodo == null:
		nodo = nivel_instanciado.get_node_or_null("Casa/" + nombre)
	return nodo


# Caja de colision en coordenadas del mundo de un nodo con un CollisionShape3D
# con BoxShape3D. Devuelve Vector4(centro_x, centro_z, ancho_x, fondo_z); si el
# nodo no esta o no es una caja, Vector4.ZERO (nunca confundir con un hueco).
func _caja48(nodo: Node) -> Vector4:
	if nodo == null:
		return Vector4.ZERO
	var colision: CollisionShape3D = nodo.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if colision == null:
		return Vector4.ZERO
	var caja: BoxShape3D = colision.shape as BoxShape3D
	if caja == null:
		return Vector4.ZERO
	var centro: Vector3 = (nodo as Node3D).global_position + colision.position
	return Vector4(centro.x, centro.z, caja.size.x, caja.size.z)


func _reportar(numero: int, titulo: String, faltantes: Array[String]) -> void:
	if faltantes.is_empty():
		_ok(numero, titulo)
	else:
		_falta(numero, titulo, faltantes)


func _ok(numero: int, titulo: String) -> void:
	print("OK %d: %s" % [numero, titulo])


func _falta(numero: int, titulo: String, detalles: Array[String]) -> void:
	errores += 1
	var extra: String = ""
	if not detalles.is_empty():
		extra = " -> falta: " + _unir(detalles)
	print("FALTA %d: %s%s" % [numero, titulo, extra])


func _aviso(numero: int, texto: String) -> void:
	avisos += 1
	print("AVISO %d: %s" % [numero, texto])


func _unir(partes: Array[String]) -> String:
	var salida: String = ""
	for i: int in partes.size():
		if i > 0:
			salida += ", "
		salida += partes[i]
	return salida


func _resumen() -> void:
	# Parar el audio y esperar unos frames antes de salir. En headless el
	# driver de audio nunca da por terminado un sonido, y si el stop no llega
	# a procesarse antes de destruir el arbol Godot reporta un ObjectDB leak
	# por cada pista (el viento esta pensado para sonar siempre, no es un bug
	# del juego). Si aqui, tras parar todo, sigue habiendo leak, ese si es real.
	for sonido: Node in get_nodes_in_group("sonido"):
		for hijo: Node in sonido.get_children():
			if hijo is AudioStreamPlayer:
				(hijo as AudioStreamPlayer).stop()
			elif hijo is AudioStreamPlayer3D:
				(hijo as AudioStreamPlayer3D).stop()
	await _frames(6)
	if avisos > 0:
		print("AVISOS: %d (no cuentan como fallo)" % avisos)
	if errores == 0:
		print("VERIFICACION OK: 0 errores")
		quit(0)
	else:
		print("VERIFICACION FALLO: %d errores" % errores)
		quit(1)
