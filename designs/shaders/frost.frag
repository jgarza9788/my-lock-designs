#version 440
// Frost, second pass: the window itself.
//
// The wallpaper is the view through the glass. Where the frost map
// (frostfield.frag) says the frost has arrived, the view goes blurred and
// white with crystals; the longer it has been there, the thicker. The time is
// wiped out of the frost as if with a finger, and typing breathes a clear
// patch around the password field that freezes over again once you stop.
//
// Drawn at half size, and only when something here changes: while the frost
// is still growing, while the breath comes and goes, once a minute.
//
// Build: qsb --qt6 -o frost.frag.qsb frost.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 clear glass .. 1 frozen over
    float aspect;       // width / height
    float breathX;      // the breath patch: its middle, 0..1 of the screen
    float breathY;
    float breathSize;   // its radius, in screen heights
    float breath;       // 0 none .. 1 fully melted
    float iceAmount;    // how white the thickest frost goes
    float fogAmount;    // how much the clear glass mists as it freezes
    float mistWidth;    // how far ahead of the frost the glass blurs, in progress
    float timeOpacity;  // 0 hides the time (boot snapshots)
    vec2 texel;         // one pixel of the time mask, in 0..1
    vec4 iceColor;
    vec4 textColor;
};

layout(binding = 1) uniform sampler2D sharp;
layout(binding = 2) uniform sampler2D blurred;
layout(binding = 3) uniform sampler2D field;
layout(binding = 4) uniform sampler2D timeMask;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 f = texture(field, uv);

    float grown = progress - f.r;
    float cover = smoothstep(0.0, 0.15, grown);
    float thick = smoothstep(0.0, 0.4, grown);

    // The breath: a wide oval round the field, its edge ragged with the
    // crystals so it melts back into them rather than along a circle.
    vec2 d = (uv - vec2(breathX, breathY)) * vec2(aspect, 1.0);
    float r = length(d * vec2(0.55, 1.0)) + (f.g - 0.5) * 0.05;
    float melt = breath * (1.0 - smoothstep(breathSize * 0.5, breathSize, r));
    cover *= 1.0 - melt;

    // The time, softened a little, so the wiped edge is not a cut.
    float m = texture(timeMask, uv).r * 0.4
            + (texture(timeMask, uv + vec2(texel.x, 0.0)).r
             + texture(timeMask, uv - vec2(texel.x, 0.0)).r
             + texture(timeMask, uv + vec2(0.0, texel.y)).r
             + texture(timeMask, uv - vec2(0.0, texel.y)).r) * 0.15;
    m *= timeOpacity;

    // Frost: the blurred view, nudged by the crystals so it looks refracted,
    // whitened by how dense and how thick the frost is here.
    vec2 bend = vec2(f.g - 0.5, f.r - 0.5) * 0.006 * thick;
    vec3 behind = texture(blurred, uv + bend).rgb;
    // A milky haze that thickens with time, denser in some places than others.
    float white = clamp(iceAmount * (0.45 + 0.55 * thick) * (0.7 + 0.6 * (f.g - 0.5) + 0.3 * f.g), 0.0, 1.0);
    vec3 ice = mix(behind, iceColor.rgb, white) + f.b * thick * 0.35;

    // Clear glass, misting over as the window freezes, and blurred in a band
    // ahead of the frost so the view goes soft before it goes white.
    // It fades in as the freeze begins, so the glass starts out clear.
    float haze = smoothstep(-mistWidth, 0.0, grown) * smoothstep(0.0, mistWidth, progress) * (1.0 - melt);
    vec3 glass = mix(texture(sharp, uv).rgb, behind, max(haze, fogAmount * progress));

    // A finger leaves a little frost behind in the wiped strokes.
    vec3 col = mix(glass, ice, cover * (1.0 - m * 0.88));
    // A wet rim where the finger went through the frost.
    float rim = smoothstep(0.1, 0.35, m) * (1.0 - smoothstep(0.35, 0.7, m)) * cover;
    col += rim * 0.18;
    // Before there is frost to wipe, the time is plain text on the glass.
    col = mix(col, textColor.rgb, m * (1.0 - cover) * textColor.a);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
