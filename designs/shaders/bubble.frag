#version 440
// Bubbles: one soap bubble, the way the Windows Vista screensaver drew them.
//
// The wallpaper behind it is seen through the bubble as through a lens, pulled
// in towards the rim. Over that, a thin-film rainbow swirls across the surface,
// faint in the middle and strong at the edge where the film is seen side on,
// with a soft window-shaped highlight at the top left and a glint opposite.
//
// Drawn only over the bubble's own square, so the cost is its area.
//
// Build: qsb --qt6 -o bubble.frag.qsb bubble.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;        // the bubble's middle on the wallpaper, 0..1
    vec2 radius;        // its radius on the wallpaper, 0..1 across and down
    float time;         // seconds, turns the film
    float hue;          // 0..1, where on the rainbow this bubble's film starts
    float filmAmount;   // how strong the rainbow film is
    float lens;         // how much the view through it bends at the rim
};
layout(binding = 1) uniform sampler2D wall;

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float d = length(p);
    float aa = max(fwidth(d) * 1.5, 0.002);
    float mask = 1.0 - smoothstep(1.0 - aa, 1.0, d);
    if (mask <= 0.0) { fragColor = vec4(0.0); return; }

    // The sphere's surface: z is 1 facing you, 0 at the rim.
    float z = sqrt(max(0.0, 1.0 - d * d));

    // The view through it, squeezed in towards the rim like a lens.
    vec2 q = p * mix(1.0 - lens, 1.0, z);
    vec3 view = texture(wall, center + q * radius).rgb;

    // Film thickness: swirls with time, and drains to the bottom.
    float t = time * 0.35 + hue * 6.2832;
    float thick = 0.55
        + 0.22 * sin(p.x * 2.4 + t)
        + 0.18 * sin(p.y * 3.3 - t * 0.8 + p.x * 1.6)
        + 0.12 * sin((p.x + p.y) * 5.0 + t * 1.3)
        + 0.25 * p.y;
    // Seen side on, the light goes a little further through the film. Kept
    // small so the colours stay broad bands rather than stripes at the rim.
    float path = thick * 0.9 + (1.0 - z) * 0.45;
    vec3 film = 0.5 + 0.5 * cos(6.2832 * (path / vec3(0.65, 0.53, 0.45) + hue));

    // Reflects more at the rim, and the sky above more than the floor below.
    float fresnel = 0.06 + 0.94 * pow(1.0 - z, 2.6);
    float sky = mix(0.35, 1.0, smoothstep(0.7, -0.8, p.y));
    vec3 col = view * (1.0 - 0.45 * fresnel)
             + film * sky * fresnel * filmAmount * 1.3
             + film * 0.06 * filmAmount;

    // A window reflected at the top left: a soft rounded rectangle on the curve.
    vec2 h = p - vec2(-0.36, -0.4);
    float ca = cos(0.7), sa = sin(0.7);
    h = vec2(ca * h.x - sa * h.y, sa * h.x + ca * h.y);
    vec2 box = abs(h) - vec2(0.2, 0.1);
    float sdf = length(max(box, 0.0)) + min(max(box.x, box.y), 0.0) - 0.06;
    // Brightest at its top, fading down, with a soft edge.
    float shine = 1.0 - smoothstep(-0.1, 0.14, sdf);
    col += vec3(0.7) * shine * mix(1.0, 0.45, clamp(h.y * 3.0 + 0.5, 0.0, 1.0));
    // And a small glint where the light comes back out, bottom right.
    col += vec3(0.35) * (1.0 - smoothstep(0.0, 0.16, length(p - vec2(0.48, 0.52))));

    // A crisp edge, darker and more coloured, so it reads as a sphere.
    float edge = smoothstep(0.86, 1.0, d);
    col = mix(col, col * 0.75 + film * 0.35, edge * 0.6);

    fragColor = vec4(col, 1.0) * mask * qt_Opacity;
}
