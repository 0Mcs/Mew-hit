extends Node

# Menu de desarrollador para la iluminacion: en juego (sin pausa) F1 cicla
# el preset de ambiente, F2 cicla el modo de oclusion (SSAO / SSIL / todo /
# nada), F3 el filtro PSX y F4 la niebla. Asi se compara en vivo y se elige
# el ambiente ideal. Cada cambio avisa por el HUD.

const MODOS_AO: Array[String] = ["SSAO", "SSIL", "Todo", "Nada"]
const MODOS_FILTRO: Array[String] = ["Nada", "Suave", "Fuerte", "Noir"]

const NIEBLAS: Array = [
	{"nombre": "Suave", "inicio": 10.0, "fin": 50.0},
	{"nombre": "Densa", "inicio": 4.0, "fin": 25.0},
	{"nombre": "Nada", "inicio": 0.0, "fin": 0.0},
]

const PRESETS: Array = [
	{
		"nombre": "Neutro",
		"cenit": Color(0.30, 0.42, 0.68, 1),
		"horizonte": Color(0.82, 0.78, 0.70, 1),
		"niebla": Color(0.70, 0.70, 0.72, 1),
		"sol": Color(1.0, 0.96, 0.88, 1),
		"sol_energia": 1.1,
		"ambiente": 0.55,
	},
	{
		"nombre": "Luna",
		"cenit": Color(0.05, 0.08, 0.20, 1),
		"horizonte": Color(0.35, 0.42, 0.60, 1),
		"niebla": Color(0.52, 0.56, 0.64, 1),
		"sol": Color(0.75, 0.85, 1.0, 1),
		"sol_energia": 0.9,
		"ambiente": 0.45,
	},
	{
		"nombre": "Atardecer",
		"cenit": Color(0.10, 0.13, 0.30, 1),
		"horizonte": Color(0.80, 0.52, 0.42, 1),
		"niebla": Color(0.62, 0.65, 0.72, 1),
		"sol": Color(1.0, 0.85, 0.70, 1),
		"sol_energia": 1.0,
		"ambiente": 0.50,
	},
	{
		"nombre": "Oscuro",
		"cenit": Color(0.02, 0.03, 0.08, 1),
		"horizonte": Color(0.10, 0.12, 0.20, 1),
		"niebla": Color(0.15, 0.16, 0.20, 1),
		"sol": Color(0.50, 0.60, 0.80, 1),
		"sol_energia": 0.5,
		"ambiente": 0.25,
	},
	{
		"nombre": "Amanecer",
		"cenit": Color(0.35, 0.30, 0.55, 1),
		"horizonte": Color(0.95, 0.65, 0.55, 1),
		"niebla": Color(0.75, 0.68, 0.70, 1),
		"sol": Color(1.0, 0.85, 0.75, 1),
		"sol_energia": 1.0,
		"ambiente": 0.50,
	},
	{
		"nombre": "Mediodía",
		"cenit": Color(0.25, 0.45, 0.85, 1),
		"horizonte": Color(0.75, 0.82, 0.90, 1),
		"niebla": Color(0.72, 0.74, 0.78, 1),
		"sol": Color(1.0, 0.98, 0.95, 1),
		"sol_energia": 1.2,
		"ambiente": 0.60,
	},
]

var preset_actual: int = 0
var modo_ao: int = 2
var filtro_actual: int = 0
var niebla_actual: int = 0
var entorno: WorldEnvironment = null
var sol: DirectionalLight3D = null
var hud_nodo: Node = null


func _ready() -> void:
	entorno = get_parent().get_node_or_null("Entorno") as WorldEnvironment
	sol = get_parent().get_node_or_null("Luz") as DirectionalLight3D
	hud_nodo = get_parent().get_node_or_null("HUD/Reticula")
	aplicar_preset(0)
	aplicar_modo_ao()
	aplicar_filtro()
	aplicar_niebla()


func _unhandled_key_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey):
		return
	var tecla: InputEventKey = evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	match tecla.keycode:
		KEY_F1:
			siguiente_preset()
		KEY_F2:
			siguiente_modo_ao()
		KEY_F3:
			siguiente_filtro()
		KEY_F4:
			siguiente_niebla()


func siguiente_preset() -> void:
	aplicar_preset((preset_actual + 1) % PRESETS.size())


