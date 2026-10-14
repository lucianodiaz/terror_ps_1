shader_type spatial;

render_mode specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 grid_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float grid_size = 1.0; // Size in meters
uniform float line_width = 0.05; // Width of the grid lines

varying vec3 world_pos;

void vertex() {
    // Calculate world position for meter-based grid independent of UVs
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 coord = world_pos / grid_size;
    vec3 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
    float line = min(min(grid.x, grid.y), grid.z);
    
    float weight = 1.0 - min(line * line_width, 1.0);
    
    ALBEDO = mix(base_color.rgb, grid_color.rgb, weight);
    METALLIC = 0.2;
    ROUGHNESS = 0.8;
}