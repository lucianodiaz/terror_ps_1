shader_type spatial;
render_mode unshaded, cull_disabled;

// Old CRT showing a flat color with static, scanlines and a rolling bar

uniform vec4 screen_color : source_color = vec4(0.22, 0.85, 0.28, 1.0);
uniform float brightness = 1.3;
uniform float static_amount : hint_range(0.0, 1.0) = 0.25;
uniform vec2 static_resolution = vec2(160.0, 120.0);
uniform float static_fps = 24.0;
uniform float scanline_count = 90.0;
uniform float roll_speed = 0.12;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float noise = hash(floor(uv * static_resolution) + floor(TIME * static_fps));
	float scanline = 0.85 + 0.15 * sin(uv.y * scanline_count * 6.2831);
	float roll = 1.0 + 0.3 * smoothstep(0.08, 0.0, abs(fract(uv.y + TIME * roll_speed) - 0.5));
	vec2 centered = uv - 0.5;
	float vignette = clamp(1.0 - dot(centered, centered) * 1.8, 0.0, 1.0);
	vec3 color = mix(screen_color.rgb, vec3(noise), static_amount);
	ALBEDO = color * scanline * roll * vignette * brightness;
}
