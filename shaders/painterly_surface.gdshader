shader_type spatial;
render_mode depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.5, 0.4, 0.3, 1.0);
uniform float grain_scale = 8.0;
uniform float grain_strength = 0.055;
uniform float metallic_amount = 0.0;
uniform float roughness_amount = 0.88;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;

float hash_value(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash_value(i);
    float b = hash_value(i + vec2(1.0, 0.0));
    float c = hash_value(i + vec2(0.0, 1.0));
    float d = hash_value(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 paint_uv = UV * grain_scale;
    float broad = value_noise(paint_uv * 0.54);
    float fine = value_noise(paint_uv * 2.6);
    float brush = sin((UV.y * 23.0) + broad * 1.8) * 0.5 + 0.5;
    float pigment = (broad - 0.5) * 0.12 + (fine - 0.5) * 0.055 + (brush - 0.5) * 0.025;
    ALBEDO = max(base_color.rgb * (1.0 + pigment * grain_strength * 8.0), vec3(0.0));
    METALLIC = metallic_amount;
    ROUGHNESS = roughness_amount;
    SPECULAR = 0.22;
    EMISSION = emission_color.rgb * emission_strength;
}
