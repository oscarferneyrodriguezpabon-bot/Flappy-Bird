extends "res://bloques.gd"

const FILAS = 13
const COLS_ADELANTE = 40
const TIEMPO_ESPERA = 1.5
const COL_PRIMER_TUBO = 10
const SEP_MIN = 4
const SEP_MAX = 5
const HUECO_MIN = 2
const HUECO_MAX = 3
const CAMBIO_MAX = 6
const COLS_SUELO = 16
const ALTURA_BASE_TORRE = 114.0
const ALTURA_BASE_SENSOR = 100.0

# tubos del inicio (siempre iguales)
const INICIO_FIJO = [4, 3, 5, 4, 6]
const HUECO_FIJO = [3, 3, 3, 3, 3]
const SEP_FIJA = 5

var moneda_escena = preload("res://moneda.tscn")
var pluma_escena = preload("res://pluma.tscn")
var tubo_escena = preload("res://tubo.tscn")
var ojo_escena = preload("res://ojo.tscn")
var suelo_escena = preload("res://suelo.tscn")
var sensor_escena = preload("res://sensor.tscn")

var puntaje = 0
var siguiente_col = 0
var ultimo_inicio = 4
var siguiente_suelo = 0
var puede_generar = false
var tubos_creados = 0
var pos_inicial = Vector2.ZERO

var ojo = null
var objetos = []   # tubos, sensores, items y suelos todos juntos

@onready var pajaro = $Pajaro
@onready var timer = $Timer


func _ready():
	randomize()
	pos_inicial = pajaro.position   # guardo donde empieza el pajaro

	# conecto el timer por codigo (solo si no esta conectado ya desde el editor)
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	pajaro.murio.connect(reiniciar)
	reiniciar()


func _process(delta):
	if not is_instance_valid(pajaro):
		return

	$Camera2D.position = Vector2(pajaro.position.x, 410)
	generar_todo()
	limpiar()
	crear_ojo()


func reiniciar():
	if ojo != null:
		ojo.queue_free()
		ojo = null

	for o in objetos:
		if is_instance_valid(o):
			o.queue_free()
	objetos.clear()

	puntaje = 0
	$HUD/Puntaje.text = "Puntaje: 0"
	ultimo_inicio = 4
	tubos_creados = 0   # vuelve a empezar con los tubos fijos

	# devuelvo el pajaro al inicio antes de calcular nada
	pajaro.position = pos_inicial
	pajaro.velocity = Vector2.ZERO

	var pos_x = pos_inicial.x
	siguiente_suelo = int(pos_x / (COLS_SUELO * CELDA)) - 2
	siguiente_col = int(pos_x / CELDA) + COL_PRIMER_TUBO

	# bloqueo los tubos y arranco el timer de 1.5 segundos
	# (si ya estaba corriendo, start() lo reinicia, asi que no se cruzan)
	puede_generar = false
	timer.wait_time = TIEMPO_ESPERA
	timer.one_shot = true
	timer.start()

	generar_todo()


# se llama cuando el timer termina
func _on_timer_timeout():
	puede_generar = true
	# los tubos salen a COL_PRIMER_TUBO columnas de donde esta el pajaro ahora
	siguiente_col = int(pajaro.position.x / CELDA) + COL_PRIMER_TUBO


func crear_ojo():
	if ojo != null:
		return

	ojo = ojo_escena.instantiate()
	ojo.pajaro = pajaro
	ojo.global_position = Vector2(pajaro.global_position.x - 450, 410)
	$Mapa.add_child(ojo)


func generar_todo():
	var ancho_suelo = COLS_SUELO * CELDA
	while siguiente_suelo * ancho_suelo < pajaro.position.x + COLS_ADELANTE * CELDA:
		var suelo = suelo_escena.instantiate()
		suelo.position.x = siguiente_suelo * ancho_suelo
		$Mapa.add_child(suelo)
		objetos.append(suelo)
		siguiente_suelo += 1

	# si el timer no ha terminado no creo tubos
	if puede_generar == false:
		return

	var col_limite = int(pajaro.position.x / CELDA) + COLS_ADELANTE
	while siguiente_col < col_limite:
		# separacion: fija al inicio, aleatoria despues
		var separacion = SEP_FIJA
		if tubos_creados >= INICIO_FIJO.size():
			separacion = randi_range(SEP_MIN, SEP_MAX)

		crear_obstaculo(siguiente_col)
		siguiente_col += separacion


