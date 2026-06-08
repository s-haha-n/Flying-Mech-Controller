shader_type spatial;
render_mode blend_add, cull_front, unshaded, depth_draw_never;

uniform float alpha : hint_range(0.0, 1.0) = 0.3;
uniform vec4 rim_color : source_color = vec4(0.4, 0.85, 1.0, 1.0);
uniform float power = 1.0;
uniform float rim = 2.5;

void fragment() {
    // Fresnel/rim effect — opaque at edges, transparent at center
    float fresnel = pow(power - abs(dot(NORMAL, VIEW)), rim);
    ALBEDO = rim_color.rgb;
    ALPHA = fresnel * alpha;
}