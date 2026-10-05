extends Node3D

# Decoracion 2D y molduras creadas 100% por codigo: texturas pixel-art con
# set_pixel y mallas primitivas generadas en _ready, sin assets externos, sin
# GPUParticles3D y sin audio. El nodo Decorado va en cada escena y es_salon
# decide que se pinta: dormitorio (default) o salon.

@export var es_salon: bool = false

const MADERA: Color = Color(0.25, 0.16, 0.1)
const TAM_CUADRO: Vector2 = Vector2(0.5, 0.4)

var mallas_caja: Dictionary = {}
var material_madera: StandardMaterial3D = null
var cortinas: Array[MeshInstance3D] = []
var tiempo_cortina: float = 0.0


func _ready() -> void:
	if es_salon:
		# El nodo del salon va girado PI: los cuadros miran a -z y el pattern
		# en local +1.78 cae en el mundo (0, 0.03, 4.6), sobre la alfombra.
		_cuadro("CuadroPez", Vector3(-0.8, 1.5, 0.0), _textura_pez())
		_cuadro("CuadroSol", Vector3(-1.6, 1.5, 0.0), _textura_sol())
		_cortina("CortinaIzq", Vector3(1.15, 1.6, 0.05))
		_cortina("CortinaDer", Vector3(-0.15, 1.6, 0.05))
		_pattern_alfombra()
		return
	_cuadro("CuadroPez", Vector3(-1.3, 1.5, 0.0), _textura_pez())
	_cuadro("CuadroSol", Vector3(-0.4, 1.5, 0.0), _textura_sol())
	_cortina("CortinaIzq", Vector3(0.25, 1.6, 0.05))
	_cortina("CortinaDer", Vector3(1.55, 1.6, 0.05))
	_caja("ZocaloA", Vector3(2.0, 0.08, 0.03), Vector3(0.5, 0.04, 0.02))
	_caja("ZocaloB", Vector3(1.5, 0.08, 0.03), Vector3(-0.8, 0.04, 0.02))
	_caja("MarcoIzq", Vector3(0.08, 2.0, 0.06), Vector3(-0.55, 1.0, 0.0))
	_caja("MarcoDer", Vector3(0.08, 2.0, 0.06), Vector3(0.55, 1.0, 0.0))
	_caja("MarcoSup", Vector3(1.18, 0.08, 0.06), Vector3(0.0, 2.04, 0.0))


# Cortina a un lado de la ventana: quad con rayas que se balancea solo.
func _cortina(nombre: String, pos: Vector3) -> void:
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(0.3, 0.9)
	malla.material = _material_textura(_textura_cortina())
	var nodo: MeshInstance3D = _montar(nombre, malla, pos)
	cortinas.append(nodo)


func _process(delta: float) -> void:
	tiempo_cortina += delta
	for cortina: MeshInstance3D in cortinas:
		if is_instance_valid(cortina):
			cortina.rotation.z = sin(tiempo_cortina * 1.3 + cortina.position.x * 2.0) * 0.06


# Quad con textura generada: cada cuadro lleva SU material, nunca compartido.
func _cuadro(nombre: String, pos: Vector3, textura: Texture2D) -> MeshInstance3D:
	var malla: QuadMesh = QuadMesh.new()
	malla.size = TAM_CUADRO
	malla.material = _material_textura(textura)
	return _montar(nombre, malla, pos)


# Alfombra a cuadros del salon, tumbada en el suelo (rotacion -90 grados en X).
func _pattern_alfombra() -> void:
	var malla: QuadMesh = QuadMesh.new()
	malla.size = Vector2(2.0, 1.4)
	malla.material = _material_textura(_textura_alfombra())
	var nodo: MeshInstance3D = _montar("PatternAlfombra", malla, Vector3(0, 0.03, 1.78))
	nodo.rotation.x = -1.5708


# Caja de madera oscura: un BoxMesh por tamano, reutilizado si se repite.
func _caja(nombre: String, tam: Vector3, pos: Vector3) -> MeshInstance3D:
	if not mallas_caja.has(tam):
		var malla: BoxMesh = BoxMesh.new()
		malla.size = tam
		malla.material = _material_madera()
		mallas_caja[tam] = malla
	return _montar(nombre, mallas_caja[tam] as BoxMesh, pos)


func _montar(nombre: String, malla: Mesh, pos: Vector3) -> MeshInstance3D:
	var nodo: MeshInstance3D = MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.position = pos
	add_child(nodo)
	nodo.add_to_group("decorado")
	return nodo


func _material_textura(textura: Texture2D) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = textura
	mat.roughness = 0.9
	return mat


func _material_madera() -> StandardMaterial3D:
	if material_madera == null:
		material_madera = StandardMaterial3D.new()
		material_madera.albedo_color = MADERA
	return material_madera


# ---------------------------------------------------------------------------
# Texturas pixel-art (32x32), una llamada create_from_image por textura
# ---------------------------------------------------------------------------
# Fondo azul oscuro, cuerpo naranja en elipse, cola en triangulo y ojo blanco.
func _textura_pez() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.1, 0.28))
	for x: int in range(2, 9):
		var alto: int = int(round(4.0 * float(8 - x) / 6.0))
		for y: int in range(16 - alto, 17 + alto):
			img.set_pixel(x, y, Color(0.88, 0.42, 0.1))
	for y: int in range(10, 23):
		for x: int in range(6, 27):
			var ex: float = float(x - 16) / 9.0
			var ey: float = float(y - 16) / 6.0
			if ex * ex + ey * ey <= 1.0:
				img.set_pixel(x, y, Color(0.95, 0.5, 0.12))
	for y: int in range(12, 17):
		for x: int in range(19, 24):
			var dx: float = float(x) - 20.5
			var dy: float = float(y) - 14.5
			if dx * dx + dy * dy <= 2.6:
				img.set_pixel(x, y, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


# Degradado vertical naranja a rojo oscuro, con franja de horizonte oscura.
func _textura_sol() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var naranja: Color = Color(1.0, 0.55, 0.1)
	var rojo: Color = Color(0.32, 0.05, 0.05)
	for y: int in 32:
		var mezcla: Color = naranja.lerp(rojo, float(y) / 31.0)
		for x: int in 32:
			img.set_pixel(x, y, mezcla)
	for y: int in range(25, 32):
		for x: int in 32:
			img.set_pixel(x, y, Color(0.13, 0.06, 0.05))
	return ImageTexture.create_from_image(img)


# Damero de dos colores en bloques de 8 pixeles.
func _textura_alfombra() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var claro: Color = Color(0.5, 0.26, 0.3)
	var oscuro: Color = Color(0.27, 0.14, 0.17)
	for y: int in 32:
		for x: int in 32:
			var damero: int = (int(x / 8.0) + int(y / 8.0)) % 2
			img.set_pixel(x, y, claro if damero == 0 else oscuro)
	return ImageTexture.create_from_image(img)


# Rayas verticales granates para las cortinas.
func _textura_cortina() -> ImageTexture:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var claro: Color = Color(0.62, 0.25, 0.28)
	var oscuro: Color = Color(0.35, 0.12, 0.15)
	for y: int in 32:
		for x: int in 32:
			var raya: int = int(x / 4.0) % 2
			img.set_pixel(x, y, claro if raya == 0 else oscuro)
	return ImageTexture.create_from_image(img)
