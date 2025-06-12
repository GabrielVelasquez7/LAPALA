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
var money_display_scene = preload("res://money_display.tscn")
var money_display: Control
var timer_pregunta: Timer
var tiempo_limite: float = 20.0  # 30 segundos por defecto, ajústalo según necesites
var tiempo_restante: float = 0.0
var min_time_for_sound := 15.0
var tiempo_total_inicial: float = 30.0  # Ajusta según tu timer
var pitch_inicial: float = 0.03  # Velocidad más lenta al inicio
var pitch_final: float = 1.1   # Velocidad máxima al final


# --- NODOS UI ---
@onready var retry_label: Label = $retry_label
@onready var rewarded: TextureButton = $rewarded
var dinero: float = 100.0  # Dinero inicial del jugador
var opciones = ["A", "B", "C", "D"]
var opcion_correcta = "A"
var bonos_usados = {
	"50_50": false,
	"pista": false,
	"publico": false
}

# --- NODOS UI ---
@onready var label_style: Label = $LabelStyleTemplate
@onready var continuar_button: TextureButton = $continue
@onready var question_container: VBoxContainer = $question_container
@onready var final_results_container: VBoxContainer = $final_results_container
@onready var question_label: Label = $question_container/question_label
@onready var options_container: GridContainer = $options_container  # GridContainer con columns = 2
@onready var result_label: Label = $question_container/result_label
@onready var secondary_questions_container: VBoxContainer = $secondary_questions_container
@onready var money_display_container: Control = $money_display_container
@onready var admob = $AdMob
@onready var ruleta_menu_container = $ruleta_menu
@onready var opcion_label_1: Label = $options_container/option_1/optionlabel1
@onready var opcion_label_2: Label = $options_container/option_2/optionlabel2
@onready var opcion_label_3: Label = $options_container/option_3/optionlabel3
@onready var opcion_label_4: Label = $options_container/option_4/optionlabel4
@onready var timer_sound: AudioStreamPlayer = $TimerSound
@onready var timer_label: Label = $TimerContainer/TimerLabel
var ruleta_menu_instance
var money_display_instance: Control



# --- FUNCIÓN PRINCIPAL ---
func _ready() -> void:
	timer_pregunta = Timer.new()
	add_child(timer_pregunta)
	timer_pregunta.timeout.connect(_on_tiempo_agotado)
	timer_pregunta.one_shot = true
	
	_configurar_ui_inicial()
	_cargar_datos_iniciales()
	rewarded.hide()
	$CanvasLayer.cambiar_fondo_por_ano(anio_seleccionado)

	
	
	print("🔍 Iniciando verificación de plugin...")

	if admob:
		print("✅ Nodo AdMob encontrado")
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
		

	var money_scene = load("res://money_display.tscn")
	if money_scene:
		money_display_instance = money_scene.instantiate()
		money_display_container.add_child(money_display_instance)
		money_display_instance.set_money(Global.dinero)

	else:
		printerr("❌ No se pudo cargar la escena del display de dinero")


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
	tiempo_restante = tiempo_limite
	timer_pregunta.start(tiempo_limite)
	_actualizar_ui_timer()  # Actualiza la UI del time
	pregunta_actual = preguntas[indice_pregunta]
	_mostrar_pregunta_principal()
	if pregunta_actual.has("secundarias"):
		_mostrar_preguntas_secundarias()
		
func _actualizar_ui_timer():
	# Mostrar número entero
	timer_label.text = str(int(tiempo_restante))
	
	# 1. Sonido continuo con aceleración progresiva
	var progreso = 1.0 - (tiempo_restante / tiempo_total_inicial)
	timer_sound.pitch_scale = pitch_inicial + (pitch_final - pitch_inicial) * progreso
	
	if not timer_sound.playing:
		timer_sound.play()
	
	# 2. Parpadeo rojo (últimos 3 segundos)
	if tiempo_restante <= 3.0:
		timer_label.modulate = Color.RED.lerp(Color.WHITE, fmod(tiempo_restante, 0.5))
	else:
		timer_label.modulate = Color.WHITE
		
func _on_tiempo_agotado():
	Sound_master.play("lose")  # Añade este sonido a tu sistema de sonidos
	Global.dinero = 0.0  # Pierdes todo el dinero por tiempo
	dinero_guardado = 500.0  # Reset al valor inicial
	_mostrar_retry_ui()

