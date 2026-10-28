shader_type canvas_item;

// Scene transition: a disc that grows from `center` until it covers the screen. Full-screen
// ColorRect, tween `progress` from 0 to 1. With `aspect` at 0 the circle stays round
// on any screen size.
group_uniforms Transition;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 cover_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms Shape;
uniform vec2 center = vec2(0.5, 0.5);
uniform float softness : hint_range(0.0, 0.3) = 0.03;
// 0 = auto-fit the screen shape (keeps circles/tiles proportional); or set width/height
uniform float aspect : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	// the ColorRect colour and modulate: tint or fade the effect from the node
	vec4 node_tint = COLOR;
	float asp = aspect > 0.0 ? aspect : (fwidth(UV.y) / max(fwidth(UV.x), 1e-5));
	vec2 d = UV - center;
	d.x *= asp;
	float dist = length(d);
	// the radius runs to just past the farthest corner, so 1 always covers everything
	float max_d = length(vec2(max(center.x, 1.0 - center.x) * asp, max(center.y, 1.0 - center.y)));
	// at least one pixel of softness: 0 would turn the edge around (and alias)
	float s = max(softness, fwidth(dist));
	float r = mix(-s, max_d + s, progress);
	float mask = smoothstep(r + s, r - s, dist);
	COLOR = vec4(cover_color.rgb, mask * cover_color.a);
	COLOR *= node_tint;
}