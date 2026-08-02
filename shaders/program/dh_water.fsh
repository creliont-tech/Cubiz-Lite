// Distant Horizons translucent material stage.
// It mirrors the normal water pass so the Glimmer composite receives the same
// strict mask format at both vanilla and DH distances.
#define DH_TERRAIN

#include "/lib/all_the_libs.glsl"

uniform sampler2D gtexture;

varying vec2 texcoord;
varying vec4 glcolor;
varying vec2 LightmapCoords;

#include "/global/lighting.fsh"
#include "/global/sky.glsl"
#include "/global/fog.glsl"
#include "/lib/glimmer_water/common.glsl"

vec4 get_dh_translucent_basic(vec3 tweakedLightmap, vec3 viewPos) {
    vec4 color = glcolor * texture2D(gtexture, texcoord);
    if (color.a < 0.1) {
        discard;
    }

    vec3 playerPos = to_player_pos(viewPos);
    #ifdef DH_NOISE
        color.rgb = dh_noise(playerPos, color.rgb);
    #endif

    color.rgb = to_linear(color.rgb) * tweakedLightmap;
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
    vec3 viewPos = to_view_pos(vec3(screenUV, gl_FragCoord.z), true);
    vec3 playerPos = to_player_pos(viewPos);

    if (!transition_to_dh(playerPos, true, bayer8(gl_FragCoord.xy))) {
        discard;
        return;
    }

    if (texture2D(depthtex0, screenUV).x < 1.0) {
        discard;
        return;
    }

    if (material == 1001.0) {
        vec3 worldFaceNormal = normalize(
            mat3(gbufferModelViewInverse) * Normal
        );
        gl_FragData[0] = vec4(0.0);
        gl_FragData[1] = vec4(
            glimmerEncodeNormal(worldFaceNormal),
            clamp(LightmapCoords.y, 0.0, 1.0),
            1.0
        );
        return;
    }

    gl_FragData[0] = get_dh_translucent_basic(tweak_lightmap(), viewPos);
    gl_FragData[1] = vec4(0.0);
}
