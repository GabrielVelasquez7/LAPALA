extends Control

var todas_las_preguntas = []
var botones_anios: Array
var money_display_scene = preload("res://money_display.tscn")
var money_display: Control
var money_display_instance: Control

@onready var money_display_container: Control = $money_display_container

func _ready():
	botones_anios = [
		$year_container/year_1,
		$year_container/year_2,
		$year_container/year_3,
		$year_container/year_4
	]
	var money_scene = load("res://money_display.tscn")
	if money_scene:
		money_display_instance = money_scene.instantiate()
		money_display_container.add_child(money_display_instance)
		money_display_instance.set_money(Global.dinero)

	else:
		printerr("❌ No se pudo cargar la escena del display de dinero")
	# Verificación de años ganados y dinero
	print("Años ganados (al cargar Selección): ", Global.anios_ganados)
	print("Dinero actual: $", Global.dinero)
	
	# Aplicar condición de reset si dinero es 0
	if Global.dinero <= 0:
		Global.dinero = 100
		print("¡Dinero reseteado a $100!")
	
	# Actualizar el label de dinero (asegúrate de tener un Label llamado LabelDinero en tu escena)

	
	cargar_preguntas()
	seleccionar_anios_aleatorios()

	$boton_continuar.disabled = true
	$boton_continuar.pressed.connect(_on_boton_continuar_pressed)

	for boton in botones_anios:
		boton.pressed.connect(_on_boton_anio_pressed.bind(boton))

func cargar_preguntas():
	var file = FileAccess.open("res://data/preguntas.json", FileAccess.READ)
	if file:
		var data = file.get_as_text()
		var parsed = JSON.parse_string(data)
		todas_las_preguntas = parsed if typeof(parsed) == TYPE_ARRAY else []
		file.close()

func seleccionar_anios_aleatorios():
	var anios_disponibles = []
	for pregunta in todas_las_preguntas:
		var anio = pregunta["año"]
		if anio not in Global.anios_ganados and anio not in anios_disponibles:
			anios_disponibles.append(anio)

	anios_disponibles.shuffle()

	var seleccionados = anios_disponibles.slice(0, 4)
	for i in range(4):
		if i < seleccionados.size():
			botones_anios[i].text = str(seleccionados[i])
			botones_anios[i].visible = true
			botones_anios[i].disabled = false
			botones_anios[i].set_meta("anio", seleccionados[i])
		else:
			botones_anios[i].visible = false

func _on_boton_anio_pressed(boton):
	var anio = boton.get_meta("anio")
	Global.ano_seleccionado = anio
	print("Año seleccionado:", anio)
	$boton_continuar.disabled = false

	# Feedback visual
	for b in botones_anios:
		b.modulate = Color(1, 1, 1, 0.5)
	boton.modulate = Color(1, 1, 1, 1)

func _on_boton_continuar_pressed():
	var anio = Global.ano_seleccionado
	if anio == -1:
		printerr("No se ha seleccionado un año válido")
		return
	get_tree().change_scene_to_file("res://trivia_scene.tscn")
