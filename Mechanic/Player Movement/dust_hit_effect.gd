extends CanvasLayer

@onready var effect_rect: ColorRect = $ColorRect
@onready var effect_material: ShaderMaterial = effect_rect.material as ShaderMaterial

var tween: Tween

func _ready() -> void:
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_effect(0.0, 0.0, 0.0)
	effect_rect.visible = false

func play_dust_hit_effect() -> void:
	if tween:
		tween.kill()

	effect_rect.visible = true
	_set_effect(2.2, 0.75, 0.18)

	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(_animate_effect, 1.0, 0.0, 0.8)
	tween.tween_callback(_hide_effect)

func _animate_effect(strength: float) -> void:
	var blur = lerp(0.0, 2.2, strength)
	var gray = lerp(0.0, 0.75, strength)
	var tint = lerp(0.0, 0.18, strength)
	_set_effect(blur, gray, tint)

func _set_effect(blur: float, gray: float, tint: float) -> void:
	if effect_material == null:
		return

	effect_material.set_shader_parameter("blur_strength", blur)
	effect_material.set_shader_parameter("gray_strength", gray)
	effect_material.set_shader_parameter("dust_tint_strength", tint)

func _hide_effect() -> void:
	effect_rect.visible = false
