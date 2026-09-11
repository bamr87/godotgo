// Pulsing emissive material for collectible orbs.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.25, 0.85, 1.0);
uniform float pulse_speed = 3.0;
uniform float emission_strength = 1.5;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	ALBEDO = base_color;
	EMISSION = base_color * emission_strength * (0.6 + 0.8 * pulse);
	METALLIC = 0.2;
	ROUGHNESS = 0.3;
}
