extends Control

# Variables mejor organizadas y tipadas
var todas_las_preguntas: Array = []
var preguntas_filtradas: Array = []
var preguntas: Array = []
var pregunta_actual: Dictionary = {}
var indice_pregunta: int = 0
var anio_seleccionado: int = -1
var respuestas_seleccionadas: Array = []  # [{correcta: bool, cuota: float, ...}]
var multiplicador_total: float = 1.0

# Nodos de la UI (ahora con tipos explícitos)
@onready var continuar_button: Button = $continue
@onready var question_container: VBoxContainer = $question_container
@onready var final_results_container: VBoxContainer = $final_results_container
@onready var question_label: Label = $question_container/question_label
@onready var options_container: VBoxContainer = $question_container/options_container
@onready var result_label: Label = $question_container/result_label
@onready var secondary_questions_container: VBoxContainer = $secondary_questions_container

func set_preguntas_data(data: Dictionary) -> void:
	anio_seleccionado = data.get("anio", -1)
	todas_las_preguntas = data.get("preguntas", [])

func _ready() -> void:
	# Configuración inicial
	continuar_button.hide()
	continuar_button.pressed.connect(_on_continuar_pressed)
	
	anio_seleccionado = Global.ano_seleccionado
	print("Año seleccionado en trivia (ready): ", anio_seleccionado)
	
	if not _cargar_preguntas_desde_json():
		printerr("Error al cargar preguntas")
		return
	
	if anio_seleccionado == -1:
		printerr("Error: no se ha recibido un año válido")
		return
	
	_filtrar_y_cargar_preguntas(anio_seleccionado)

func _filtrar_y_cargar_preguntas(anio: int) -> void:
	preguntas_filtradas = todas_las_preguntas.filter(func(p): return p.get("año", -1) == anio)
	
	if preguntas_filtradas.is_empty():
		printerr("No hay preguntas para el año seleccionado: ", anio)
		return
	
	preguntas = preguntas_filtradas
	indice_pregunta = 0
	_cargar_pregunta()

func _cargar_preguntas_desde_json() -> bool:
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if not file:
		printerr("No se pudo abrir el archivo de preguntas")
		return false
	
	var data_text = file.get_as_text()
	var parsed = JSON.parse_string(data_text)
	file.close()
	
	if typeof(parsed) != TYPE_ARRAY:
		printerr("Error: JSON no es un array")
		return false
	
	todas_las_preguntas = parsed
	print("Preguntas cargadas: ", todas_las_preguntas.size())
	return true

func _cargar_pregunta() -> void:
	# Limpiar UI
	_limpiar_contenedores()
	
	# Verificar fin del cuestionario
	if indice_pregunta >= preguntas.size():
		_mostrar_resultados_finales()
		return
	
	# Configurar pregunta actual
	pregunta_actual = preguntas[indice_pregunta]
	
	# Mostrar pregunta principal
	_mostrar_pregunta_principal()
	
	# Mostrar preguntas secundarias si existen
	if pregunta_actual.has("secundarias") and not pregunta_actual["secundarias"].is_empty():
		_mostrar_preguntas_secundarias()
	else:
		# Si no hay secundarias, preparar para siguiente pregunta
		continuar_button.show()

func _limpiar_contenedores() -> void:
	for child in options_container.get_children():
		child.queue_free()
	
	for child in secondary_questions_container.get_children():
		child.queue_free()
	
	question_container.hide()
	secondary_questions_container.hide()
	continuar_button.hide()
	final_results_container.hide()

func _mostrar_pregunta_principal() -> void:
	question_container.show()
	
	var cuota = pregunta_actual.get("cuota", 1.0)
	question_label.text = "{0} (Cuota: x{1})".format([
		pregunta_actual.get("pregunta", "Sin pregunta"),
		cuota
	])
	
	var opciones = pregunta_actual.get("opciones", [])
	for i in range(opciones.size()):
		var btn = Button.new()
		btn.text = opciones[i]
		btn.set_meta("option_index", i)
		btn.pressed.connect(_on_option_pressed.bind(btn))
		options_container.add_child(btn)

