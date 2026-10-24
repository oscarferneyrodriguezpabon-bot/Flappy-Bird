extends CharacterBody2D

signal murio

@export var gravedad = 980.0   # px/s²
@export var impulso = 350.0    # px/s hacia arriba en cada aleteo
@export var avance = 120.0     # px/s hacia la derecha

var inicio = Vector2.ZERO
var muriendo = false

@onready var sprite = $AnimatedSprite2D
@onready var sonido_aleteo = $Aleteo
@onready var sonido_golpe = $Golpe


func _ready():
	inicio = position


func _physics_process(delta):
	if muriendo:
		return
	mover(delta)
	if Input.is_action_just_pressed("aletear"):
		sonido_aleteo.play()
	if is_on_floor():
		morir()
		return
	actualizar_animacion()
	inclinar()


func mover(delta):
	velocity.y += gravedad * delta
	if Input.is_action_just_pressed("aletear"):
		velocity.y = -impulso
	velocity.x = avance
	move_and_slide()


func actualizar_animacion():
	var vy = get_real_velocity().y
	if vy < -1.0:
		sprite.play("aletear")
		sprite.speed_scale = 1.0 + (-vy) / impulso
	else:
		sprite.play("planear")
		sprite.speed_scale = 1.0


func inclinar():
	var grados = clampf(get_real_velocity().y * 0.15, -25.0, 90.0)
	sprite.rotation = deg_to_rad(grados)


func morir():
	if muriendo:
		return
	muriendo = true
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0
	sprite.rotation = 0.0
	sprite.play("morir")
	sonido_golpe.play()
	await sprite.animation_finished
	murio.emit()
	position = inicio
	velocity = Vector2.ZERO
	sprite.play("planear")
	muriendo = false
	
