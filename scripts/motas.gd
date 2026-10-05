extends Node3D

# Motas de polvo ambientales: dos emisores GPUParticles3D que viven en el
# nivel (dormitorio y salon) y se quedan encendidos, como los del jugador.
# Se montan aqui por codigo, con el mismo estilo que _nueva_particula de
# player.gd: malla quad translucida + material de proceso propio.

const COLOR_MOTA: Color = Color(0.9, 0.85, 0.7, 0.35)
const TAMANO_MOTA: float = 0.03


func _ready() -> void:
	_nueva_mota("MotasDormitorio", Vector3(0.0, 1.0, 0.0))
	_nueva_mota("MotasSalon", Vector3(0.0, 1.2, 4.6))


func _nueva_mota(nombre: String, posicion: Vector3) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = nombre
	p.amount = 20
	p.lifetime = 4.0
	p.one_shot = false
	p.emitting = true
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6.0, -2.0, -6.0), Vector3(12.0, 5.0, 12.0))
	p.draw_pass_1 = _malla_mota()
	p.process_material = _material_proceso()
	add_child(p)
	p.position = posicion
	return p


# Cuadradito translucido y sin sombras: la mota se ve igual a cualquier altura.
func _malla_mota() -> QuadMesh:
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(TAMANO_MOTA, TAMANO_MOTA)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOR_MOTA
	malla.material = material
	return malla


# Flotan hacia arriba muy despacio y en todas direcciones (spread 180): una
# gravedad bajita las hace trepar en lugar de caer.
func _material_proceso() -> ParticleProcessMaterial:
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.15
	material.gravity = Vector3(0.0, 0.02, 0.0)
	return material
