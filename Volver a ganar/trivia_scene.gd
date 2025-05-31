extends Control

# Variables de datos
var todas_las_preguntas = []
var preguntas_filtradas = []
var preguntas = []
var pregunta_actual = {}
var indice_pregunta = 0

# Referencias a nodos
var year_selector: OptionButton
var question_container: VBoxContainer
var question_label: Label
var options_container: VBoxContainer
var result_label: Label

func _ready():
	# Inicializar todos los nodos necesarios
	_inicializar_nodos()
	
	# Configuración inicial
	cargar_preguntas()
	llenar_selector_anios()
	question_container.visible = false

func _inicializar_nodos():
	# 1. OptionButton (selector de años)
	if not has_node("year_selector"):
		year_selector = OptionButton.new()
		year_selector.name = "year_selector"
		add_child(year_selector)
		year_selector.size = Vector2(250, 40)
		year_selector.position = Vector2(20, 20)
		print("Creado year_selector dinámicamente")
	else:
		year_selector = $year_selector
	
	# 2. Contenedor principal de preguntas
	if not has_node("pregunta_container"):
		question_container = VBoxContainer.new()
		question_container.name = "pregunta_container"
		add_child(question_container)
		question_container.size = Vector2(600, 400)
		question_container.position = Vector2(20, 80)
		question_container.visible = false
		print("Creado pregunta_container dinámicamente")
	else:
		question_container = $pregunta_container
	
	# 3. Label de pregunta
	if not question_container.has_node("question_label"):
		question_label = Label.new()
		question_label.name = "question_label"
		question_container.add_child(question_label)
		question_label.size = Vector2(580, 100)
		question_label.text = "Pregunta aparecerá aquí"
		print("Creado question_label dinámicamente")
	else:
		question_label = $pregunta_container/question_label
	
	# 4. Contenedor de opciones
	if not question_container.has_node("options_container"):
		options_container = VBoxContainer.new()
		options_container.name = "options_container"
		question_container.add_child(options_container)
		options_container.size = Vector2(580, 200)
		options_container.position = Vector2(0, 120)
		
		# Crear 4 botones de opciones
		for i in range(4):
			var btn = Button.new()
			btn.name = "option_btn_%d" % i
			btn.text = "Opción %d" % (i+1)
			btn.size = Vector2(580, 50)
			options_container.add_child(btn)
		print("Creado options_container con 4 botones dinámicamente")
	else:
		options_container = $pregunta_container/options_container
	
	# 5. Label de resultado
	if not question_container.has_node("result_label"):
		result_label = Label.new()
		result_label.name = "result_label"
		question_container.add_child(result_label)
		result_label.size = Vector2(580, 50)
		result_label.position = Vector2(0, 320)
		result_label.text = ""
		print("Creado result_label dinámicamente")
	else:
		result_label = $pregunta_container/result_label

func cargar_preguntas():
	print("Cargando preguntas...")
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if file:
		var data = file.get_as_text()
		var parsed = JSON.parse_string(data)

		if typeof(parsed) == TYPE_ARRAY and parsed.size() > 0:
			todas_las_preguntas = parsed
			print("Preguntas cargadas:", todas_las_preguntas.size())
		else:
			printerr("JSON vacío o estructura incorrecta")
		
		file.close()
	else:
		printerr("Error al abrir preguntas.json. Código:", FileAccess.get_open_error())
		
	# Datos de prueba si el archivo no carga
	if todas_las_preguntas.is_empty():
		printerr("Usando datos de prueba")
		todas_las_preguntas = [
			{"año": 2023, "pregunta": "Pregunta prueba 2023", "opciones": ["Opción A", "Opción B", "Opción C", "Opción D"], "respuesta_correcta": 0},
			{"año": 2022, "pregunta": "Pregunta prueba 2022", "opciones": ["Opción 1", "Opción 2", "Opción 3", "Opción 4"], "respuesta_correcta": 1}
		]

