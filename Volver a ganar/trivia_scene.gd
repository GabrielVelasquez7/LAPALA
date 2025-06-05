extends Control

# --- VARIABLES PRINCIPALES ---
var todas_las_preguntas: Array = []
var preguntas_filtradas: Array = []
var preguntas: Array = []
var pregunta_actual: Dictionary = {}
var indice_pregunta: int = 0
var anio_seleccionado: int = -1
var respuestas_seleccionadas: Array = []
var multiplicador_total: float = 1.0
var seleccion_temporal: int = -1
var selecciones_secundarias: Dictionary = {}
var dinero_guardado: float = 0.0
var esperando_recompensa: bool = false
var recompensa_otorgada: bool = false


# --- NODOS UI ---
@onready var retry_label: Label = $retry_label
@onready var rewarded: Button = $rewarded
var dinero: float = 100.0  # Dinero inicial del jugador
var opciones = ["A", "B", "C", "D"]
var opcion_correcta = "A"
var bonos_usados = {
	"50_50": false,
	"pista": false,
	"publico": false
}

# --- NODOS UI ---
@onready var continuar_button: Button = $continue
@onready var question_container: VBoxContainer = $question_container
@onready var final_results_container: VBoxContainer = $final_results_container
@onready var question_label: Label = $question_container/question_label
@onready var options_container: GridContainer = $options_container  # GridContainer con columns = 2
@onready var result_label: Label = $question_container/result_label
@onready var secondary_questions_container: VBoxContainer = $secondary_questions_container
@onready var money_label: Label = $money_label
@onready var admob = $AdMob
@onready var ruleta_menu_container = $ruleta_menu
var ruleta_menu_instance

# --- FUNCIÓN PRINCIPAL ---
func _ready() -> void:
	_configurar_ui_inicial()
	_cargar_datos_iniciales()
	rewarded.hide()
	print("🔍 Iniciando verificación de plugin...")
	if admob:
		print("✅ Nodo AdMob encontrado")
		
		# Conectar señales directamente al nodo
		if admob.has_signal("rewarded"):
			admob.rewarded.connect(_on_recompensa_recibida)
		else:
			printerr("❌ Señal 'rewarded' no encontrada en nodo AdMob")
			
		if admob.has_signal("rewarded_video_closed"):
			admob.rewarded_video_closed.connect(_on_anuncio_cerrado)
		else:
			printerr("❌ Señal 'rewarded_video_closed' no encontrada en nodo AdMob")
			
		if admob.has_signal("rewarded_video_loaded"):
			admob.rewarded_video_loaded.connect(_on_rewarded_video_loaded)
		else:
			printerr("❌ Señal 'rewarded_video_loaded' no encontrada en nodo AdMob")
	else:
		printerr("❌ Error: Nodo AdMob no encontrado en escena")

	var menu_scene = load("res://bonos.tscn")
	if menu_scene:
		ruleta_menu_instance = menu_scene.instantiate()
		ruleta_menu_container.add_child(ruleta_menu_instance)
		ruleta_menu_instance.connect("potenciar_50_50", Callable(self, "_usar_50_50"))
		ruleta_menu_instance.connect("potenciar_pista", Callable(self, "_usar_pista"))
		ruleta_menu_instance.connect("potenciar_publico", Callable(self, "_usar_publico"))
		ruleta_menu_instance.hide()
	else:
		printerr("❌ No se pudo cargar el menú de potenciadores")


# --- CONFIGURACIÓN INICIAL ---
func _configurar_ui_inicial() -> void:
	continuar_button.hide()
	continuar_button.pressed.connect(_on_continuar_pressed)
	money_label.text = "Dinero: $%.2f" % Global.dinero

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
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(150, 80)
		options_container.add_child(btn)

