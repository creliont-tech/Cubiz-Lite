#include "/lib/all_the_libs.glsl"

varying vec2 texcoord;

/* DRAWBUFFERS:0 */

// Stable color grading and tone mapping. Cubiz Lite deliberately has no
// temporal history output, motion blur, or reflection feedback buffer here.
void main() {
    vec4 Color = texture2D(colortex0, texcoord);

    Color.rgb *= EXPOSURE;
    Color.rgb = apply_tonemap(Color.rgb);

    #if TONEMAP_OPERATOR != 3
    Color.rgb = pow(Color.rgb, vec3(1.0 / 2.2));
    #endif

    #if DEBUG_SHOW_BUFFER == 0
    gl_FragData[0] = Color;
    #elif DEBUG_SHOW_BUFFER == 1
    gl_FragData[0] = texelFetch2D(colortex1, ivec2(gl_FragCoord.xy), 0);
    #elif DEBUG_SHOW_BUFFER == 2
    gl_FragData[0] = texelFetch2D(noisetex, ivec2(gl_FragCoord.xy), 0);
    #elif DEBUG_SHOW_BUFFER == 3
    gl_FragData[0] = texelFetch2D(depthtex0, ivec2(gl_FragCoord.xy), 0);
    #else
    gl_FragData[0] = Color;
    #endif
}
