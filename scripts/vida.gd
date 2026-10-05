extends Node
class_name Vida

# Componente de vida. En Godot 4 un nodo solo admite UN script, asi que la vida
# vive en un nodo hijo ("Vida") y quien dispara reenvia el dano a quien tenga
# el metodo recibir_dano(). Asi player.gd no tiene que ceder su script.

signal vida_cambiada(actual: int, maxima: int)
signal muerto

@export var vida_maxima: int = 100

var vida: int = 100


func _ready() -> void:
	vida = vida_maxima
	vida_cambiada.emit(vida, vida_maxima)


func recibir_dano(cantidad: int) -> void:
	if cantidad <= 0 or vida <= 0:
		return
	vida = maxi(vida - cantidad, 0)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		muerto.emit()


func curar(cantidad: int) -> void:
	if cantidad <= 0:
		return
	vida = mini(vida + cantidad, vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)


func reiniciar() -> void:
	vida = vida_maxima
	vida_cambiada.emit(vida, vida_maxima)


func proporcion() -> float:
	if vida_maxima <= 0:
		return 0.0
	return float(vida) / float(vida_maxima)


func sigue_vivo() -> bool:
	return vida > 0
