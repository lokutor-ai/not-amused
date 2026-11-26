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
// Set by Toon.batch, which packs surfaces together: each vertex then carries its colour (albedo times its own tint, the
// flat part already applied; stored in sRGB, it reaches the shader in linear, as albedo does) and its look (Toon.PACKED,
// in CUSTOM0 and CUSTOM1), and albedo and the look values above are not used.
uniform bool packed = false;

varying vec3 tint;
varying flat vec4 look_a;                 // flat_colour, receive_shadow, rim, halftone
varying flat vec3 look_b;                 // shine, shine_size, glow

void vertex() {
	tint = COLOR.rgb;
	look_a = packed ? CUSTOM0 : vec4(flat_colour, receive_shadow, rim, halftone);
	look_b = packed ? CUSTOM1.xyz : vec3(shine, shine_size, glow);
}

void fragment() {
	vec3 c = (packed ? tint : albedo.rgb * mix(tint, vec3(1.0), look_a.x)) * texture(paint, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = c * look_b.z + c * look_a.x * 0.10;
}

void light() {
	float shadow = mix(1.0, ATTENUATION, LIGHT_IS_DIRECTIONAL ? look_a.y : 1.0);
	float lit = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float s = LIGHT_IS_DIRECTIONAL ? smoothstep(0.35, 0.65, shadow) : shadow;
	float level = LIGHT_IS_DIRECTIONAL ? lit * mix(0.55, 1.0, s) : lit * sqrt(clamp(shadow, 0.0, 1.0));
	float full = smoothstep(edge - softness, edge + softness, level);
	float mid = smoothstep(edge - 0.16 - softness, edge - 0.16 + softness, level) * look_a.w;
	float band = max(full, mid);
	float strength = LIGHT_IS_DIRECTIONAL ? 1.0 : clamp(ceil(shadow * 4.0) / 4.0, 0.0, 1.0) * 0.9;
	band = mix(band, 1.0, look_a.x);
	DIFFUSE_LIGHT += band * strength * LIGHT_COLOR / PI;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.0 / max(rim_width, 0.01));
	DIFFUSE_LIGHT += smoothstep(0.25, 0.32, r) * look_a.z * full * strength * LIGHT_COLOR / PI * (1.0 - look_a.x);
	if (look_b.x > 0.0) {
		float h = dot(NORMAL, normalize(LIGHT + VIEW));
		float lim = 1.0 - look_b.y * 0.16;
		SPECULAR_LIGHT += smoothstep(lim - 0.006, lim + 0.006, h) * look_b.x * strength * LIGHT_COLOR / PI;
	}
}
