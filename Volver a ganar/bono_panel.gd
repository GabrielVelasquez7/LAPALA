extends Panel

@onready var label = $bono_result_label
@onready var cerrar_boton = $cerrar
var auto_hide_timer = null

func _ready():
	cerrar_boton.connect("pressed", Callable(self, "_on_cerrar_boton_pressed"))

func mostrar_mensaje(mensaje: String):
	label.text = mensaje
	visible = true

	if auto_hide_timer:
		auto_hide_timer.stop()
		auto_hide_timer.queue_free()

	auto_hide_timer = Timer.new()
	auto_hide_timer.one_shot = true
	auto_hide_timer.wait_time = 10
	auto_hide_timer.connect("timeout", Callable(self, "_on_cerrar_boton_pressed"))
	add_child(auto_hide_timer)
	auto_hide_timer.start()

func _on_cerrar_boton_pressed():
	visible = false
