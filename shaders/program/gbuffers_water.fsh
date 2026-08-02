// Cubiz Lite translucent material stage.
// Water leaves the scene color untouched and writes only an exact Glimmer
// water mask, face normal, and skylight value to colortex4.
#include "/lib/all_the_libs.glsl"

uniform sampler2D gtexture;

varying vec2 texcoord;
varying vec4 glcolor;
varying vec2 LightmapCoords;

#include "/global/lighting.fsh"
#include "/global/sky.glsl"
#include "/global/fog.glsl"
#include "/lib/glimmer_water/common.glsl"

vec4 get_translucent_basic(vec3 tweakedLightmap, vec3 viewPos) {
    vec4 color = glcolor * texture2D(gtexture, texcoord);
    if (color.a < 0.1) {
        discard;
    }

    color.rgb = to_linear(color.rgb) * tweakedLightmap;
    vec3 playerPos = to_player_pos(viewPos);
    vec3 viewDir = normalize(viewPos);
    vec3 skyColor = get_sky_main(
        viewDir,
        normalize(playerPos),
        get_sun_glare(dot(viewDir, sunPosN))
    );
    color.rgb = get_fog_main(playerPos, color.rgb, gl_FragCoord.z, skyColor);
    return color;
}

/* DRAWBUFFERS:04 */

void main() {
    vec2 screenUV = gl_FragCoord.xy * resolutionInv;
    vec3 viewPos = to_view_pos(vec3(screenUV, gl_FragCoord.z), false);

    #ifdef DISTANT_HORIZONS
        vec3 playerPos = to_player_pos(viewPos);
        if (transition_to_dh(playerPos, false, bayer8(gl_FragCoord.xy))) {
            discard;
            return;
        }
    #endif

    if (material == 1001.0) {
        vec3 worldFaceNormal = normalize(
            mat3(gbufferModelViewInverse) * Normal
        );

        // Alpha zero preserves the already-rendered opaque scene. The
        // unblended colortex4 write is the strict water-only material record.
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(
            glimmerEncodeNormal(worldFaceNormal),
            clamp(LightmapCoords.y, 0.0, 1.0),
            1.0
        );
        return;
    }

    gl_FragData[0] = get_translucent_basic(tweak_lightmap(), viewPos);
    gl_FragData[1] = vec4(0.0);
}
