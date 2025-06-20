extends Control

signal potenciar_50_50
signal potenciar_publico
signal potenciar_pista
signal exit

func _on_button_50_pressed():
	emit_signal("potenciar_50_50")


func _on_boton_pista_pressed():
	emit_signal("potenciar_pista")


func _on_boton_publico_pressed():
	emit_signal("potenciar_publico")


func _on_exit_pressed():
	emit_signal("exit")
