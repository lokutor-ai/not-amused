shader_type spatial;
// Cel shading: light falls in two flat steps with a crisp edge, the shadow side takes the colour of the ambient light,
// and the silhouette gets a thin band of light. Colours are flat, so nothing depends on textures.
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D paint : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// Where light turns into shadow, and how soft the edge is.
uniform float edge : hint_range(0.0, 1.0) = 0.46;
uniform float softness : hint_range(0.001, 0.4) = 0.025;
// A second, lighter step between light and shadow. 0 = none.
uniform float halftone : hint_range(0.0, 1.0) = 0.35;
uniform float rim : hint_range(0.0, 2.0) = 0.35;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
// Metal: a hard highlight.
uniform float shine : hint_range(0.0, 2.0) = 0.0;
uniform float shine_size : hint_range(0.0, 1.0) = 0.35;
// 1 = flat, not lit at all (eyes, teeth, flames).
uniform float flat_colour : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 8.0) = 0.0;
// How much of the shadows other things cast reaches it.
uniform float receive_shadow : hint_range(0.0, 1.0) = 1.0;

varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	vec3 c = albedo.rgb * texture(paint, UV).rgb * mix(tint, vec3(1.0), flat_colour);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * glow + c * flat_colour * 0.10;
}

void light() {
	float shadow = mix(1.0, ATTENUATION, LIGHT_IS_DIRECTIONAL ? receive_shadow : 1.0);
	float lit = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float s = LIGHT_IS_DIRECTIONAL ? smoothstep(0.35, 0.65, shadow) : shadow;
	float level = LIGHT_IS_DIRECTIONAL ? lit * mix(0.55, 1.0, s) : lit * sqrt(clamp(shadow, 0.0, 1.0));
	float full = smoothstep(edge - softness, edge + softness, level);
	float mid = smoothstep(edge - 0.16 - softness, edge - 0.16 + softness, level) * halftone;
	float band = max(full, mid);
	float strength = LIGHT_IS_DIRECTIONAL ? 1.0 : clamp(ceil(shadow * 4.0) / 4.0, 0.0, 1.0) * 0.9;
	band = mix(band, 1.0, flat_colour);
	DIFFUSE_LIGHT += band * strength * LIGHT_COLOR / PI;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.0 / max(rim_width, 0.01));
	DIFFUSE_LIGHT += smoothstep(0.25, 0.32, r) * rim * full * strength * LIGHT_COLOR / PI * (1.0 - flat_colour);
	if (shine > 0.0) {
		float h = dot(NORMAL, normalize(LIGHT + VIEW));
		float lim = 1.0 - shine_size * 0.16;
		SPECULAR_LIGHT += smoothstep(lim - 0.006, lim + 0.006, h) * shine * strength * LIGHT_COLOR / PI;
	}
}
