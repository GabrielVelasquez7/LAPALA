extends Node

# Configuración de sonidos
var sounds = {
	"click": preload("res://assets/Sounds/Interface Click 1_1.wav"),
	"win": preload("res://assets/Sounds/Cash Register 1_1.wav"),
	"lose": preload("res://assets/Sounds/Negative 2_1.wav")
}

var audio_players := []

func _ready():
	# Crear pool de AudioStreamPlayers
	for i in 3:
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)

func play(sound_name: String, pitch_variation: bool = true):
	if not sounds.has(sound_name):
		push_error("Sonido no encontrado: " + sound_name)
		return
	
	var available_player = _get_available_player()
	if available_player:
		available_player.stream = sounds[sound_name]
		if pitch_variation:
			available_player.pitch_scale = randf_range(0.95, 1.05)
		available_player.play()

func _get_available_player():
	for player in audio_players:
		if not player.playing:
			return player
	# Si todos están en uso, crea uno nuevo
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)
	audio_players.append(new_player)
	return new_player
