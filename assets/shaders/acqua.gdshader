shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Piccole increspature irregolari nei soli riflessi. Colore, trasparenza
// e rugosita restano costanti, senza bande sinusoidali o pulsazioni.
varying vec3 posizione_mondo;

float hash_acqua(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float increspatura(vec2 p) {
	vec2 cella = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_acqua(cella), hash_acqua(cella + vec2(1.0, 0.0)), f.x),
		mix(hash_acqua(cella + vec2(0.0, 1.0)), hash_acqua(cella + vec2(1.0)), f.x), f.y);
}

void vertex() {
	posizione_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Coordinate mondo: nessuna cucitura fra zone. Movimento lento e
	// ampiezza minima, ulteriormente attenuata quando si allontana la camera.
	vec2 p = posizione_mondo.xz * vec2(0.8, 1.15) + TIME * vec2(0.045, 0.025);
	float dettaglio = 1.0 - smoothstep(0.12, 0.45, max(length(dFdx(p)), length(dFdy(p))));
	vec2 pendenza = (vec2(increspatura(p), increspatura(p + vec2(19.7, 8.3))) - 0.5)
		* 0.024 * dettaglio;
	vec3 normale = normalize(vec3(-pendenza.x, 1.0, -pendenza.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normale, 0.0)).xyz);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	ROUGHNESS = 0.44;
}
