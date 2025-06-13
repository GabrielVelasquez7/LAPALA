extends Node

func fade_in(node: CanvasItem, duration := 0.8):
	if node:
		node.modulate.a = 0.0
		node.show()
		node.create_tween().tween_property(node, "modulate:a", 1.0, duration)

func fade_out(node: CanvasItem, duration := 0.5):
	if node:
		var tween = node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, duration)
		tween.connect("finished", func(): node.hide())

func escalar_desde_cero(node: Node2D, duration := 0.4):
	if node:
		node.scale = Vector2(0, 0)
		node.show()
		node.create_tween().tween_property(node, "scale", Vector2(1, 1), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func rebote_control(node: Control, escala_final := Vector2(1, 1), duration := 0.4):
	if node:
		node.scale = Vector2(0.8, 0.8)
		node.show()
		node.create_tween().tween_property(node, "scale", escala_final, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
func rebote(node: Node2D, escala_final := Vector2(1, 1), duration := 0.4):
	if node:
		node.scale = Vector2(0.8, 0.8)
		node.create_tween().tween_property(node, "scale", escala_final, duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func deslizar_desde_abajo(node: Node2D, offset := 100.0, duration := 0.4):
	if node:
		var pos_inicial = node.position
		node.position.y += offset
		node.show()
		node.create_tween().tween_property(node, "position:y", pos_inicial.y, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