func _mostrar_preguntas_secundarias() -> void:
	secondary_questions_container.show()
	selecciones_secundarias.clear()
	for i in pregunta_actual["secundarias"].size():
		var secundaria = pregunta_actual["secundarias"][i]
		var box = VBoxContainer.new()
		box.set_meta("secundaria_index", i)
		box.size_flags_horizontal = Control.SIZE_FILL
		box.custom_minimum_size = Vector2(320, 0)

		var label = Label.new()
		label.text = "{0} (Cuota: x{1})".format([secundaria["pregunta"], secundaria["cuota"]])
		label.custom_minimum_size = Vector2(300, 40)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(0, 0, 0)
		label.z_index = 1


		box.add_child(label)
		for j in secundaria["opciones"].size():
			var btn = Button.new()
			btn.text = secundaria["opciones"][j]
			btn.set_meta("option_index", j)
			btn.custom_minimum_size = Vector2(200, 60)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_FILL
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

# --- CONFIRMAR APUESTA ---
func _on_continuar_pressed() -> void:
	if seleccion_temporal == -1:
		print("¡Selecciona una opción primero!")
		return
	var acierto_principal = (seleccion_temporal == pregunta_actual["respuesta_correcta"])
	Global.dinero *= pregunta_actual["cuota"] if acierto_principal else 0.0
	respuestas_seleccionadas.append({
		"pregunta": pregunta_actual["pregunta"],
		"correcta": acierto_principal,
		"cuota": pregunta_actual["cuota"]
	})
	if pregunta_actual.has("secundarias"):
		for i in pregunta_actual["secundarias"].size():
			var idx_str = str(i)
			if selecciones_secundarias.has(idx_str):
				var secundaria = pregunta_actual["secundarias"][i]
				var acierto_sec = (selecciones_secundarias[idx_str] == secundaria["respuesta_correcta"])
				Global.dinero *= secundaria["cuota"] if acierto_sec else 0.0
				respuestas_seleccionadas.append({
					"pregunta": secundaria["pregunta"],
					"correcta": acierto_sec,
					"cuota": secundaria["cuota"]
				})

	money_label.text = "Dinero: $%.2f" % Global.dinero

	if Global.dinero <= 0.0:
		dinero_guardado = 500.0  # Puedes ajustar el valor que se recupera
		_mostrar_retry_ui()
		return

	indice_pregunta += 1
	_cargar_pregunta()

# --- RESULTADOS FINALES ---
func _mostrar_resultados_finales() -> void:
	final_results_container.show()
	if Global.ano_seleccionado not in Global.anios_ganados:
		Global.anios_ganados.append(Global.ano_seleccionado)

	await get_tree().create_timer(2.0).timeout
	# Cambia directamente a la escena sin instanciar manualmente
	get_tree().change_scene_to_file("res://SeleccionarAnoScene.tscn")
	

func _mostrar_retry_ui() -> void:
	_limpiar_contenedores()
	question_container.hide()
	secondary_questions_container.hide()
	final_results_container.hide()
	
	retry_label.text = "¡Perdiste todo! ¿Otra oportunidad?"
	retry_label.custom_minimum_size = Vector2(300, 40)
	retry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_label.modulate = Color(0, 0, 0)
	retry_label.z_index = 1
	retry_label.show()
	rewarded.show()
	
func _on_recompensa_recibida(currency: String, amount: int) -> void:
	print("💰 Recompensa recibida: ", currency, " - ", amount)
	recompensa_otorgada = true
	Global.dinero = dinero_guardado
	money_label.text = "Dinero: $%.2f" % Global.dinero

func _on_anuncio_cerrado() -> void:
	print("🎬 Anuncio cerrado. Recompensa otorgada: ", recompensa_otorgada)
	
	if recompensa_otorgada:
		retry_label.hide()
		rewarded.hide()
		indice_pregunta += 1
		_cargar_pregunta()
	else:
		print("⚠️ El usuario cerró el anuncio sin completarlo")
		retry_label.text = "¡Anuncio no completado! ¿Reintentar?"
		rewarded.show()
	
	# Resetear banderas
	esperando_recompensa = false
	recompensa_otorgada = false

