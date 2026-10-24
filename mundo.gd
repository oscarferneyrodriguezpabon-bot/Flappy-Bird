extends "res://bloques.gd"

# ---------------------------------------------------------------
# CONSTANTES DE CONFIGURACIÓN DEL MAPA Y DIFICULTAD
# ---------------------------------------------------------------
const FILAS = 13                 # Alto del mapa en cuadrícula
const COLS_ADELANTE = 40         # Columnas generadas por delante del pájaro
const COLS_PRIMER_TUBO = 5       # Distancia inicial del primer tubo

# Dificultad y variedad de obstáculos
const SEP_MIN = 4                # Separación mínima entre torres
const SEP_MAX = 5                # Separación máxima entre torres
const HUECO_MIN = 2             # Hueco mínimo para pasar
const HUECO_MAX = 3              # Hueco máximo
const CAMBIO_MAX = 6             # Permite cambios de altura bruscos

# Configuración del suelo/techo
const COLS_SUELO = 16            # Ancho de cada bloque de piso/techo
const COLOR_BLOQUES = Color(0.384, 0.035, 0.09, 0.0)
const COLOR_BORDE = Color(0.118, 0.004, 0.031, 0.0)

# Altura original de la imagen de la torre en píxeles (64x114)
const ALTURA_BASE_TORRE = 114.0

# ---------------------------------------------------------------
# RECURSOS PRECARGADOS
# ---------------------------------------------------------------
var moneda_escena = preload("res://moneda.tscn")
var pluma_escena = preload("res://pluma.tscn")
var tubo_escena = preload("res://tubo.tscn")
var ojo_escena = preload("res://ojo.tscn")

# ---------------------------------------------------------------
# VARIABLES DE ESTADO
# ---------------------------------------------------------------
var puntaje = 0
var siguiente_col = 0            # Próxima columna donde irá una torre
var ultimo_inicio = 4            # Fila donde empezó el último hueco
var siguiente_suelo = 0          # Índice del próximo bloque de piso/techo

var inst_ojo: Node2D = null      # Referencia al jefe colosal
var obstaculos = []              # Nodos de torres, monedas y sensores
var suelos = []                  # Nodos de piso/techo

@onready var pajaro = $Pajaro


func _ready():
	randomize()
	if is_instance_valid(pajaro) and pajaro.has_signal("murio"):
		pajaro.murio.connect(reiniciar)
	reiniciar()


func _process(_delta):
	if is_instance_valid(pajaro):
		# 1. Cámara fija en Y = 410.0 y siguiendo la X del pájaro
		if has_node("Camera2D"):
			$Camera2D.position = Vector2(pajaro.position.x, 410.0)
			
		# 2. Generación procedural de mapa
		generar_todo()
		limpiar()

	# El ojo se sigue actualizando / generando de forma independiente
	actualizar_ojo_gigante()


# ---------------------------------------------------------------
# CONTROL Y REINICIO DEL JUEGO
# ---------------------------------------------------------------
func reiniciar():
	if is_instance_valid(inst_ojo):
		inst_ojo.queue_free()
	inst_ojo = null

	for n in obstaculos:
		if is_instance_valid(n):
			n.queue_free()
	for s in suelos:
		if is_instance_valid(s):
			s.queue_free()
			
	obstaculos.clear()
	suelos.clear()

	puntaje = 0
	if has_node("HUD/Puntaje"):
		$HUD/Puntaje.text = "Puntaje: 0"
	
	ultimo_inicio = 4
	var pos_x = pajaro.position.x if is_instance_valid(pajaro) else 0.0
	siguiente_suelo = int(pos_x / (COLS_SUELO * CELDA)) - 2
	siguiente_col = int(pos_x / CELDA) + COLS_PRIMER_TUBO
	
	generar_todo()


# ---------------------------------------------------------------
# INSTANCIACIÓN DEL JEFE OJO GIGANTE
# ---------------------------------------------------------------
func actualizar_ojo_gigante():
	if is_instance_valid(inst_ojo):
		return

	if not is_instance_valid(pajaro):
		return

	inst_ojo = ojo_escena.instantiate()
	inst_ojo.pajaro = pajaro
	
	# Aparece a la izquierda del pájaro y centrado en Y = 410.0
	inst_ojo.global_position = Vector2(pajaro.global_position.x - 450.0, 410.0)
	
	if inst_ojo.has_signal("body_entered"):
		inst_ojo.body_entered.connect(_on_enemigo_tocado)
		
	$Mapa.add_child(inst_ojo)


