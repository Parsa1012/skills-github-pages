extends Control
## راه‌انداز سبک و آفلاین فاز ۱ (بدون نیاز به اینترنت).

const TRANSITION_DELAY_SEC: float = 0.35

var _elapsed: float = 0.0
var _transitioned: bool = false


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	GameManager.apply_performance_settings()


func _process(delta: float) -> void:
	if _transitioned:
		return
	_elapsed += delta
	if _elapsed >= TRANSITION_DELAY_SEC:
		_transitioned = true
		GameManager.go_to_main_menu()
