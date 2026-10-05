extends Node3D
class_name ModeloGato

# Modelo de gato compartido: lo instancian el jugador y los enemigos. Los
# colores se aplican POR INSTANCIA duplicando materiales, porque los
# sub_resource se comparten y tintaria a todos los gatos a la vez. Los
# arboles ajenos al gato (la pistola cuelga de aqui) se saltan.

@export var color_pelo: Color = Color(0.3, 0.31, 0.36, 1)
@export var color_ojos: Color = Color(0.4, 1, 0.3, 1)


func _ready() -> void:
	_pintar(self)


func _pintar(nodo: Node) -> void:
	for hijo: Node in nodo.get_children():
		if hijo.get_script() != null:
			continue
		if hijo is MeshInstance3D:
			_tintar(hijo as MeshInstance3D)
		_pintar(hijo)


func _tintar(malla: MeshInstance3D) -> void:
	var base: Material = malla.get_active_material(0)
	if base == null:
		return
	var material: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	if material == null:
		return
	if String(malla.name).contains("Ojo"):
		material.albedo_color = color_ojos
		material.emission_enabled = true
		material.emission = color_ojos
	else:
		material.albedo_color = color_pelo
	malla.material_override = material