func aplicar_preset(i: int) -> void:
	if PRESETS.is_empty():
		return
	preset_actual = clampi(i, 0, PRESETS.size() - 1)
	var preset: Dictionary = PRESETS[preset_actual]
	var env: Environment = _env()
	if env != null:
		if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
			var cielo: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
			cielo.sky_top_color = preset.get("cenit", cielo.sky_top_color)
			cielo.sky_horizon_color = preset.get("horizonte", cielo.sky_horizon_color)
		env.fog_light_color = preset.get("niebla", env.fog_light_color)
		env.ambient_light_energy = float(preset.get("ambiente", env.ambient_light_energy))
	if sol != null:
		sol.light_color = preset.get("sol", sol.light_color)
		sol.light_energy = float(preset.get("sol_energia", sol.light_energy))
	_avisar("iluminación: " + str(preset.get("nombre", "?")).to_lower())


func siguiente_modo_ao() -> void:
	modo_ao = (modo_ao + 1) % MODOS_AO.size()
	aplicar_modo_ao()


func aplicar_modo_ao() -> void:
	var env: Environment = _env()
	if env == null:
		return
	var modo: String = MODOS_AO[modo_ao]
	env.ssao_enabled = modo == "SSAO" or modo == "Todo"
	env.ssil_enabled = modo == "SSIL" or modo == "Todo"
	_avisar("oclusión: " + modo.to_lower())


func siguiente_filtro() -> void:
	filtro_actual = (filtro_actual + 1) % MODOS_FILTRO.size()
	aplicar_filtro()


func aplicar_filtro() -> void:
	if hud_nodo == null:
		return
	var filtro: CanvasItem = (hud_nodo as Node).get_node_or_null("../FiltroPSX") as CanvasItem
	if filtro == null:
		return
	var modo: String = MODOS_FILTRO[filtro_actual]
	filtro.visible = modo != "Nada"
	var mat: ShaderMaterial = filtro.material as ShaderMaterial
	if mat != null:
		if modo == "Fuerte":
			mat.set_shader_parameter("posterize_niveles", 6.0)
			mat.set_shader_parameter("dither_fuerza", 0.08)
			mat.set_shader_parameter("scanline_fuerza", 0.06)
			mat.set_shader_parameter("grano_fuerza", 0.04)
			mat.set_shader_parameter("vineta_fuerza", 0.35)
			mat.set_shader_parameter("blanco_negro", 0.0)
		elif modo == "Noir":
			mat.set_shader_parameter("posterize_niveles", 12.0)
			mat.set_shader_parameter("dither_fuerza", 0.05)
			mat.set_shader_parameter("scanline_fuerza", 0.035)
			mat.set_shader_parameter("grano_fuerza", 0.02)
			mat.set_shader_parameter("vineta_fuerza", 0.3)
			mat.set_shader_parameter("blanco_negro", 1.0)
		else:
			mat.set_shader_parameter("posterize_niveles", 12.0)
			mat.set_shader_parameter("dither_fuerza", 0.05)
			mat.set_shader_parameter("scanline_fuerza", 0.035)
			mat.set_shader_parameter("grano_fuerza", 0.02)
			mat.set_shader_parameter("vineta_fuerza", 0.3)
			mat.set_shader_parameter("blanco_negro", 0.0)
	_avisar("filtro: " + modo.to_lower())


func siguiente_niebla() -> void:
	niebla_actual = (niebla_actual + 1) % NIEBLAS.size()
	aplicar_niebla()


func aplicar_niebla() -> void:
	var env: Environment = _env()
	if env == null:
		return
	var nivel: Dictionary = NIEBLAS[niebla_actual]
	var nombre: String = str(nivel.get("nombre", "Suave"))
	env.fog_enabled = nombre != "Nada"
	if nombre != "Nada":
		env.fog_depth_begin = float(nivel.get("inicio", env.fog_depth_begin))
		env.fog_depth_end = float(nivel.get("fin", env.fog_depth_end))
	_avisar("niebla: " + nombre.to_lower())


func _env() -> Environment:
	if entorno == null:
		return null
	return entorno.environment


func _avisar(texto: String) -> void:
	if hud_nodo != null and hud_nodo.has_method("mostrar_aviso"):
		hud_nodo.call("mostrar_aviso", texto)
