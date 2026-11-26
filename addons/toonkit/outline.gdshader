shader_type spatial;
// The drawn line: the mesh again, inside out and a little bigger, in ink. Its width is in pixels at any distance, thinner
// far away so small things do not turn black.
render_mode cull_front, unshaded, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.17, 0.09, 0.20, 1.0);
uniform float width = 3.0;
uniform float max_world = 0.030;
// Set by Toon.batch, which packs surfaces together: the ink comes from each vertex's colour, as Toon.material makes it
// from the albedo (in sRGB), and the width from each vertex too (CUSTOM1.w; 0: no line there).
uniform bool packed = false;

vec3 linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

vec3 srgb(vec3 c) {
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = normalize((PROJECTION_MATRIX * vec4(n, 0.0)).xy + vec2(1e-5));
	float w = packed ? CUSTOM1.w : width;
	vec2 px = dir * w * 2.0 / VIEWPORT_SIZE * (VIEWPORT_SIZE.y / 1080.0);
	float limit = max_world * abs(PROJECTION_MATRIX[1][1]) / clip.w;
	px *= smoothstep(0.04, 0.40, length(n.xy));                  // no specks where the surface faces the camera
	px *= min(1.0, limit / max(length(px * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)), 1e-5));
	clip.xy += px * clip.w;
	POSITION = w > 0.0 ? clip : vec4(2.0, 2.0, 2.0, 1.0);        // no line here: off the screen, nothing drawn
}

void fragment() {
	ALBEDO = packed ? linear(mix(vec3(0.169, 0.086, 0.200), srgb(COLOR.rgb) * 0.4, 0.45)) : ink.rgb;
}
