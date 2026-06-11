shader_type spatial;
// cull_front menyembunyikan bagian depan objek, unshaded membuatnya tidak terpengaruh cahaya
render_mode cull_front, unshaded;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_thickness : hint_range(0.0, 1.0) = 0.05;

void vertex() {
	// Mendorong posisi vertex keluar searah dengan normal (arah hadapnya)
	VERTEX += NORMAL * outline_thickness;
}

void fragment() {
	// Menerapkan warna outline
	ALBEDO = outline_color.rgb;
}