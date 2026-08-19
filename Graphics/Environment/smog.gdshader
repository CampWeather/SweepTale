shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float smog_density : hint_range(0.0, 1.0) = 0.0; // Ini = Sifat Kabut (Sampah)
uniform float player_depth : hint_range(0.0, 1.0) = 0.0; // Ini = Sifat Layar (Kedalaman)
uniform vec4 smog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); 

void fragment() {
    vec4 screen_color = texture(screen_texture, SCREEN_UV);
    
    // Langsung kalikan saja! Semakin banyak sampah & semakin dalam player, makin hitam.
    // Hapus angka * 1.5, dan ubah batas maksimal 1.0 menjadi 0.85
	float total_darkness = clamp(smog_density * player_depth, 0.0, 0.85);
    // Campur warna asli layar dengan warna hitam secara merata (1 layar penuh)
    vec3 final_color = mix(screen_color.rgb, smog_color.rgb, total_darkness);
    
    COLOR = vec4(final_color, 1.0);
}