func _mostrar_pregunta_principal() -> void:
	question_container.show()
	question_label.text = "{0} (Cuota: x{1})".format([
		pregunta_actual["pregunta"], pregunta_actual["cuota"]
	])
	
	# Limpiar solo los botones anteriores
	for child in options_container.get_children():
		if child is TextureButton:
			child.queue_free()
	
	for i in pregunta_actual["opciones"].size():
		var btn = TextureButton.new()
		
		# Configuración del botón (igual que antes)
		btn.name = "Opcion_%d" % i
		btn.set_meta("option_index", i)
		btn.pressed.connect(_on_option_pressed.bind(btn))
		btn.custom_minimum_size = Vector2(150, 80)
		btn.texture_normal = load("res://assets/MobileGameUI/Silver-Gold_Pack/LongButtons/LongButton_White.png")
		btn.texture_pressed = load("res://assets/MobileGameUI/Silver-Gold_Pack/LongButtons/LongButton_White_Pressed.png")
		btn.stretch_mode = TextureButton.STRETCH_SCALE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		# Crear NUEVO Label pero copiando el estilo de la plantilla
		var new_label = Label.new()
		
		# 1. CONFIGURACIÓN MANUAL OBLIGATORIA
		new_label.position.y += 25
		new_label.name = "OptionLabel_%d" % i
		new_label.text = pregunta_actual["opciones"][i]
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # Valor 1 para centro
		new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER      # Valor 1 para centro
		
		# 2. PROPIEDADES DE TAMAÑO (CRÍTICAS)
		new_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		new_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		new_label.anchor_right = 2.0
		new_label.anchor_bottom = 1.0

		new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# 3. ESTILO VISUAL FORZADO (eliminar después de debug)
		var debug_style = StyleBoxFlat.new()
		debug_style.bg_color = Color(0.8, 0.8, 0.8, 0.5)  # Fondo gris semitransparente
		new_label.add_theme_stylebox_override("normal", debug_style)
		
		# 4. FUENTE Y TEXTO (configuración manual)
		var font = FontFile.new()
		font.font_data = load("res://Fonts/Pixellari.ttf")  # Cambia por tu fuente

		
		new_label.add_theme_font_override("font", font)
		new_label.add_theme_font_size_override("font_size", 24)
		new_label.add_theme_color_override("font_color", Color.BLACK)
		
		# 5. AÑADIR AL BOTÓN
		btn.add_child(new_label)
		
		# Debug adicional
		print("✅ Label creado - Texto: ", new_label.text)
		print("   - Tamaño: ", new_label.size)
		print("   - Posición: ", new_label.position)
		print("   - Alineación: ", new_label.horizontal_alignment, ", ", new_label.vertical_alignment)
		
		options_container.add_child(btn)
		
		# Forzar actualización
		new_label.reset_size()
		
func _process(delta):
	if timer_pregunta and timer_pregunta.time_left > 0:
		tiempo_restante = timer_pregunta.time_left

		_actualizar_ui_timer()

