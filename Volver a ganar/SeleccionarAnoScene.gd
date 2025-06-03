extends Control

var todas_las_preguntas = []
var year_selector: OptionButton

func _ready():
	year_selector = $year_selector
	cargar_preguntas()
	llenar_selector_anios()
	$boton_continuar.disabled = true
	year_selector.item_selected.connect(_on_year_selected)
	$boton_continuar.pressed.connect(_on_boton_continuar_pressed)

func cargar_preguntas():
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if file:
		var data = file.get_as_text()
		var parsed = JSON.parse_string(data)
		todas_las_preguntas = parsed if typeof(parsed) == TYPE_ARRAY else []
		file.close()

func llenar_selector_anios():
	var anios = {}
	for pregunta in todas_las_preguntas:
		anios[pregunta["año"]] = true
	var ordenados = anios.keys()
	ordenados.sort()
	ordenados.reverse()
	year_selector.clear()
	year_selector.add_item("Selecciona un año", -1)
	year_selector.set_item_disabled(0, true)
	for anio in ordenados:
		year_selector.add_item(str(anio), anio)

func _on_year_selected(index):
	if year_selector.get_item_id(index) != -1:
		$boton_continuar.disabled = false

func _on_boton_continuar_pressed():
	var anio = year_selector.get_selected_id()
	if anio == -1:
		printerr("No se ha seleccionado un año válido")
		return
	Global.ano_seleccionado = anio
	print("Asignando año:", anio)
	call_deferred("_cargar_trivia")

func _cargar_trivia():
	var trivia_scene = preload("res://trivia_scene.tscn").instantiate()
	get_tree().root.add_child(trivia_scene)
	queue_free()
