 
extends CharacterBody2D

@export var velocidad: float = 150.0
@export var distancia_detras: float = 180.0
@export var seguimiento_vertical: float = 3.0
@export var amplitud: float = 18.0
@export var frecuencia: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Cambia esta ruta si tu pájaro está en otra ubicación.
@onready var pajaro: Node2D = get_node_or_null("../Pajaro")

var tiempo: float = 0.0
var altura_base: float = 0.0


func _ready() -> void:
	sprite.play("volar")
	altura_base = global_position.y


func _physics_process(delta: float) -> void:
	tiempo += delta

	if not is_instance_valid(pajaro):
		return

	# El ojo busca una posición detrás del pájaro.
	var direccion = -1.0

	# Si el pájaro avanza hacia la derecha,
	# el ojo se mantiene a su izquierda.
	var posicion_objetivo = pajaro.global_position
	posicion_objetivo.x -= distancia_detras

	# Movimiento suave para seguir la altura del pájaro.
	posicion_objetivo.y += sin(tiempo * frecuencia) * amplitud

	global_position = global_position.lerp(
		posicion_objetivo,
		clampf(seguimiento_vertical * delta, 0.0, 1.0)
	)

	# Orienta el ojo hacia el pájaro.
	var diferencia = pajaro.global_position - global_position
	if diferencia.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# Mantiene activa la animación de vuelo.
	if sprite.animation != "volar":
		sprite.play("volar")
