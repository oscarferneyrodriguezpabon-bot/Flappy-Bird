
extends CharacterBody2D

@export var distancia_atras: float = 220.0
@export var velocidad_persecucion: float = 180.0
@export var velocidad_embestida: float = 650.0
@export var altura_fija: float = 410.0

var pajaro: Node2D = null
var embistiendo: bool = false
var escala_original: Vector2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Guardar el tamaño original y no modificarlo nunca.
	escala_original = anim.scale

	if anim.sprite_frames:
		if anim.sprite_frames.has_animation("seguir"):
			anim.play("seguir")
		elif anim.sprite_frames.has_animation("volar"):
			anim.play("volar")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(pajaro):
		return

	# El ojo permanece siempre a la misma altura.
	global_position.y = altura_fija

	# Detectar la muerte sin hacer crecer el ojo.
	if bool(pajaro.get("muriendo")):
		embistiendo = true

	var destino_x: float

	if embistiendo:
		# Avanza hasta la posición horizontal del pájaro.
		destino_x = pajaro.global_position.x
		global_position.x = move_toward(
			global_position.x,
			destino_x,
			velocidad_embestida * delta
		)

		# Cuando el pájaro se reinicie, volver detrás de él.
		if not bool(pajaro.get("muriendo")):
			embistiendo = false
	else:
		# Perseguir al pájaro manteniendo distancia horizontal.
		destino_x = pajaro.global_position.x - distancia_atras
		global_position.x = move_toward(
			global_position.x,
			destino_x,
			velocidad_persecucion * delta
		)

	# Garantizar que el tamaño no cambie.
	anim.scale = escala_original
