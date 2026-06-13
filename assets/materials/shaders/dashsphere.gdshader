shader_type spatial;
render_mode blend_add, cull_back, unshaded, depth_draw_never;

uniform vec4  color          : source_color  = vec4(0.3, 0.7, 1.0, 1.0);
uniform float brightness     : hint_range(0.0, 90.0)  = 5.0;
uniform float band_offset    : hint_range(-1.0, 1.0)  = -0.438;
uniform float band_sharpness : hint_range(0.1, 12.0)  = 1.971;
uniform float edge_softness  : hint_range(0.1, 64.0)  = 12.073;

uniform vec3  tail_direction  = vec3(0.0, 0.0, -1.0);
uniform float tail_length    : hint_range(0.0, 4.0)   = 1.8;
// tail_fade_start: how far along the tail the fade begins (0=equator, 1=tip)
// tail_fade_end:   where it reaches fully transparent (should be >= start)
uniform float tail_fade_start : hint_range(0.0, 1.0)  = 0.3;
uniform float tail_fade_end   : hint_range(0.0, 2.0)  = 1.0;

uniform float flutter_amount : hint_range(0.0, 0.05)  = 0.007;
uniform float flutter_speed  : hint_range(0.0, 120.0) = 90.0;

varying float v_tail_dist; // pre-deform dot product along tail axis, 0=equator 1=back pole

void vertex() {
	// Store pre-deform distance along tail axis (0 at equator, 1 at back pole)
	// Normalized so tail_fade values are intuitive regardless of sphere size
	v_tail_dist = dot(normalize(VERTEX), tail_direction);

	float flutter = sin(TIME * flutter_speed) * flutter_amount;
	VERTEX += NORMAL * flutter;

	float facing = max(0.0, dot(NORMAL, tail_direction));
	VERTEX += tail_direction * (facing * facing) * tail_length;
}

void fragment() {
	float NdotV   = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float shifted = clamp(NdotV - band_offset, 0.0, 1.0);
	float rim     = pow(1.0 - shifted, band_sharpness);
	float cent    = pow(shifted, edge_softness);

	// Fade alpha to zero toward the tail tip
	// 1.0 where v_tail_dist < tail_fade_start, 0.0 where > tail_fade_end
	float tail_fade = 1.0 - smoothstep(tail_fade_start, tail_fade_end, v_tail_dist);

	ALBEDO = color.rgb * brightness;
	ALPHA  = rim * cent * tail_fade * color.a;
}
