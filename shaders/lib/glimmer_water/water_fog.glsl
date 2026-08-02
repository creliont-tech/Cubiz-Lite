/*
    Glimmer water absorption and scattering.
    Copyright (c) 2024 Josh Britain (jbritain)
    Licensed under the MIT License; see /licenses/Glimmer/LICENSE.

    Glimmer's optical coefficients are retained. Kute's current sun, moon, sky,
    and weather colors provide the incident light for Cubiz Lite.
*/
#ifndef CUBIZ_GLIMMER_WATER_FOG
#define CUBIZ_GLIMMER_WATER_FOG

#define GLIMMER_WATER_ABSORPTION \
    (vec3(0.3, 0.06, 0.04) * WATER_ABSORPTION_MOD)
#define GLIMMER_WATER_SCATTERING \
    (vec3(0.01, 0.05, 0.03) * 0.1 * WATER_SCATTERING_MOD)

vec3 glimmerWaterFog(
    vec3 color,
    vec3 startPosition,
    vec3 endPosition,
    vec3 scatterFactor
) {
    float travelDistance = distance(startPosition, endPosition);
    if (travelDistance < 0.01) {
        return color;
    }

    vec3 extinction = max(
        GLIMMER_WATER_ABSORPTION + GLIMMER_WATER_SCATTERING,
        vec3(0.0001)
    );
    vec3 transmittance = exp(-extinction * travelDistance);

    vec3 travelDirection = normalize(endPosition - startPosition);
    float lightPhase = max(
        xlf_phase(dot(travelDirection, sunOrMoonPosN), 0.4),
        0.0
    );

    float weatherVisibility = 1.0 - rainStrength * 0.55;
    vec3 directScatter = SUN_DIRECT * lightPhase * weatherVisibility;
    vec3 skyScatter = SKY_GROUND * (
        0.18 + float(eyeBrightnessSmooth.y) / 240.0 * 0.42
    );
    vec3 scatterLight = directScatter + skyScatter;
    scatterLight *= max(scatterFactor, vec3(0.0));

    vec3 inScatter = (vec3(1.0) - transmittance)
        * (GLIMMER_WATER_SCATTERING / extinction)
        * scatterLight;
    return color * transmittance + inScatter;
}

#endif
