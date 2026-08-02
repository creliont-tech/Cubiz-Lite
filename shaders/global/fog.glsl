// Kute atmosphere retained for Cubiz Lite. Water and underwater fog are
// handled exclusively by the Glimmer water composite.
vec3 get_lava_fog(float dist, vec3 color) {
    const vec3 LAVA_FOG_COLOR = to_linear(vec3(0.85, 0.65, 0.45));
    const vec3 PSNOW_FOG_COLOR = to_linear(vec3(0.7, 0.75, 0.85));

    if (isEyeInWater == 2) {
        dist = clamp(dist / 3.0, 0.0, 1.0);
        return mix(color, LAVA_FOG_COLOR, dist * 0.7);
    }
    if (isEyeInWater == 3) {
        dist = clamp(dist / 3.0, 0.0, 1.0);
        return mix(color, PSNOW_FOG_COLOR, dist * 0.7);
    }
    return color;
}

vec3 get_border_fog(float strength, vec3 color, vec3 SkyColor) {
    strength *= strength * 0.8;
    #ifndef DIMENSION_NETHER
        strength *= strength * 0.9;
        strength *= strength * 0.9;
    #endif
    strength = exp(-2.0 * strength);
    return mix(SkyColor, color, strength);
}

vec3 get_blindness_fog(float Dist, vec3 Color) {
    Dist = clamp(1.0 - exp(-2.0 * Dist / 12.0), 0.0, 1.0);
    Dist *= max(darknessFactor, blindness);
    return Color * (1.0 - Dist * 0.8);
}

vec3 get_atm_fog(float Dist, vec3 Color, vec3 WorldPos, vec3 FogColor) {
    Dist = min(Dist / 320.0, 1.0);
    Dist = 1.0 - exp(-2.0 * Dist);
    float Visibility = sunriseStrength * 0.4 + nightStrength * 0.8;
    Visibility = max(Visibility, rainStrength * 0.8) * isOutdoorsSmooth;
    Visibility *= ATM_FOG_STRENGTH * 0.7;
    Visibility *= 1.0 - fbm_fast(WorldPos.xz, 1) * 0.7;

    float HeightFalloff = 0.0;
    if (WorldPos.y >= 50.0) {
        HeightFalloff = smoothstep(55.0, 75.0, WorldPos.y);
        HeightFalloff -= smoothstep(75.0, 130.0, WorldPos.y);
    }

    return mix(Color, FogColor, Dist * HeightFalloff * Visibility * 0.8);
}

vec3 get_fog_main(vec3 PlayerPos, vec3 Color, float Depth, vec3 SkyColor) {
    float Dist = length(PlayerPos);

    if (Depth < 1.0) {
        #if defined DIMENSION_OVERWORLD && defined ATMOSPHERIC_FOG
            if (isEyeInWater == 0) {
                Color = get_atm_fog(Dist, Color, PlayerPos + cameraPosition, SkyColor);
            }
        #endif
        #if defined BORDER_FOG && !defined CUSTOM_SKYBOXES
            if (isEyeInWater == 0) {
                #ifdef DISTANT_HORIZONS
                    Color = get_border_fog(Dist / dhRenderDistance, Color, SkyColor);
                #else
                    Color = get_border_fog(Dist / far, Color, SkyColor);
                #endif
            }
        #endif
    }

    Color = get_lava_fog(Dist, Color);
    Color = get_blindness_fog(Dist, Color);
    return Color;
}
