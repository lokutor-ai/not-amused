shader_type spatial;
// The drawn line: the mesh again, inside out and a little bigger, in ink. Its width is in pixels at any distance, thinner
// far away so small things do not turn black.
render_mode cull_front, unshaded, shadows_disabled, fog_disabled;

uniform vec4 ink : source_color = vec4(0.17, 0.09, 0.20, 1.0);
uniform float width = 3.0;
uniform float max_world = 0.030;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = normalize((PROJECTION_MATRIX * vec4(n, 0.0)).xy + vec2(1e-5));
	vec2 px = dir * width * 2.0 / VIEWPORT_SIZE * (VIEWPORT_SIZE.y / 1080.0);
	float limit = max_world * abs(PROJECTION_MATRIX[1][1]) / clip.w;
	px *= smoothstep(0.04, 0.40, length(n.xy));                  // no specks where the surface faces the camera
	px *= min(1.0, limit / max(length(px * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0)), 1e-5));
	clip.xy += px * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
