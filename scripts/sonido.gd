extends Node

# Todo el sonido del juego se genera aqui con AudioStreamWAV: ni un archivo de
# audio en el proyecto. Cada sonido tiene su propio AudioStreamPlayer, asi dos
# llamadas seguidas (pasos, impactos) no se pisan.
#
# Los scripts del jugador y de la pistola no saben si este nodo existe: buscan
# "sonido" en el arbol y llaman a estos metodos con has_method().

const MUESTREO: int = 44100
const VOLUMEN_AMBIENTE: float = -16.0
const VOLUMEN_PASO: float = -14.0
const VOLUMEN_IMPACTO: float = -8.0

var aleatorio: RandomNumberGenerator = RandomNumberGenerator.new()
var pistolas: Dictionary = {}
var flujos: Dictionary = {}


func _ready() -> void:
	aleatorio.seed = 20261004
	add_to_group("sonido")
	_crearpistas()
	_generar_flujos()


# Al salir del arbol, todo el mundo deja de sonar. En headless el driver de
# audio nunca da por terminado un sonido, y Godot reporta un ObjectDB leak
# por cada pista que sigue sonando cuando se destruye el arbol.
func _exit_tree() -> void:
	for hijo: Node in get_children():
		if hijo is AudioStreamPlayer:
			(hijo as AudioStreamPlayer).stop()
		elif hijo is AudioStreamPlayer3D:
			(hijo as AudioStreamPlayer3D).stop()


func _crearpistas() -> void:
	_nueva_pista("disparo", -6.0)
	_nueva_pista("paso", VOLUMEN_PASO)
	_nueva_pista("dash", -9.0)
	_nueva_pista("trepar", -12.0)
	_nueva_pista("maullido", -6.0)
	_nueva_pista("maullido_dano", -4.0)
	_nueva_pista("enemigo_detecta", -9.0)
	_nueva_pista("enemigo_aviso", -7.0)
	_nueva_pista("enemigo_golpe", -5.0)
	_nueva_pista("marcador", -10.0)
	_nueva_pista("ambiente", VOLUMEN_AMBIENTE)


func _nueva_pista(nombre: String, volumen: float) -> AudioStreamPlayer:
	var pista: AudioStreamPlayer = AudioStreamPlayer.new()
	pista.name = nombre
	pista.volume_db = volumen
	add_child(pista)
	pistolas[nombre] = pista
	return pista


# ---------------------------------------------------------------------------
# API que llaman el jugador y la pistola
# ---------------------------------------------------------------------------
func reproducir_disparo() -> void:
	_tocar("disparo", randf_range(0.95, 1.06))


func reproducir_paso() -> void:
	_tocar("paso", randf_range(0.85, 1.2))


func reproducir_dash() -> void:
	_tocar("dash", randf_range(0.9, 1.1))


func reproducir_trepar() -> void:
	_tocar("trepar", randf_range(0.9, 1.15))


func reproducir_maullido() -> void:
	_tocar("maullido", randf_range(0.95, 1.08))


func reproducir_maullido_dano() -> void:
	_tocar("maullido_dano", randf_range(1.0, 1.15))


func reproducir_ambiente() -> void:
	_tocar("ambiente", 1.0)


func reproducir_enemigo_detecta() -> void:
	_tocar("enemigo_detecta", randf_range(0.95, 1.12))


func reproducir_enemigo_aviso() -> void:
	_tocar("enemigo_aviso", randf_range(0.9, 1.06))


func reproducir_enemigo_golpe() -> void:
	_tocar("enemigo_golpe", randf_range(0.88, 1.16))


func reproducir_marcador() -> void:
	_tocar("marcador", randf_range(0.95, 1.1))


# El impacto suena donde cae: se crea un reproductor 3D en el punto y se
# borra solo al terminar.
func reproducir_impacto(punto: Vector3) -> void:
	var flujo: AudioStreamWAV = flujos.get("impacto") as AudioStreamWAV
	if flujo == null:
		return
	var pista: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	pista.stream = flujo
	pista.volume_db = VOLUMEN_IMPACTO
	pista.pitch_scale = randf_range(0.85, 1.25)
	pista.unit_size = 10.0
	add_child(pista)
	pista.global_position = punto
	pista.finished.connect(pista.queue_free)

	# Segunda red de seguridad: si el audio no llega a avisar de que ha
	# terminado (salida anulada, modo headless, driver sin dispositivo), la
	# pista se borra igual pasada su duracion. Sin esto el reproductor se
	# acumula uno por impacto y Godot avisa al salir con un ObjectDB leak.
	var arbol: SceneTree = get_tree()
	if arbol != null:
		var segundos: float = float(flujo.data.size() / 2) / float(maxf(flujo.mix_rate, 1.0))
		var espera: float = maxf(segundos, 0.05) + 0.4
		arbol.create_timer(espera).timeout.connect(pista.queue_free)

	pista.play()