func _on_rewarded_video_loaded() -> void:
	print("📦 Anuncio rewarded cargado y listo")


# --- FUNCIONES DE POTENCIADORES ---
func _usar_50_50() -> void:
	if bonos_usados["50_50"]:
		return
	bonos_usados["50_50"] = true
	var correct_index = pregunta_actual["respuesta_correcta"]
	var indices_incorrectos = []
	for i in range(pregunta_actual["opciones"].size()):
		if i != correct_index:
			indices_incorrectos.append(i)
	indices_incorrectos.shuffle()
	var eliminados = indices_incorrectos.slice(0, 2)
	for btn in options_container.get_children():
		var index = btn.get_meta("option_index")
		if eliminados.has(index):
			btn.hide()
	print("✅ Bono 50/50 activado")

func _usar_pista() -> void:
	if bonos_usados["pista"]:
		return
	bonos_usados["pista"] = true
	var correcta = pregunta_actual["opciones"][pregunta_actual["respuesta_correcta"]]
	var pista = "💡 Pista: la respuesta está relacionada con: %s" % correcta
	result_label.text = pista
	result_label.show()
	print("✅ Bono pista activado")

func _usar_publico() -> void:
	if bonos_usados["publico"]:
		return
	bonos_usados["publico"] = true
	var cantidad_opciones = pregunta_actual["opciones"].size()
	var correct_index = pregunta_actual["respuesta_correcta"]
	var porcentaje_correcta = randi_range(50, 70)
	var restante = 100 - porcentaje_correcta
	var incorrectos = []
	var porcentajes = []
	for i in range(cantidad_opciones):
		if i != correct_index:
			incorrectos.append(i)
	var suma = 0
	for i in range(incorrectos.size()):
		var valor = (restante - suma) if i == incorrectos.size() - 1 else randi_range(0, restante - suma)
		suma += valor
		porcentajes.append("Opción %s: %d%%" % [opciones[incorrectos[i]], valor])
	porcentajes.append("Opción %s: %d%% ✅" % [opciones[correct_index], porcentaje_correcta])
	result_label.text = "📊 Resultado del público:\n" + "\n".join(porcentajes)
	result_label.show()
	print("✅ Bono público activado")

# --- FUNCIONES DE ANUNCIOS ---
func _on_rewarded_pressed():
	if esperando_recompensa:
		print("⏳ Ya se está esperando una recompensa...")
		return
	
	print("▶️ Iniciando flujo de anuncio rewarded")
	esperando_recompensa = true
	recompensa_otorgada = false
	
	# Cargar y mostrar el anuncio con manejo de errores
	admob.load_rewarded_video()
	
	# Esperar a que el anuncio se cargue con timeout
	var tiempo_espera = 10.0  # segundos
	var tiempo_inicio = Time.get_ticks_msec()
	
	while not admob.is_rewarded_video_loaded() and (Time.get_ticks_msec() - tiempo_inicio) < tiempo_espera * 1000:
		print("⏳ Esperando carga del anuncio...")
		await get_tree().create_timer(0.5).timeout
	
	if admob.is_rewarded_video_loaded():
		print("📺 Mostrando anuncio rewarded")
		admob.show_rewarded_video()
	else:
		printerr("❌ Tiempo de espera agotado para cargar el anuncio")
		esperando_recompensa = false
		retry_label.text = "Error al cargar anuncio. ¿Reintentar?"
		rewarded.show()

func _on_banner_pressed():
	admob.load_banner()
	await admob.banner_loaded
	admob.show_banner()

# --- ABRIR MENÚ DE BONOS ---
func _on_ruleta_menu_pressed() -> void:
	ruleta_menu_instance.visible = not ruleta_menu_instance.visible
