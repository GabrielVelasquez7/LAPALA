extends Control

var preguntas = []
var pregunta_actual = {}
var indice_pregunta = 0

func _ready():
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if file:
		var data = file.get_as_text()
		var parsed = JSON.parse_string(data)

		if typeof(parsed) == TYPE_ARRAY and parsed.size() > 0:
			preguntas = parsed
			indice_pregunta = 0
			cargar_pregunta()
		else:
			print("JSON vacío o estructura incorrecta")
		
		file.close()
	else:
		print("No se pudo abrir preguntas.json")

func cargar_pregunta():
	if indice_pregunta >= preguntas.size():
		$question_label.text = "¡Fin del cuestionario!"
		$result_label.text = ""
		for btn in $options_container.get_children():
			btn.hide()
		return

	pregunta_actual = preguntas[indice_pregunta]
	$question_label.text = pregunta_actual.get("pregunta", "Sin pregunta")
	$result_label.text = ""

	var opciones = pregunta_actual.get("opciones", [])
	for i in range($options_container.get_child_count()):
		var btn = $options_container.get_child(i)
		if i < opciones.size():
			btn.text = opciones[i]
			btn.disabled = false
			btn.show()
			btn.set_meta("option_index", i)
			if not btn.is_connected("pressed", Callable(self, "_on_option_pressed").bind(btn)):
				btn.connect("pressed", Callable(self, "_on_option_pressed").bind(btn))
		else:
			btn.hide()

func _on_option_pressed(button):
	var index = button.get_meta("option_index")
	if index == pregunta_actual["respuesta_correcta"]:
		$result_label.text = "¡Correcto!"
	else:
		$result_label.text = "Incorrecto 😢"

	for btn in $options_container.get_children():
		btn.disabled = true

	# Esperar 1.5 segundos y cargar la siguiente pregunta
	await get_tree().create_timer(1.5).timeout
	indice_pregunta += 1
	cargar_pregunta()