func _tocar(nombre: String, tono: float) -> void:
	var pista: AudioStreamPlayer = pistolas.get(nombre) as AudioStreamPlayer
	if pista == null or pista.stream == null:
		return
	pista.pitch_scale = tono
	pista.play()


# ---------------------------------------------------------------------------
# Generacion de flujos
# ---------------------------------------------------------------------------
func _generar_flujos() -> void:
	flujos["disparo"] = _wav_disparo()
	flujos["paso"] = _wav_paso()
	flujos["impacto"] = _wav_impacto()
	flujos["dash"] = _wav_dash()
	flujos["trepar"] = _wav_trepar()
	flujos["maullido"] = _wav_maullido(0.55, 1.0)
	flujos["maullido_dano"] = _wav_maullido(0.32, 1.35)
	flujos["enemigo_detecta"] = _wav_enemigo_detecta()
	flujos["enemigo_aviso"] = _wav_enemigo_aviso()
	flujos["enemigo_golpe"] = _wav_enemigo_golpe()
	flujos["marcador"] = _wav_marcador()
	flujos["ambiente"] = _wav_viento()

	for nombre: String in flujos.keys():
		if pistolas.has(nombre):
			(pistolas[nombre] as AudioStreamPlayer).stream = flujos[nombre]

	# El viento arranca solo: es el fondo del nivel, en bucle.
	_tocar("ambiente", 1.0)


func _wav_disparo() -> AudioStreamWAV:
	var duracion: float = 0.18
	var m: PackedFloat32Array = _muestras(duracion)
	var fase: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var f: float = 130.0 + 950.0 * exp(-t * 32.0)
		fase += TAU * f / MUESTREO
		var ruido: float = _ruido() * exp(-t * 48.0)
		var tono: float = sin(fase) * exp(-t * 24.0)
		m[i] = clampf(ruido * 0.85 + tono * 0.5, -1.0, 1.0)
	return _wav(m)


func _wav_paso() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(0.06)
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		suave += 0.3 * (_ruido() - suave)
		m[i] = clampf(suave * exp(-t * 55.0) * 0.8, -1.0, 1.0)
	return _wav(m)


func _wav_impacto() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(0.1)
	var fase: float = 0.0
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var f: float = 90.0 + 260.0 * exp(-t * 42.0)
		fase += TAU * f / MUESTREO
		suave += 0.5 * (_ruido() - suave)
		m[i] = clampf(sin(fase) * exp(-t * 32.0) * 0.6 + suave * exp(-t * 70.0) * 0.6, -1.0, 1.0)
	return _wav(m)


func _wav_dash() -> AudioStreamWAV:
	var duracion: float = 0.32
	var m: PackedFloat32Array = _muestras(duracion)
	var fase: float = 0.0
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var u: float = t / duracion
		var env: float = sin(PI * u)
		suave += 0.35 * (_ruido() - suave)
		var f: float = 260.0 + 720.0 * u
		fase += TAU * f / MUESTREO
		m[i] = clampf(suave * env * 0.8 + sin(fase) * env * 0.2, -1.0, 1.0)
	return _wav(m)


func _wav_trepar() -> AudioStreamWAV:
	var duracion: float = 0.26
	var m: PackedFloat32Array = _muestras(duracion)
	var anterior: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var bruto: float = _ruido()
		var agudo: float = bruto - anterior
		anterior = bruto
		var rascado: float = 0.55 + 0.45 * sin(TAU * 9.0 * t)
		m[i] = clampf(agudo * rascado * exp(-t * 7.0) * 0.4, -1.0, 1.0)
	return _wav(m)


# El maullido: la curva sube, se sostiene y cae mas grave, con vibrato y
# armónicos para que no suene a silbido.
func _wav_maullido(duracion: float, escala: float) -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(duracion)
	var fase: float = 0.0
	var armonicos: Array[int] = [1, 2, 3, 4, 6]
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var u: float = t / duracion
		var curva: float
		if u < 0.22:
			curva = u / 0.22
		elif u < 0.55:
			curva = 1.0
		else:
			curva = 1.0 - ((u - 0.55) / 0.45) * 0.8
		var f: float = 400.0 * escala * (0.8 + 0.6 * curva)
		f *= 1.0 + 0.04 * sin(TAU * 11.0 * t)
		fase += TAU * f / MUESTREO

		var voz: float = 0.0
		for h: int in armonicos:
			voz += sin(fase * float(h)) / float(h)
		voz *= 0.32

		var ataque: float = clampf(t / 0.05, 0.0, 1.0)
		var cola: float = 1.0
		if u > 0.6:
			cola = clampf(1.0 - (u - 0.6) / 0.4, 0.0, 1.0)
		m[i] = clampf((voz + _ruido() * 0.1) * ataque * cola, -1.0, 1.0)
	return _wav(m)


