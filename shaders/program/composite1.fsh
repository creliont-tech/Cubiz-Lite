// Glimmer water/underwater composite. It executes before Kute bloom and final
// color grading, so water shares the same exposure without buffer feedback.
#include "/lib/all_the_libs.glsl"
#include "/global/sky.glsl"
#include "/lib/glimmer_water/water_composite.glsl"

/* DRAWBUFFERS:0 */

void main() {
    // Pixel-center coordinates avoid interpolation differences along the two
    // triangles of the fullscreen quad.
    vec2 screenUV = glimmerClampUV(gl_FragCoord.xy * resolutionInv);
    vec3 color = texture2D(colortex0, screenUV).rgb;
    vec4 waterData = texture2D(
        colortex4,
        glimmerPixelCenterUV(screenUV)
    );

    // Alpha is written as exactly one only by water. Every non-water fragment
    // and the per-frame buffer clear writes zero.
    if (waterData.a > 0.5) {
        color = glimmerSurfaceWater(screenUV, color, waterData);
    }

    if (glimmerWaterBlend > 0.001) {
        color = glimmerUnderwater(screenUV, color);
    }

    gl_FragData[0] = vec4(color, 1.0);
}
