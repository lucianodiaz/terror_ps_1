shader_type spatial;
render_mode blend_add, depth_draw_always, cull_disabled, unshaded;

uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 0.8, 1.0);
uniform float thickness : hint_range(0.01, 0.2) = 0.05;
uniform float brightness : hint_range(0.1, 2.0) = 0.5;

void vertex() {
    // Hace que el objeto 3D siempre mire a la cámara (Efecto Billboard)
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0],
        INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[1],
        MODEL_MATRIX[3]
    );
}

void fragment() {
	vec2 uv = UV - 0.5;

	float beam_x = thickness / abs(uv.x);
	float beam_y = thickness / abs(uv.y);

	float dist = length(uv);
	float sparkle = (beam_x + beam_y) * (brightness * (1.0 - dist * 2.0));

	sparkle = max(sparkle, 0.0);
	sparkle *= step(dist, 0.5);

	ALBEDO = sparkle_color.rgb;
	EMISSION = sparkle_color.rgb * sparkle * 2.0;
	ALPHA = sparkle * sparkle_color.a;
}
