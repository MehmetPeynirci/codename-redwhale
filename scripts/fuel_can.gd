extends Area3D

@export var rotate_speed: float = 1.1
@export var bob_height: float = 0.09
@export var bob_speed: float = 1.6

var _base_position: Vector3 = Vector3.ZERO
var _time: float = 0.0

func _ready() -> void:
	_base_position = global_position
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	rotate_y(rotate_speed * delta)
	global_position = Vector3(
		_base_position.x,
		_base_position.y + sin(_time * bob_speed) * bob_height,
		_base_position.z
	)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_has_fuel"):
		body.call("set_has_fuel", true)
		queue_free()
