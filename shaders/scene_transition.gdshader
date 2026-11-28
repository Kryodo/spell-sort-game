shader_type canvas_item;

uniform float aperture_radius : hint_range(0.0, 1.1) = 1.04;
uniform vec2 aperture_center = vec2(0.5, 0.5);
uniform float screen_aspect = 0.5625;
uniform float corner_radius = 0.637;
uniform vec4 veil_color : source_color = vec4(0.012, 0.020, 0.017, 1.0);

void fragment() {
	vec2 delta = (UV - aperture_center) * vec2(screen_aspect, 1.0);
	float distance_from_focus = length(delta) / max(corner_radius, 0.001);

	// The scene remains visible inside the aperture; a soft edge and etched
	// brass ticks ride its boundary as it closes and opens.
	float cover = smoothstep(
		aperture_radius - 0.006,
		aperture_radius + 0.006,
		distance_from_focus
	);
	float ring_distance = abs(distance_from_focus - aperture_radius);
	float ring = 1.0 - smoothstep(0.003, 0.020, ring_distance);

	float angle = atan(delta.y, delta.x);
	float tick_sector = 0.5235988;
	float tick_angle = mod(angle + tick_sector * 0.5, tick_sector) - tick_sector * 0.5;
	float tick = 1.0 - smoothstep(0.010, 0.026, abs(tick_angle));
	float ring_strength = ring * (0.14 + 0.34 * tick);

	vec3 brass = vec3(0.68, 0.51, 0.29);
	vec3 color = mix(veil_color.rgb, brass, ring_strength * 0.52);
	float alpha = max(cover, ring * (0.16 + 0.34 * tick));

	// At the fully closed point, cover every pixel with the veil.
	if (aperture_radius <= 0.001) {
		alpha = 1.0;
	}

	COLOR = vec4(color, alpha);
}
