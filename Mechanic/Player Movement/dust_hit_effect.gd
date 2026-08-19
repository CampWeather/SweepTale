extends CanvasLayer

@onready var effect_rect: ColorRect = $ColorRect
@onready var effect_material: ShaderMaterial = effect_rect.material as ShaderMaterial

@onready var smog_rect: ColorRect = $SmogRect
@onready var smog_material: ShaderMaterial = smog_rect.material as ShaderMaterial

var tween: Tween

func _ready() -> void:
	add_to_group("screen_effect") # Group agar mudah ditemukan oleh SmogArea
	
	# Biar kedua kotak tidak menghalangi klik mouse (jika ada tombol UI)
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	smog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_set_effect(0.0, 0.0, 0.0)
	
	# Reset shader smog awal ke kotak kabut (SmogRect)
	if smog_material:
		smog_material.set_shader_parameter("smog_density", 0.0)
		smog_material.set_shader_parameter("player_depth", 0.0)
		
	effect_rect.visible = false # Matikan debu di awal
	smog_rect.visible = true  # Nyalakan kanvas kabut

# --- FUNGSI BARU UNTUK KABUT HITAM (SMOG) ---
func update_smog_effect(smog_density: float, player_depth: float) -> void:
	if smog_material == null:
		return
		
	# Kirim nilainya langsung ke shader SmogRect
	smog_material.set_shader_parameter("smog_density", smog_density)
	smog_material.set_shader_parameter("player_depth", player_depth)

# --- FUNGSI EFEK DEBU LAMA ---
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
	effect_rect.visible = false # Simpel, langsung sembunyikan kotak debunya saja
