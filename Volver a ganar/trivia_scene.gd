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
var opciones = ["A", "B", "C", "D"]
var opcion_correcta = "A" # Ejemplo, esta debe definirse dinámicamente por pregunta
var bonos_usados = {
	"50_50": false,
	"pista": false,
	"publico": false
}
# --- SELECCIONES TEMPORALES ---
var seleccion_temporal: int = -1
var selecciones_secundarias: Dictionary = {}  # Ej: {"0": 1, "1": -1}

# --- NODOS UI ---
@onready var continuar_button: Button = $continue
@onready var question_container: VBoxContainer = $question_container
@onready var final_results_container: VBoxContainer = $final_results_container
@onready var question_label: Label = $question_container/question_label
@onready var options_container: VBoxContainer = $options_container
@onready var result_label: Label = $question_container/result_label
@onready var secondary_questions_container: VBoxContainer = $secondary_questions_container
@onready var money_label: Label = $money_label
@onready var admob = $AdMob
@onready var ruleta_menu_container = $ruleta_menu  # Este es un contenedor donde irá el menú instanciado
var ruleta_menu_instance  # Referencia al nodo instanciado

# --- FUNCIÓN PRINCIPAL ---
func _ready() -> void:
	_configurar_ui_inicial()
	_cargar_datos_iniciales()

	# Instanciar menú de potenciadores
	var menu_scene = load("res://bonos.tscn")
	if menu_scene:
		ruleta_menu_instance = menu_scene.instantiate()
		ruleta_menu_container.add_child(ruleta_menu_instance)
		# Conectar señales de potenciadores
		ruleta_menu_instance.connect("potenciar_50_50", Callable(self, "_usar_50_50"))
		ruleta_menu_instance.connect("potenciar_pista", Callable(self, "_usar_pista"))
		ruleta_menu_instance.connect("potenciar_publico", Callable(self, "_usar_publico"))
		ruleta_menu_instance.hide()
	else:
		printerr("❌ No se pudo cargar el menú de potenciadores")

	# Verificación del plugin AdMob
	print("🔍 Iniciando verificación de plugin...")
	if Engine.has_singleton("AdMob"):
		admob = Engine.get_singleton("AdMob")
		print("✅ Plugin detectado: ", admob)
	else:
		printerr("❌ Error: Plugin no encontrado")
	print("Lista de singletons disponibles: ", Engine.get_singleton_list())


# --- CONFIGURACIÓN INICIAL ---
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


# --- CARGA Y FILTRADO DE PREGUNTAS ---
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
	for btn in options_container.get_children():
		btn.modulate = Color.WHITE if btn != button else Color.GREEN
	_verificar_selecciones()

func _on_secundaria_option_pressed(button: Button, secundaria_index: int) -> void:
	selecciones_secundarias[str(secundaria_index)] = button.get_meta("option_index")
	for sibling in button.get_parent().get_children():
		if sibling is Button:
			sibling.modulate = Color.WHITE if sibling != button else Color.GREEN
	_verificar_selecciones()


# --- VERIFICACIÓN DE COMPLECIÓN ---
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


# --- CONFIRMACIÓN DE RESPUESTA ---
func _on_continuar_pressed() -> void:
	if seleccion_temporal == -1:
		print("¡Selecciona una opción primero!")
		return

	# Pregunta principal
	var acierto_principal = (seleccion_temporal == pregunta_actual["respuesta_correcta"])
	dinero *= pregunta_actual["cuota"] if acierto_principal else 0.0
	respuestas_seleccionadas.append({
		"pregunta": pregunta_actual["pregunta"],
		"correcta": acierto_principal,
		"cuota": pregunta_actual["cuota"]
	})

	# Preguntas secundarias
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

	money_label.text = "Dinero: $%.2f" % dinero
	indice_pregunta += 1
	_cargar_pregunta()


# --- RESULTADOS FINALES ---
func _mostrar_resultados_finales() -> void:
	final_results_container.show()
	# Aquí puedes agregar un resumen de respuestas correctas e incorrectas


# --- LIMPIAR PREGUNTA ANTERIOR ---
func _limpiar_contenedores() -> void:
	for child in options_container.get_children():
		child.queue_free()
	for child in secondary_questions_container.get_children():
		child.queue_free()
	seleccion_temporal = -1
	selecciones_secundarias.clear()
	question_container.hide()
	secondary_questions_container.hide()
	continuar_button.hide()
	final_results_container.hide()


# --- FUNCIONES DE ANUNCIOS ---
func _on_rewarded_pressed():
	admob.load_rewarded_video()
	await admob.rewarded_video_loaded
	admob.show_rewarded_video()

func _on_banner_pressed():
	admob.load_banner()
	await admob.banner_loaded
	admob.show_banner()


# --- FUNCIONES DE POTENCIADORES ---
# Debes tener acceso a la pregunta actual. Vamos a asumir que está en una variable llamada pregunta_actual.

# --- FUNCIONES DE POTENCIADORES ---
func _usar_50_50(pregunta_actual):
	var correct_index = pregunta_actual["respuesta_correcta"]
	var opciones = pregunta_actual["opciones"]
	var indices_incorrectos = []

	for i in range(opciones.size()):
		if i != correct_index:
			indices_incorrectos.append(i)

	# Elegimos dos índices incorrectos al azar
	indices_incorrectos.shuffle()
	var eliminados = indices_incorrectos.slice(0, 2)

	# Creamos una nueva lista de opciones mostrando solo la correcta y una incorrecta
	var opciones_mostradas = []
	for i in range(opciones.size()):
		if i == correct_index or not eliminados.has(i):
			opciones_mostradas.append({
				"texto": opciones[i],
				"index": i
			})

	print("Usando 50/50: mostrando opciones", opciones_mostradas)
	return opciones_mostradas


func _usar_pista(pregunta_actual):
	var correcta = pregunta_actual["opciones"][pregunta_actual["respuesta_correcta"]]
	var pista = "La respuesta está relacionada con: %s" % correcta
	print("Usando pista:", pista)
	return pista


func _usar_publico(pregunta_actual):
	var opciones = pregunta_actual["opciones"]
	var cantidad_opciones = opciones.size()
	var correct_index = pregunta_actual["respuesta_correcta"]

	# Asignar una cantidad mayor al correcto (entre 50% y 70%)
	var porcentaje_correcta = randi_range(50, 70)
	var porcentajes = []

	var restante = 100 - porcentaje_correcta
	var incorrectos = []

	for i in range(cantidad_opciones):
		if i != correct_index:
			incorrectos.append(i)

	# Repartir el porcentaje restante aleatoriamente entre las otras opciones
	var suma = 0
	for i in range(incorrectos.size()):
		var valor = (restante - suma) if i == incorrectos.size() - 1 else randi_range(0, restante - suma)

		suma += valor
		porcentajes.append({
			"index": incorrectos[i],
			"porcentaje": valor
		})

	# Agregar la opción correcta
	porcentajes.append({
		"index": correct_index,
		"porcentaje": porcentaje_correcta
	})

	# Ordenar por índice para que coincida con el orden original
	porcentajes.sort_custom(func(a, b): return a["index"] < b["index"])

	print("Usando público:", porcentajes)
	return porcentajes


func _on_ruleta_menu_pressed() -> void:
	ruleta_menu_instance.visible = not ruleta_menu_instance.visible
