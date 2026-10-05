extends Node3D
class_name Proyectil

# Bala del enemigo: viaja en linea recta (sin homing) y comprueba cada frame
# el tramo recorrido con un rayo de mascara 1|2 (escenario y jugador). Si
# golpea a alguien con recibir_dano() le reparte el dano; despues se borra
# solo: al impactar, al terminar su alcance o al agotar la vida de seguridad.
# Sin esa red de seguridad, una bala que no choca nunca se acumularia hasta
# el ObjectDB leak del cierre. Malla tipica, nada de GPUParticles3D: en
# headless no hay GPU que simule particulas.

@export var velocidad: float = 9.0
@export var dano: int = 10
@export var alcance: float = 7.0
@export var vida_seguridad: float = 4.0

const MASCARA_IMPACTO: int = 3

var direccion: Vector3 = Vector3.FORWARD
var recorrido: float = 0.0
var tiempo_vida: float = 0.0


func _ready() -> void:
	var malla: MeshInstance3D = MeshInstance3D.new()
	malla.name = "Bola"
	var esfera: SphereMesh = SphereMesh.new()
	esfera.radius = 0.02
	esfera.height = 0.04
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.75, 0.3)
	material.emission_energy_multiplier = 3.0
	esfera.material = material
	malla.mesh = esfera
	add_child(malla)
	if direccion.length_squared() < 0.0001:
		direccion = Vector3.FORWARD
	direccion = direccion.normalized()


func _physics_process(delta: float) -> void:
	tiempo_vida += delta
	if tiempo_vida >= vida_seguridad:
		queue_free()
		return

	var paso: float = velocidad * delta
	var mundo: World3D = get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return
	var destino: Vector3 = global_position + direccion * paso
	var consulta: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, destino, MASCARA_IMPACTO
	)
	var golpe: Dictionary = mundo.direct_space_state.intersect_ray(consulta)
	if not golpe.is_empty():
		var golpeado: Object = golpe.get("collider")
		if golpeado is Node and (golpeado as Node).has_method("recibir_dano"):
			(golpeado as Node).call("recibir_dano", dano)
		_chispa()
		queue_free()
		return

	global_position = destino
	recorrido += paso
	if recorrido >= alcance:
		queue_free()


# Chispa breve en el punto de impacto: malla + tween, que en headless si
# funciona, y se borra sola a los 0.12 s.
func _chispa() -> void:
	if get_parent() == null:
		return
	var chispa: MeshInstance3D = MeshInstance3D.new()
	chispa.name = "Chispa"
	var esfera: SphereMesh = SphereMesh.new()
	esfera.radius = 0.05
	esfera.height = 0.1
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.85, 0.4)
	material.emission_energy_multiplier = 4.0
	esfera.material = material
	chispa.mesh = esfera
	get_parent().add_child(chispa)
	chispa.global_position = global_position
	var brillo: Tween = chispa.create_tween()
	brillo.tween_property(chispa, "scale", Vector3(0.001, 0.001, 0.001), 0.12)
	brillo.tween_callback(chispa.queue_free)
