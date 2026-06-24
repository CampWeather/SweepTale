shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 5.0) = 0.0;
uniform float gray_strength : hint_range(0.0, 1.0) = 0.0;
uniform float dust_tint_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 screen_col = textureLod(screen_texture, SCREEN_UV, blur_strength);

	float gray = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray_col = vec3(gray);

	vec3 final_col = mix(screen_col.rgb, gray_col, gray_strength);
	final_col = mix(final_col, vec3(0.55, 0.55, 0.55), dust_tint_strength);

	COLOR = vec4(final_col, 1.0);
}
