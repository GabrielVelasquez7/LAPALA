extends CanvasLayer

@onready var texture_rect = $TextureRect  # Ruta a tu TextureRect hijo

func cambiar_fondo_por_ano(ano_seleccionada: int) -> void:
	match ano_seleccionada:
		1998:
			texture_rect.texture = preload("res://assets/background/02_1998.png")
		2019:
			texture_rect.texture = preload("res://assets/background/01_1994.PNG")
		2022:
			texture_rect.texture = preload("res://assets/background/02_1998.png")
		
