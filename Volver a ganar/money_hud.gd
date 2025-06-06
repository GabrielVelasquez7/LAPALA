extends Control

@onready var cantidad_label: Label = $CantidadLabel

func set_money(monto: float) -> void:
	cantidad_label.text = "$%.2f" % monto