# ---------------------------------------------------------------
# GENERACIÓN INFINITA
# ---------------------------------------------------------------
func generar_todo():
	if not is_instance_valid(pajaro):
		return
		
	var ancho_suelo = COLS_SUELO * CELDA
	while siguiente_suelo * ancho_suelo < pajaro.position.x + COLS_ADELANTE * CELDA:
		crear_suelo(siguiente_suelo)
		siguiente_suelo += 1
		
	var col_limite = int(pajaro.position.x / CELDA) + COLS_ADELANTE
	while siguiente_col < col_limite:
		crear_obstaculo(siguiente_col)
		siguiente_col += randi_range(SEP_MIN, SEP_MAX)


func limpiar():
	if not is_instance_valid(pajaro):
		return
		
	var limite_x = pajaro.position.x - 1500
	
	for i in range(obstaculos.size() - 1, -1, -1):
		var n = obstaculos[i]
		if not is_instance_valid(n):
			obstaculos.remove_at(i)
		elif n.position.x < limite_x:
			n.queue_free()
			obstaculos.remove_at(i)
			
	for i in range(suelos.size() - 1, -1, -1):
		var s = suelos[i]
		if not is_instance_valid(s):
			suelos.remove_at(i)
		elif s.position.x + COLS_SUELO * CELDA < limite_x:
			s.queue_free()
			suelos.remove_at(i)


# ---------------------------------------------------------------
# CONSTRUCCIÓN DE TORRES RESPETANDO TRANSFORMACIONES BASE DEL EDITOR
# ---------------------------------------------------------------
func crear_obstaculo(col: int):
	# 1. Definir el hueco por donde pasa el pájaro
	var hueco = randi_range(HUECO_MIN, HUECO_MAX)

	# Limitar el rango para asegurar que el hueco quede centrado y visible
	var minimo = max(2, ultimo_inicio - CAMBIO_MAX)
	var maximo = min(FILAS - 2 - hueco, ultimo_inicio + CAMBIO_MAX)
	if minimo > maximo:
		minimo = maximo
		
	var inicio = randi_range(minimo, maximo)
	
	if abs(inicio - ultimo_inicio) < 2:
		if randf() > 0.5 and inicio + 2 <= maximo:
			inicio += 2
		elif inicio - 2 >= minimo:
			inicio -= 2
			
	ultimo_inicio = inicio
	var centro_x = (col + 0.5) * CELDA

	# -----------------------------------------------------------
	# 1. TORRE SUPERIOR (Cuelga del techo hacia abajo)
	# -----------------------------------------------------------
	var alto_arriba = inicio * CELDA
	if alto_arriba > 0:
		var tubo_arriba = tubo_escena.instantiate()
		tubo_arriba.position = Vector2(centro_x, alto_arriba / 2.0)
		
		# Factor de estiramiento vertical basado en la altura objetivo vs base
		var factor_y = alto_arriba / ALTURA_BASE_TORRE
		
		if tubo_arriba.has_node("Sprite2D"):
			var sprite = tubo_arriba.get_node("Sprite2D")
			sprite.flip_v = true # La copa mira hacia el hueco
			
			# Multiplica la escala base del editor sin modificar X
			var escala_base_x = sprite.scale.x if sprite.scale.x != 0 else 1.0
			var escala_base_y = sprite.scale.y if sprite.scale.y != 0 else 1.0
			sprite.scale = Vector2(escala_base_x, escala_base_y * factor_y)
			
		if tubo_arriba.has_node("CollisionShape2D"):
			var colision = tubo_arriba.get_node("CollisionShape2D")
			var escala_col_x = colision.scale.x if colision.scale.x != 0 else 1.0
			var escala_col_y = colision.scale.y if colision.scale.y != 0 else 1.0
			colision.scale = Vector2(escala_col_x, escala_col_y * factor_y)

		tubo_arriba.add_to_group("enemigos")
		if tubo_arriba.has_signal("body_entered"):
			tubo_arriba.body_entered.connect(_on_enemigo_tocado)
		$Mapa.add_child(tubo_arriba)
		obstaculos.append(tubo_arriba)

	# -----------------------------------------------------------
	# 2. TORRE INFERIOR (Nace desde el suelo hacia arriba)
	# -----------------------------------------------------------
	var y_inicio_abajo = (inicio + hueco) * CELDA
	var alto_abajo = (FILAS * CELDA) - y_inicio_abajo
	if alto_abajo > 0:
		var tubo_abajo = tubo_escena.instantiate()
		tubo_abajo.position = Vector2(centro_x, y_inicio_abajo + (alto_abajo / 2.0))
		
		var factor_y = alto_abajo / ALTURA_BASE_TORRE
		
		if tubo_abajo.has_node("Sprite2D"):
			var sprite = tubo_abajo.get_node("Sprite2D")
			sprite.flip_v = false
			
			var escala_base_x = sprite.scale.x if sprite.scale.x != 0 else 1.0
			var escala_base_y = sprite.scale.y if sprite.scale.y != 0 else 1.0
			sprite.scale = Vector2(escala_base_x, escala_base_y * factor_y)
			
		if tubo_abajo.has_node("CollisionShape2D"):
			var colision = tubo_abajo.get_node("CollisionShape2D")
			var escala_col_x = colision.scale.x if colision.scale.x != 0 else 1.0
			var escala_col_y = colision.scale.y if colision.scale.y != 0 else 1.0
			colision.scale = Vector2(escala_col_x, escala_col_y * factor_y)

		tubo_abajo.add_to_group("enemigos")
		if tubo_abajo.has_signal("body_entered"):
			tubo_abajo.body_entered.connect(_on_enemigo_tocado)
		$Mapa.add_child(tubo_abajo)
		obstaculos.append(tubo_abajo)

	# -----------------------------------------------------------
	# 3. SENSOR DE PUNTOS E ÍTEMS
	# -----------------------------------------------------------
	crear_sensor_punto(col, inicio, hueco)
	var fila_item = inicio + int(hueco / 2)
	var r = randf()
	if r < 0.3:
		poner_item(moneda_escena, col, fila_item)
	elif r < 0.45:
		poner_item(pluma_escena, col, fila_item)


