shader_type spatial;
render_mode unshaded, depth_draw_always, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Merah tebal (seperti di contoh)
uniform float outline_thickness = 1.0;

void vertex() {
	// Memperluas simpul model ke luar berdasarkan normal simpul
	vec3 outline_direction = NORMAL;
	VERTEX += outline_direction * outline_thickness * 0.01;
}

void fragment() {
	// Render outline sebagai warna solid
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}