func _mostrar_preguntas_secundarias() -> void:
	secondary_questions_container.show()
	
	for secundaria in pregunta_actual.get("secundarias", []):
		var box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		
		var cuota_sec = secundaria.get("cuota", 1.0)
		var label = Label.new()
		label.text = "{0} (Cuota: x{1})".format([
			secundaria.get("pregunta", "Sin pregunta secundaria"),
			cuota_sec
		])
		box.add_child(label)
		
		var opciones_sec = secundaria.get("opciones", [])
		for i in range(opciones_sec.size()):
			var btn = Button.new()
			btn.text = opciones_sec[i]
			btn.set_meta("option_index", i)
			btn.pressed.connect(_on_secundaria_option_pressed.bind(
				btn, secundaria["respuesta_correcta"], cuota_sec
			))
			box.add_child(btn)
		
		secondary_questions_container.add_child(box)

func _mostrar_resultados_finales() -> void:
	final_results_container.show()
	
	# Limpiar resultados anteriores
	for child in final_results_container.get_children():
		child.queue_free()
	
	var todas_correctas = true
	var multiplicador = 1.0
	
	# Mostrar cada resultado
	for resultado in respuestas_seleccionadas:
		var item = Label.new()
		var estado = "✔ Correcta" if resultado["correcta"] else "✘ Incorrecta"
		
		if not resultado["correcta"]:
			todas_correctas = false
		multiplicador *= resultado["cuota"]
		
		item.text = "{0}\n{1} | Cuota: x{2}\n".format([
			resultado["pregunta"],
			estado,
			resultado["cuota"]
		])
		final_results_container.add_child(item)
	
	# Mostrar resumen final
	var resumen = Label.new()
	if respuestas_seleccionadas.size() == 3:
		resumen.text = "🎉 ¡Ganaste la apuesta combinada!\nMultiplicador final: x{0}".format(
			[snapped(multiplicador, 0.01)]
		) if todas_correctas else "❌ Perdiste la apuesta combinada.\nMultiplicador anulado."
	else:
		resumen.text = "Preguntas respondidas: {0}".format([respuestas_seleccionadas.size()])
	
	final_results_container.add_child(resumen)

func _on_option_pressed(button: Button) -> void:
	var index = button.get_meta("option_index")
	var es_correcta = index == pregunta_actual["respuesta_correcta"]
	var cuota = pregunta_actual.get("cuota", 1.0)
	
	# Registrar respuesta
	respuestas_seleccionadas.append({
		"correcta": es_correcta,
		"cuota": cuota,
		"anio": anio_seleccionado,
		"pregunta": pregunta_actual.get("pregunta", ""),
		"seleccion": index
	})
	
	if es_correcta:
		multiplicador_total *= cuota
	
	# Desactivar botones
	for btn in options_container.get_children():
		if btn is Button:
			btn.disabled = true
	
	# Si no hay secundarias, pasar a siguiente pregunta después de un delay
	if not pregunta_actual.has("secundarias") or pregunta_actual["secundarias"].is_empty():
		await get_tree().create_timer(1.5).timeout
		indice_pregunta += 1
		_cargar_pregunta()

func _on_secundaria_option_pressed(button: Button, respuesta_correcta: int, cuota_sec: float) -> void:
	var index = button.get_meta("option_index")
	var resultado = index == respuesta_correcta
	
	# Desactivar botones en este grupo
	for sibling in button.get_parent().get_children():
		if sibling is Button:
			sibling.disabled = true
	
	button.get_parent().set_meta("respondida", true)
	button.get_parent().set_meta("es_correcta", resultado)
	
	# Registrar respuesta
	respuestas_seleccionadas.append({
		"pregunta": button.get_parent().get_child(0).text,
		"correcta": resultado,
		"cuota": cuota_sec
	})
	
	# Verificar si todas las secundarias están respondidas
	var todas_respondidas = true
	for child in secondary_questions_container.get_children():
		if not child.has_meta("respondida") or not child.get_meta("respondida"):
			todas_respondidas = false
			break
	
	if todas_respondidas:
		continuar_button.show()

func _on_continuar_pressed() -> void:
	# Opcional: contar respuestas secundarias
	var stats = {"correctas": 0, "incorrectas": 0}
	for child in secondary_questions_container.get_children():
		if child.has_meta("es_correcta"):
			if child.get_meta("es_correcta"):
				stats.correctas += 1
			else:
				stats.incorrectas += 1
	print("Secundarias - Correctas: %s, Incorrectas: %s" % [stats.correctas, stats.incorrectas])
	
	# Pasar a siguiente pregunta
	indice_pregunta += 1
	_cargar_pregunta()
