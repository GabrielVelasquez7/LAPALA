extends Control

var todas_las_preguntas = []
var preguntas_filtradas = []
var preguntas = []
var pregunta_actual = {}
var indice_pregunta = 0
var anio_seleccionado = -1

var question_container: VBoxContainer
var question_label: Label
var options_container: VBoxContainer
var result_label: Label

func set_preguntas_data(data):
	anio_seleccionado = data["anio"]
	todas_las_preguntas = data["preguntas"]

func _ready():
	_inicializar_nodos()
	anio_seleccionado = Global.ano_seleccionado
	print("Año seleccionado en trivia (ready):", anio_seleccionado)
	
	leer_preguntas()  # Aquí cargas las preguntas
	
	if anio_seleccionado == -1:
		printerr("Error: no se ha recibido un año válido")
		return

	filtrar_y_cargar_preguntas(anio_seleccionado)

func _inicializar_nodos():
	question_container = $question_container
	question_label = question_container.get_node("question_label")
	options_container = question_container.get_node("options_container")
	result_label = question_container.get_node("result_label")

func filtrar_y_cargar_preguntas(anio):
	preguntas_filtradas.clear()
	for pregunta in todas_las_preguntas:
		if pregunta.get("año", -1) == anio:
			preguntas_filtradas.append(pregunta)
	
	if preguntas_filtradas.is_empty():
		printerr("No hay preguntas para el año seleccionado")
		return

	preguntas = preguntas_filtradas
	indice_pregunta = 0
	cargar_pregunta()

func cargar_pregunta():
	if indice_pregunta >= preguntas.size():
		question_label.text = "¡Fin del cuestionario!"
		result_label.text = ""
		for btn in options_container.get_children():
			if btn is Button:
				btn.hide()
		return

	pregunta_actual = preguntas[indice_pregunta]
	question_label.text = pregunta_actual.get("pregunta", "Sin pregunta")
	result_label.text = ""

	var opciones = pregunta_actual.get("opciones", [])

	for i in range(options_container.get_child_count()):
		var btn = options_container.get_child(i)
		if btn is Button:
			if i < opciones.size():
				btn.text = opciones[i]
				btn.disabled = false
				btn.show()
				btn.set_meta("option_index", i)

				# Desconectar conexión anterior si existe
				if btn.pressed.is_connected(Callable(self, "_on_option_pressed")):
					btn.pressed.disconnect(Callable(self, "_on_option_pressed"))

				# Conectar usando Callable con bind
				btn.pressed.connect(Callable(self, "_on_option_pressed").bind(btn))
			else:
				btn.hide()
	pregunta_actual = preguntas[indice_pregunta]
	question_label.text = pregunta_actual.get("pregunta", "Sin pregunta")
	result_label.text = ""




func leer_preguntas():
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if file:
		var data_text = file.get_as_text()
		var parsed = JSON.parse_string(data_text)
		if typeof(parsed) == TYPE_ARRAY:
			todas_las_preguntas = parsed
			print("Preguntas cargadas:", todas_las_preguntas.size())
		else:
			printerr("Error: JSON no es un array")
		file.close()
	else:
		printerr("No se pudo abrir el archivo de preguntas")



func _on_option_pressed(button):
	var index = button.get_meta("option_index")
	if index == pregunta_actual["respuesta_correcta"]:
		result_label.text = "¡Correcto!"
	else:
		result_label.text = "Incorrecto 😢"

	for btn in options_container.get_children():
		if btn is Button:
			btn.disabled = true

	await get_tree().create_timer(1.5).timeout
	indice_pregunta += 1
	cargar_pregunta()
