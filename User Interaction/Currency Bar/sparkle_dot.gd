@tool
extends TextureRect

@export_range(4, 128, 1) var texture_size: int = 32:
	set(value):
		texture_size = max(value, 4)
		_update_texture()

@export_range(0.01, 0.45, 0.01) var core_radius: float = 0.16:
	set(value):
		core_radius = clamp(value, 0.01, 0.45)
		_update_texture()

@export_range(0.05, 1.0, 0.01) var glow_radius: float = 0.48:
	set(value):
		glow_radius = clamp(value, core_radius + 0.01, 1.0)
		_update_texture()

@export var core_color: Color = Color("#F4FFD7"):
	set(value):
		core_color = value
		_update_texture()

@export var glow_color: Color = Color("#9FFF8D"):
	set(value):
		glow_color = value
		_update_texture()


func _ready() -> void:
	_update_texture()


func _update_texture() -> void:
	if texture_size <= 0:
		return

	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var center := Vector2(texture_size * 0.5, texture_size * 0.5)
	var max_distance := texture_size * 0.5

	for y in range(texture_size):
		for x in range(texture_size):
			var pos := Vector2(x, y)
			var distance := pos.distance_to(center) / max_distance

			var color := Color.TRANSPARENT

			if distance <= core_radius:
				color = core_color
			elif distance <= glow_radius:
				var t := inverse_lerp(core_radius, glow_radius, distance)
				color = glow_color
				color.a = lerp(0.75, 0.0, t)

			image.set_pixel(x, y, color)

	var image_texture := ImageTexture.create_from_image(image)
	texture = image_texture

	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