func limpiar():
	var limite_x = pajaro.position.x - 1500

	# recorro al reves para poder borrar sin dañar la lista
	for i in range(objetos.size() - 1, -1, -1):
		var o = objetos[i]
		if not is_instance_valid(o):
			objetos.remove_at(i)
		elif o.position.x < limite_x - COLS_SUELO * CELDA:
			o.queue_free()
			objetos.remove_at(i)


func crear_tubo(cx, y, alto, invertido):
	var tubo = tubo_escena.instantiate()
	tubo.position = Vector2(cx, y + alto / 2.0)
	var escala = alto / ALTURA_BASE_TORRE
	tubo.get_node("Sprite2D").flip_v = invertido
	tubo.get_node("Sprite2D").scale.y *= escala
	tubo.get_node("CollisionShape2D").scale.y *= escala
	tubo.add_to_group("enemigos")
	tubo.body_entered.connect(_on_enemigo_tocado)
	$Mapa.add_child(tubo)
	objetos.append(tubo)


func crear_obstaculo(col):
	var hueco
	var inicio
	var es_fijo = tubos_creados < INICIO_FIJO.size()

	if es_fijo:
		# tubos del principio: siempre los mismos
		hueco = HUECO_FIJO[tubos_creados]
		inicio = INICIO_FIJO[tubos_creados]
	else:
		# tubos aleatorios
		hueco = randi_range(HUECO_MIN, HUECO_MAX)
		var min_h = max(2, ultimo_inicio - CAMBIO_MAX)
		var max_h = min(FILAS - 2 - hueco, ultimo_inicio + CAMBIO_MAX)
		if min_h > max_h:
			min_h = max_h
		inicio = randi_range(min_h, max_h)

	ultimo_inicio = inicio
	var cx = (col + 0.5) * CELDA

	# tubo de arriba y tubo de abajo
	var alto_arriba = inicio * CELDA
	if alto_arriba > 0:
		crear_tubo(cx, 0, alto_arriba, true)

	var y_abajo = (inicio + hueco) * CELDA
	var alto_abajo = FILAS * CELDA - y_abajo
	if alto_abajo > 0:
		crear_tubo(cx, y_abajo, alto_abajo, false)

	# sensor de puntos en medio del hueco
	var sensor = sensor_escena.instantiate()
	sensor.position = Vector2(cx, (inicio + hueco / 2.0) * CELDA)
	sensor.get_node("CollisionShape2D").scale.y = hueco * CELDA / ALTURA_BASE_SENSOR
	sensor.body_entered.connect(_on_sensor_tocado.bind(sensor))
	$Mapa.add_child(sensor)
	objetos.append(sensor)

	# items
	var fila_item = inicio + int(hueco / 2)
	if es_fijo:
		# en los tubos fijos pongo una moneda cada dos tubos
		if tubos_creados % 2 == 1:
			poner_item(moneda_escena, col, fila_item)
	else:
		var azar = randf()
		if azar < 0.3:
			poner_item(moneda_escena, col, fila_item)
		elif azar < 0.45:
			poner_item(pluma_escena, col, fila_item)

	tubos_creados += 1


func poner_item(escena, col, fila):
	var item = escena.instantiate()
	item.position = Vector2(col + 0.5, fila + 0.5) * CELDA
	item.body_entered.connect(_on_item_tocado.bind(item))
	$Mapa.add_child(item)
	objetos.append(item)


func _on_sensor_tocado(cuerpo, sensor):
	if cuerpo == pajaro:
		puntaje += 1
		$HUD/Puntaje.text = "Puntaje: " + str(puntaje)
		sensor.queue_free()


func _on_item_tocado(cuerpo, item):
	if cuerpo == pajaro:
		item.queue_free()


func _on_enemigo_tocado(cuerpo):
	if cuerpo == pajaro:
		pajaro.morir()