func crear_sensor_punto(col: int, inicio_hueco: int, alto_hueco: int):
	var area_punto = Area2D.new()
	var colision = CollisionShape2D.new()
	var forma = RectangleShape2D.new()
	
	forma.size = Vector2(8, alto_hueco * CELDA)
	colision.shape = forma
	
	area_punto.add_child(colision)
	# CORRECCIÓN DE PUNTAJE APLICADA AQUÍ: Se multiplica por CELDA
	area_punto.position = Vector2((col + 0.5) * CELDA, (inicio_hueco + alto_hueco / 2.0) * CELDA)
	
	area_punto.body_entered.connect(func(cuerpo): _verificar_punto(cuerpo, area_punto))
	area_punto.area_entered.connect(func(area): _verificar_punto(area, area_punto))
	
	$Mapa.add_child(area_punto)
	obstaculos.append(area_punto)


func poner_item(escena, col: int, fila: int):
	var nodo = escena.instantiate()
	nodo.position = Vector2(col + 0.5, fila + 0.5) * CELDA
	if nodo.has_signal("body_entered"):
		nodo.body_entered.connect(_on_item_recogido.bind(nodo))
	$Mapa.add_child(nodo)
	obstaculos.append(nodo)


func crear_suelo(indice: int):
	var ancho = COLS_SUELO * CELDA
	var contenedor = Node2D.new()
	contenedor.position.x = indice * ancho
	$Mapa.add_child(contenedor)
	suelos.append(contenedor)

	for fila in [0, FILAS - 1]:
		var cuerpo = StaticBody2D.new()
		cuerpo.position = Vector2(ancho / 2.0, (fila + 0.5) * CELDA)

		var forma = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(ancho, CELDA)
		forma.shape = rect
		cuerpo.add_child(forma)

		var visual = ColorRect.new()
		visual.color = COLOR_BLOQUES
		visual.size = Vector2(ancho, CELDA)
		visual.position = -visual.size / 2.0
		cuerpo.add_child(visual)

		var borde = ColorRect.new()
		borde.color = COLOR_BORDE
		borde.size = Vector2(ancho, 8)
		if fila == 0:
			borde.position = Vector2(-ancho / 2.0, CELDA / 2.0 - 8)
		else:
			borde.position = Vector2(-ancho / 2.0, -CELDA / 2.0)
		cuerpo.add_child(borde)

		contenedor.add_child(cuerpo)


# ---------------------------------------------------------------
# DETECCIÓN DE COLISIONES Y PUNTOS
# ---------------------------------------------------------------
func _verificar_punto(objeto, area_sensor):
	if objeto == pajaro or (is_instance_valid(pajaro) and objeto.get_parent() == pajaro):
		puntaje += 1
		if has_node("HUD/Puntaje"):
			$HUD/Puntaje.text = "Puntaje: " + str(puntaje)
		area_sensor.queue_free()


func _on_enemigo_tocado(cuerpo):
	if cuerpo == pajaro:
		if pajaro.has_method("morir"):
			pajaro.morir()


func _on_item_recogido(cuerpo, item_nodo):
	if cuerpo == pajaro:
		item_nodo.queue_free()