func llenar_selector_anios():
	if not is_instance_valid(year_selector):
		printerr("Error: Selector de años no válido")
		return
	
	year_selector.clear()
	
	# Extraer años únicos
	var anios_set = {}
	for pregunta in todas_las_preguntas:
		if "año" in pregunta:
			anios_set[pregunta["año"]] = true
	
	if anios_set.is_empty():
		printerr("No se encontraron años en las preguntas")
		year_selector.add_item("No hay años disponibles", -1)
		year_selector.disabled = true
		return
	
	# Ordenar años (más reciente primero)
	var anios_ordenados = anios_set.keys()
	anios_ordenados.sort()
	anios_ordenados.reverse()
	
	# Añadir opción por defecto
	year_selector.add_item("Selecciona un año", -1)
	year_selector.set_item_disabled(0, true)
	
	# Añadir años al selector
	for anio in anios_ordenados:
		year_selector.add_item(str(anio), anio)
	
	# Conectar señal si no está conectada
	if year_selector.item_selected.get_connections().is_empty():
		year_selector.item_selected.connect(_on_year_selector_item_selected)
	
	print("Selector llenado con", year_selector.item_count, "años")

func _on_year_selector_item_selected(index):
	if index == 0:  # Ignorar selección por defecto
		return
		
	var anio_seleccionado = year_selector.get_item_id(index)
	print("Año seleccionado:", anio_seleccionado)
	
	# Filtrar preguntas
	preguntas_filtradas = []
	for pregunta in todas_las_preguntas:
		if pregunta.get("año", -1) == anio_seleccionado:
			preguntas_filtradas.append(pregunta)
	
	if preguntas_filtradas.is_empty():
		printerr("No hay preguntas para el año seleccionado")
		question_container.visible = false
		return
	
	preguntas = preguntas_filtradas
	indice_pregunta = 0
	question_container.visible = true
	cargar_pregunta()

func cargar_pregunta():
	if indice_pregunta >= preguntas.size():
		question_label.text = "¡Fin del cuestionario!"
		result_label.text = ""
		for btn in options_container.get_children():
			btn.hide()
		return

	pregunta_actual = preguntas[indice_pregunta]
	question_label.text = pregunta_actual.get("pregunta", "Sin pregunta")
	result_label.text = ""

	var opciones = pregunta_actual.get("opciones", [])
	for i in range(options_container.get_child_count()):
		var btn = options_container.get_child(i)
		if i < opciones.size():
			btn.text = opciones[i]
			btn.disabled = false
			btn.show()
			btn.set_meta("option_index", i)
			
			# Conectar señal si no está conectada
			if not btn.pressed.is_connected(_on_option_pressed.bind(btn)):
				btn.pressed.connect(_on_option_pressed.bind(btn))
		else:
			btn.hide()

func _on_option_pressed(button):
	var index = button.get_meta("option_index")
	if index == pregunta_actual["respuesta_correcta"]:
		result_label.text = "¡Correcto!"
	else:
		result_label.text = "Incorrecto 😢"

	# Deshabilitar todos los botones
	for btn in options_container.get_children():
		btn.disabled = true

	# Esperar y pasar a siguiente pregunta
	await get_tree().create_timer(1.5).timeout
	indice_pregunta += 1
<<<<<<< Updated upstream
	cargar_pregunta()
=======
	_cargar_pregunta()

# --- RESULTADOS FINALES ---
func _mostrar_resultados_finales() -> void:
	final_results_container.show()
	# (Implementa aquí tu lógica para mostrar ganancias/perdidas totales)


func _on_rewarded_pressed():
	admob.load_rewarded_video()
	await admob.rewarded_video_loaded
	admob.show_rewarded_video()



func _on_banner_pressed():
	admob.load_banner()
	await admob.banner_loaded
	admob.show_banner()
>>>>>>> Stashed changes
