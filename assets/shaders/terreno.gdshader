shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Grana opaca alla scala delle texture refined_v2. Le coordinate mondo
// mantengono il dettaglio continuo fra celle e zone, anche dopo lo scavo.
varying vec3 posizione_mondo;
varying vec3 normale_mondo;

float hash_grana(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grana(vec2 p) {
	vec2 cella = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_grana(cella), hash_grana(cella + vec2(1.0, 0.0)), f.x),
		mix(hash_grana(cella + vec2(0.0, 1.0)), hash_grana(cella + vec2(1.0)), f.x), f.y);
}

void vertex() {
	posizione_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale_mondo = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Proiezione sui pianori e sui due orientamenti delle scarpate, senza UV
	// né nuove facce. La geometria del terreno rimane quella originale.
	vec3 n = abs(normale_mondo);
	vec2 p = posizione_mondo.xz;
	if (n.x > 0.5) {
		p = posizione_mondo.zy;
	} else if (n.z > 0.5) {
		p = posizione_mondo.xy;
	}
	float largo = grana(p * 0.7) - 0.5;
	// Sfuma la grana minuta quando diventa subpixel per evitare sfarfallii.
	float dettaglio = 1.0 - smoothstep(0.035, 0.14, max(length(dFdx(p)), length(dFdy(p))));
	float fine = (grana(p * 18.0) - 0.5) * dettaglio;
	ALBEDO = COLOR.rgb * (1.0 + largo * 0.10 + fine * 0.16);
	ROUGHNESS = clamp(0.88 + fine * 0.12, 0.80, 0.96);
}
