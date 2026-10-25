#version 440
// Frost, first pass: where and how the frost grows, worked out once.
//
// Nothing here moves. The picture is drawn when the screen is built (or
// resized) and kept, and frost.frag reads it every time the glass changes.
//
//   red    when the frost gets here, 0 (first) .. 1 (last). Frost starts in
//          the corners and along the edges, a little sooner at the bottom
//          where a real window is coldest, and pushes in along feathery veins
//          ahead of the rest.
//   green  how dense the frost is here, drifting smoothly across the glass.
//   blue   a sparse glitter of single bright crystals.
//
// Build: qsb --qt6 -o frostfield.frag.qsb frostfield.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect;      // width / height
    float seed;        // a different pattern per number
    float veinPush;    // how far the veins run ahead of the frost front
    float bottomBias;  // how much sooner the bottom freezes than the top
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed * 0.1317);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.1, 9.2);
        a *= 0.5;
    }
    return v;
}

// Sharp ridges where plain noise crosses the middle: thin branching lines,
// which is what frost ferns look like from a step back.
float ridged(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        float n = 1.0 - abs(noise(p) * 2.0 - 1.0);
        v += a * n * n;
        p = p * 2.1 + vec2(3.7, 11.3);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * aspect, uv.y);

    // Distance to the nearest edge, in screen heights. The soft minimum of
    // the two is smaller in the corners, so they freeze first.
    float dx = min(uv.x, 1.0 - uv.x) * aspect;
    float dy = min(uv.y, 1.0 - uv.y);
    float soft = 2.0 * dx * dy / (dx + dy + 1e-4);
    float d = mix(min(dx, dy), soft, 0.5);
    d *= mix(1.0 + bottomBias, 1.0 - bottomBias, uv.y);

    // Bend the coordinates so the veins wander instead of running straight.
    vec2 w = vec2(fbm(p * 3.0), fbm(p * 3.0 + 5.2));
    vec2 q = p + (w - 0.5) * 0.3;

    float veins = ridged(q * 5.0);
    float lumps = fbm(q * 2.0) - 0.5;
    float drift = fbm(q * 3.5 + w * 2.0);
    float grain = noise(p * 260.0);

    float arrival = d * 2.0 - veins * veinPush - lumps * 0.3 + 0.05;
    // Smooth frost: a density that drifts gently across the glass, the veins
    // only a little brighter, and a fine grain so it reads as ice, not paint.
    float crystal = clamp(0.5 + (drift - 0.5) * 1.1 + (pow(veins, 3.0) - 0.15) * 0.3 + (grain - 0.5) * 0.12, 0.0, 1.0);
    float glitter = step(0.995, hash(floor(p * 420.0))) * drift;

    fragColor = vec4(clamp(arrival, 0.0, 0.98), crystal, glitter, 1.0) * qt_Opacity;
}
