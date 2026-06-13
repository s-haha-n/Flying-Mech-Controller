# hud.gd — attach to CanvasLayer or HealthBarFrame
extends CanvasLayer

var _tween: Tween
@onready var _bar: ProgressBar = $HealthBarFrame/ProgressBar
var _health_component: Node

func _ready() -> void:
	# Wait a frame so Player is fully ready
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	_health_component = player.get_node("HealthComponent")
	_health_component.health_changed.connect(_on_health_changed)
	# Init bar
	_bar.max_value = _health_component.max_health
	_bar.value = _health_component.current_health

func _on_health_changed(current: int, maximum: int) -> void:
	_bar.value = current
	# Flash bar red then back
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_bar.modulate = Color.RED
	_tween.tween_property(_bar, "modulate", Color.WHITE, 0.4)
