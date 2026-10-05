shader_type canvas_item;

// Filtro PSX sutil a pantalla completa. Lee la pantalla trasera
// (hint_screen_texture): posterize + dither Bayer 4x4 + scanlines + grano
// animado + viñeta suave.
// Va colocado en el ColorRect FiltroPSX de hud.tscn (mouse_filter IGNORE),
// asi que el juego se ve filtrado pero el input y los tests no se tocan.

uniform float posterize_niveles = 12.0;
uniform float dither_fuerza = 0.05;
uniform float vineta_fuerza = 0.3;
uniform float vineta_radio = 0.55;
uniform float scanline_fuerza = 0.035;
uniform float grano_fuerza = 0.02;
uniform float blanco_negro = 0.0;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;

	// Posterize por canal, al nivel mas cercano (floor(c*n+0.5)/n).
	c = floor(c * posterize_niveles + 0.5) / posterize_niveles;

	// Dither Bayer 4x4 en coordenadas de pixel, en aritmetica pura:
	// M4(x,y) = 4*M2(x0,y0) + M2(x1,y1) con M2(a,b) = 2*a*(1-2*b) + 3*b.
	vec2 px = mod(FRAGCOORD.xy, 4.0);
	float x0 = mod(px.x, 2.0);
	float y0 = mod(px.y, 2.0);
	float x1 = step(2.0, px.x);
	float y1 = step(2.0, px.y);
	float bajo = 2.0 * x0 * (1.0 - 2.0 * y0) + 3.0 * y0;
	float alto = 2.0 * x1 * (1.0 - 2.0 * y1) + 3.0 * y1;
	float bayer = (4.0 * bajo + alto) / 16.0;
	c += vec3(bayer * dither_fuerza);

	// Scanlines suaves (periodo 2 px) y grano animado de tubo.
	c *= 1.0 - scanline_fuerza * (0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159));
	float grano = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 60.0, -TIME * 47.0), vec2(12.9898, 78.233))) * 43758.5453);
	c += vec3((grano - 0.5) * grano_fuerza);

	// Noir: mezcla a luma para el modo detective.
	c = mix(c, vec3(dot(c, vec3(0.299, 0.587, 0.114))), blanco_negro);

	// Viñeta suave: oscuridad creciente con la distancia al centro de UV.
	float dist = distance(UV, vec2(0.5));
	float vineta = smoothstep(vineta_radio, vineta_radio + 0.3, dist) * vineta_fuerza;
	c -= vec3(vineta);

	COLOR = vec4(c, 1.0);
}