func _mostrar_preguntas_secundarias() -> void:
	secondary_questions_container.show()
	selecciones_secundarias.clear()

	var button_style = preload("res://assets/MobileGameUI/Silver-Gold_Pack/LongButtons/LongButton_White.png")
	var button_pressed_style = preload("res://assets/MobileGameUI/Silver-Gold_Pack/LongButtons/LongButton_White_Pressed.png")
	var label_font = load("res://Fonts/Pixellari.ttf")

	for i in pregunta_actual["secundarias"].size():
		var secundaria = pregunta_actual["secundarias"][i]

		var box = VBoxContainer.new()
		box.set_meta("secundaria_index", i)
		box.size_flags_horizontal = Control.SIZE_FILL
		box.custom_minimum_size = Vector2(320, 0)
		box.add_theme_constant_override("separation", 5)

		# Label de la pregunta
		var label = Label.new()
		label.text = "{0} (Cuota: x{1})".format([secundaria["pregunta"], secundaria["cuota"]])
		label.custom_minimum_size = Vector2(300, 40)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(0, 0, 0)
		label.z_index = 1
		label.add_theme_font_override("font", label_font)
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		box.add_child(label)

		# HBox para botones
		var botones_container = HBoxContainer.new()
		botones_container.alignment = BoxContainer.ALIGNMENT_CENTER
		botones_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botones_container.add_theme_constant_override("separation", 8)

		for j in secundaria["opciones"].size():
			var btn = TextureButton.new()
			btn.name = "Secundaria_%d_Opcion_%d" % [i, j]
			btn.set_meta("option_index", j)
			btn.set_meta("secundaria_index", i)  # Añadimos el índice de la pregunta secundaria
			btn.custom_minimum_size = Vector2(130, 60)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.texture_normal = button_style
			btn.texture_pressed = button_pressed_style
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			
			# Conectamos la señal pressed
			btn.pressed.connect(_on_secundaria_option_pressed.bind(btn, i))  # Pasamos el botón y el índice

			var btn_label = Label.new()
			btn_label.text = secundaria["opciones"][j]
			btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			
			btn_label.position.y += 15
			btn_label.position.x += 135
			btn_label.add_theme_font_override("font", label_font)
			btn_label.add_theme_font_size_override("font_size", 28)
			btn_label.add_theme_color_override("font_color", Color(0, 0, 0))

			btn.add_child(btn_label)
			botones_container.add_child(btn)

		box.add_child(botones_container)
		secondary_questions_container.add_child(box)


# --- MANEJO DE SELECCIONES ---
func _on_option_pressed(button: TextureButton) -> void:  # ¡Cambiado a TextureButton!
	Sound_master.play("click")
	seleccion_temporal = button.get_meta("option_index")
	for btn in options_container.get_children():
		if btn is TextureButton:
			btn.modulate = Color.WHITE if btn != button else Color.GREEN
			_verificar_selecciones()

func _on_secundaria_option_pressed(button: TextureButton, secundaria_index: int) -> void:
	Sound_master.play("click")
	
	# Guardamos la selección
	var option_index = button.get_meta("option_index")
	selecciones_secundarias[str(secundaria_index)] = option_index
	
	# Resaltamos el botón seleccionado y desmarcamos los otros
	var parent_container = button.get_parent()
	for child in parent_container.get_children():
		if child is TextureButton:
			child.modulate = Color.WHITE if child != button else Color.GREEN
	
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
		Sound_master.play("error")  # Sonido para selección inválida
		print("¡Selecciona una opción primero!")
		return
	
	var todas_correctas := true  # Bandera para resultado global
	var acierto_principal = (seleccion_temporal == pregunta_actual["respuesta_correcta"])
	todas_correctas = todas_correctas and acierto_principal  # Actualiza bandera
	
	Global.dinero *= pregunta_actual["cuota"] if acierto_principal else 0.0
	
	respuestas_seleccionadas.append({
		"pregunta": pregunta_actual["pregunta"],
		"correcta": acierto_principal,
		"cuota": pregunta_actual["cuota"]
	})
	
	# Verificar respuestas secundarias
	if pregunta_actual.has("secundarias"):
		for i in pregunta_actual["secundarias"].size():
			var idx_str = str(i)
			if selecciones_secundarias.has(idx_str):
				var secundaria = pregunta_actual["secundarias"][i]
				var acierto_sec = (selecciones_secundarias[idx_str] == secundaria["respuesta_correcta"])
				todas_correctas = todas_correctas and acierto_sec  # Actualiza bandera
				Global.dinero *= secundaria["cuota"] if acierto_sec else 0.0
				respuestas_seleccionadas.append({
					"pregunta": secundaria["pregunta"],
					"correcta": acierto_sec,
					"cuota": secundaria["cuota"]
				})
	
	# Sonido único basado en el resultado global
	if todas_correctas:
		Sound_master.play("win")
	else:
		Sound_master.play("lose")
	
	# Actualización de UI
	if money_display_instance:
		money_display_instance.set_money(Global.dinero)
	else:
		printerr("⚠️ No se ha cargado money_display_instance")
	
	# Manejo de derrota total
	if Global.dinero <= 0.0:
		dinero_guardado = 500.0 
		Sound_master.play("game_over")  # Sonido especial de fin de juego
		_mostrar_retry_ui()
		return
	
	# Avanzar a siguiente pregunta
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
	if money_display_instance:
		money_display_instance.set_money(Global.dinero)
	else:
		printerr("⚠️ No se ha cargado money_display_instance")


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