# Aviso del enemigo al detectar al jugador: dos pitidos secos, el segundo
# mas agudo. Se oye por encima del viento.
func _wav_enemigo_detecta() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(0.2)
	var fase: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var env: float = 0.0
		var f: float = 680.0
		if t < 0.06:
			env = 1.0 - t / 0.06
		elif t > 0.1 and t < 0.18:
			env = 1.0 - (t - 0.1) / 0.08
			f = 940.0
		fase += TAU * f / MUESTREO
		m[i] = clampf((sin(fase) * 0.55 + _ruido() * 0.2) * env, -1.0, 1.0)
	return _wav(m)


# Grito de aviso antes de pegar: sube de tono y termina ronco, para que el
# jugador tenga medio segundo para esquivarlo.
func _wav_enemigo_aviso() -> AudioStreamWAV:
	var duracion: float = 0.32
	var m: PackedFloat32Array = _muestras(duracion)
	var fase: float = 0.0
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var u: float = t / duracion
		var f: float = 110.0 + 360.0 * u
		fase += TAU * f / MUESTREO
		suave += 0.45 * (_ruido() - suave)
		var ataque: float = clampf(t / 0.05, 0.0, 1.0)
		var cola: float = clampf((duracion - t) / 0.12, 0.0, 1.0)
		var voz: float = sin(fase) * 0.45 + sin(fase * 2.0) * 0.2
		m[i] = clampf((voz + suave * 0.5) * ataque * cola, -1.0, 1.0)
	return _wav(m)


# Golpe cuerpo a cuerpo: golpe grave seco con cola de ruido.
func _wav_enemigo_golpe() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(0.16)
	var fase: float = 0.0
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var f: float = 75.0 + 190.0 * exp(-t * 30.0)
		fase += TAU * f / MUESTREO
		suave += 0.5 * (_ruido() - suave)
		m[i] = clampf(
			sin(fase) * exp(-t * 22.0) * 0.8 + suave * exp(-t * 55.0) * 0.5,
			-1.0, 1.0
		)
	return _wav(m)


# Tick del marcador de impacto: chasquido agudo y muy corto, se oye por
# encima del disparo sin cansar.
func _wav_marcador() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(0.08)
	var fase: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var f: float = 1600.0 + 600.0 * exp(-t * 60.0)
		fase += TAU * f / MUESTREO
		var env: float = exp(-t * 42.0)
		m[i] = clampf(
			sin(fase) * env * 0.7 + _ruido() * exp(-t * 160.0) * 0.35,
			-1.0, 1.0
		)
	return _wav(m)


# Viento en bucle: ruido muy filtrado con una modulacion lenta. El cruce del
# final con el principio evita el chasquido en el punto de bucle.
func _wav_viento() -> AudioStreamWAV:
	var m: PackedFloat32Array = _muestras(2.0)
	var grave: float = 0.0
	var suave: float = 0.0
	for i: int in m.size():
		var t: float = float(i) / MUESTREO
		var bruto: float = _ruido()
		grave += 0.02 * (bruto - grave)
		suave += 0.06 * (grave - suave)
		var lfo: float = 0.6 + 0.4 * sin(TAU * t)
		m[i] = clampf(suave * 9.0 * lfo, -1.0, 1.0)
	var cruce: int = int(0.15 * MUESTREO)
	var fin: int = _cruzar_bucle(m, cruce)
	var wav: AudioStreamWAV = _wav(m)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = fin
	return wav


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
func _ruido() -> float:
	return aleatorio.randf_range(-1.0, 1.0)


func _muestras(duracion: float) -> PackedFloat32Array:
	var m: PackedFloat32Array = PackedFloat32Array()
	m.resize(maxi(int(duracion * MUESTREO), 1))
	return m


func _wav(m: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(m.size() * 2)
	for i: int in m.size():
		bytes.encode_s16(i * 2, int(clampf(m[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUESTREO
	wav.stereo = false
	wav.data = bytes
	return wav


# Devuelve hasta donde llega el bucle para que no se salte muestras.
func _cruzar_bucle(m: PackedFloat32Array, cruce: int) -> int:
	var n: int = m.size()
	if cruce <= 0 or cruce * 2 >= n:
		return n
	for i: int in cruce:
		var peso: float = float(i) / float(cruce)
		m[i] = m[i] * peso + m[n - cruce + i] * (1.0 - peso)
	return n - cruce
