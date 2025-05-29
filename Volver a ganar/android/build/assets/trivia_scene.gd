extends Control

# --- VARIABLES PRINCIPALES ---
var todas_las_preguntas: Array = []
var preguntas_filtradas: Array = []
var preguntas: Array = []
var pregunta_actual: Dictionary = {}
var indice_pregunta: int = 0
var anio_seleccionado: int = -1
var respuestas_seleccionadas: Array = []  # [{correcta: bool, cuota: float, ...}]
var multiplicador_total: float = 1.0
var dinero: float = 100.0  # Dinero inicial del jugador

# Selecciones temporales
var seleccion_temporal: int = -1
var selecciones_secundarias: Dictionary = {}  # Ej: {"0": 1, "1": -1} (índice secundaria: opción)

# Nodos UI
@onready var continuar_button: Button = $continue
@onready var question_container: VBoxContainer = $question_container
@onready var final_results_container: VBoxContainer = $final_results_container
@onready var question_label: Label = $question_container/question_label
@onready var options_container: VBoxContainer = $question_container/options_container
@onready var result_label: Label = $question_container/result_label
@onready var secondary_questions_container: VBoxContainer = $secondary_questions_container
@onready var money_label: Label = $money_label  # Añade este nodo en tu escena
@onready var admob = $AdMob

# --- FUNCIONES PRINCIPALES ---
func _ready() -> void:
	_configurar_ui_inicial()
	_cargar_datos_iniciales()
	print("🔍 Iniciando verificación de plugin...")
	if Engine.has_singleton("AdMob"):
		var admob = Engine.get_singleton("AdMob")
		print("✅ Plugin detectado: ", admob)
	else:
		printerr("❌ Error: Plugin no encontrado")
	print("Lista de singletons disponibles: ", Engine.get_singleton_list())

func _configurar_ui_inicial() -> void:
	continuar_button.hide()
	continuar_button.pressed.connect(_on_continuar_pressed)
	money_label.text = "Dinero: $%.2f" % dinero

func _cargar_datos_iniciales() -> void:
	anio_seleccionado = Global.ano_seleccionado
	if not _cargar_preguntas_desde_json():
		printerr("Error al cargar preguntas")
		return
	_filtrar_y_cargar_preguntas(anio_seleccionado)

# --- CARGAR Y FILTRAR PREGUNTAS ---
func _cargar_preguntas_desde_json() -> bool:
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if not file:
		printerr("No se pudo abrir el archivo de preguntas")
		return false
	todas_las_preguntas = JSON.parse_string(file.get_as_text())
	file.close()
	return true

func _filtrar_y_cargar_preguntas(anio: int) -> void:
	preguntas_filtradas = todas_las_preguntas.filter(func(p): return p.get("año") == anio)
	if preguntas_filtradas.is_empty():
		printerr("No hay preguntas para el año: ", anio)
		return
	preguntas = preguntas_filtradas
	indice_pregunta = 0
	_cargar_pregunta()
	

	

# --- MANEJO DE PREGUNTAS ---
func _cargar_pregunta() -> void:
	_limpiar_contenedores()
	if indice_pregunta >= preguntas.size():
		_mostrar_resultados_finales()
		return
	
	pregunta_actual = preguntas[indice_pregunta]
	_mostrar_pregunta_principal()
	if pregunta_actual.has("secundarias"):
		_mostrar_preguntas_secundarias()

func _mostrar_pregunta_principal() -> void:
	question_container.show()
	question_label.text = "{0} (Cuota: x{1})".format([
		pregunta_actual["pregunta"], pregunta_actual["cuota"]
	])
	
	for i in pregunta_actual["opciones"].size():
		var btn = Button.new()
		btn.text = pregunta_actual["opciones"][i]
		btn.set_meta("option_index", i)
		btn.pressed.connect(_on_option_pressed.bind(btn))
		options_container.add_child(btn)

