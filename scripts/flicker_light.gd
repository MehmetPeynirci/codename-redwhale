extends OmniLight3D

@export var base_energy: float = 0.95
@export var flicker_amount: float = 0.75
@export var flicker_speed: float = 13.0
@export var pulse_chance: float = 0.08

var _time_accum: float = 0.0

func _process(delta: float) -> void:
	_time_accum += delta
	var noise_component: float = sin(_time_accum * flicker_speed) * 0.5 + 0.5
	var random_drop: float = randf() if randf() < pulse_chance * delta * 30.0 else 1.0
	light_energy = maxf(0.08, base_energy - flicker_amount * noise_component * random_drop)