func _mostrar_preguntas_secundarias() -> void:
	secondary_questions_container.show()
	selecciones_secundarias.clear()
	
	for i in pregunta_actual["secundarias"].size():
		var secundaria = pregunta_actual["secundarias"][i]
		var box = VBoxContainer.new()
		box.set_meta("secundaria_index", i)
		
		var label = Label.new()
		label.text = "{0} (Cuota: x{1})".format([secundaria["pregunta"], secundaria["cuota"]])
		box.add_child(label)
		
		for j in secundaria["opciones"].size():
			var btn = Button.new()
			btn.text = secundaria["opciones"][j]
			btn.set_meta("option_index", j)
			btn.pressed.connect(_on_secundaria_option_pressed.bind(btn, i))
			box.add_child(btn)
		
		secondary_questions_container.add_child(box)

# --- MANEJO DE SELECCIONES ---
func _on_option_pressed(button: Button) -> void:
	seleccion_temporal = button.get_meta("option_index")
	# Resaltar selección
	for btn in options_container.get_children():
		btn.modulate = Color.WHITE if btn != button else Color.GREEN

func _on_secundaria_option_pressed(button: Button, secundaria_index: int) -> void:
	selecciones_secundarias[str(secundaria_index)] = button.get_meta("option_index")
	# Resaltar selección
	for sibling in button.get_parent().get_children():
		if sibling is Button:
			sibling.modulate = Color.WHITE if sibling != button else Color.GREEN
			_verificar_selecciones()


func _limpiar_contenedores() -> void:
	# Limpia las opciones principales
	for child in options_container.get_children():
		child.queue_free()
	
	# Limpia las preguntas secundarias
	for child in secondary_questions_container.get_children():
		child.queue_free()
	
	# Reinicia selecciones temporales
	seleccion_temporal = -1
	selecciones_secundarias.clear()
	
	# Oculta contenedores no necesarios
	question_container.hide()
	secondary_questions_container.hide()
	continuar_button.hide()
	final_results_container.hide()


func _verificar_selecciones() -> void:
	var secundarias_completas = true
	if pregunta_actual.has("secundarias"):
		for i in pregunta_actual["secundarias"].size():
			if not selecciones_secundarias.has(str(i)):
				secundarias_completas = false
				break
	if seleccion_temporal != -1 and secundarias_completas:
		continuar_button.show()
	else:
		continuar_button.hide()

# --- CONFIRMAR APUESTA ---
func _on_continuar_pressed() -> void:
	if seleccion_temporal == -1:
		print("¡Selecciona una opción primero!")
		return
	
	# Procesar pregunta principal
	var acierto_principal = (seleccion_temporal == pregunta_actual["respuesta_correcta"])
	dinero *= pregunta_actual["cuota"] if acierto_principal else 0.0
	respuestas_seleccionadas.append({
		"pregunta": pregunta_actual["pregunta"],
		"correcta": acierto_principal,
		"cuota": pregunta_actual["cuota"]
	})
	
	# Procesar preguntas secundarias (si existen)
	if pregunta_actual.has("secundarias"):
		for i in pregunta_actual["secundarias"].size():
			var idx_str = str(i)
			if selecciones_secundarias.has(idx_str):
				var secundaria = pregunta_actual["secundarias"][i]
				var acierto_sec = (selecciones_secundarias[idx_str] == secundaria["respuesta_correcta"])
				dinero *= secundaria["cuota"] if acierto_sec else 0.0
				respuestas_seleccionadas.append({
					"pregunta": secundaria["pregunta"],
					"correcta": acierto_sec,
					"cuota": secundaria["cuota"]
				})
	
	# Actualizar UI y pasar a siguiente pregunta
	money_label.text = "Dinero: $%.2f" % dinero
	indice_pregunta += 1
	_cargar_pregunta()

# --- RESULTADOS FINALES ---
func _mostrar_resultados_finales() -> void:
	final_results_container.show()
	# (Implementa aquí tu lógica para mostrar ganancias/perdidas totales)


func _on_rewarded_pressed():
	admob.load_rewarded_video()
	await admob.load_rewarded_video_loaded
	admob.show_rewarded_video()
	pass # Replace with function body.
