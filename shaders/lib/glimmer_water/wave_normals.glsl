/*
    Glimmer procedural water waves, adapted for GLSL 1.20.
    Copyright (c) 2024 Josh Britain (jbritain), MIT License.

    The underlying "Very fast procedural ocean" method is by afl_ext:
    https://www.shadertoy.com/view/MdXyzX (MIT License).
*/
#ifndef CUBIZ_GLIMMER_WAVE_NORMALS
#define CUBIZ_GLIMMER_WAVE_NORMALS

#include "/lib/glimmer_water/common.glsl"

#define GLIMMER_WAVE_DRAG 0.2
#define GLIMMER_WAVE_EPSILON 0.1

vec2 glimmerWaveDerivative(
    vec2 position,
    vec2 direction,
    float frequency,
    float timeShift
) {
    float phase = dot(direction, position) * frequency + timeShift;
    phase = mod(phase, 2.0 * PI);
    float wave = exp(sin(phase) - 1.0) * 0.5;
    return vec2(wave, -wave * cos(phase));
}

float glimmerWaveHeight(vec2 position) {
    float phaseShift = length(position) * 0.1;
    float iteration = 0.0;
    float frequency = 1.0;
    float timeMultiplier = 2.0;
    float weight = 1.0;
    float valueSum = 0.0;
    float weightSum = 0.0;

    for (int octave = 0; octave < 16; ++octave) {
        float angle = mod(iteration, 2.0 * PI);
        vec2 direction = vec2(sin(angle), cos(angle));
        vec2 wave = glimmerWaveDerivative(
            position,
            direction,
            frequency,
            frameTimeCounter * timeMultiplier + phaseShift
        );

        position += direction * wave.y * weight * GLIMMER_WAVE_DRAG;
        valueSum += wave.x * weight;
        weightSum += weight;

        weight *= 0.8;
        frequency *= 1.18;
        timeMultiplier *= 1.07;
        iteration += 1232.399963;
    }

    return valueSum / max(weightSum, 0.0001);
}

vec3 glimmerWaveNormal(
    vec2 worldPosition,
    vec3 worldFaceNormal,
    float heightFactor
) {
    vec2 offset = vec2(GLIMMER_WAVE_EPSILON, 0.0);
    float centerHeight =
        glimmerWaveHeight(worldPosition) * WAVE_DEPTH * heightFactor;

    vec3 center = vec3(worldPosition.x, centerHeight, worldPosition.y);
    vec3 sampleX = vec3(
        worldPosition.x - GLIMMER_WAVE_EPSILON,
        glimmerWaveHeight(worldPosition - offset)
            * WAVE_DEPTH * heightFactor,
        worldPosition.y
    );
    vec3 sampleZ = vec3(
        worldPosition.x,
        glimmerWaveHeight(worldPosition + offset.yx)
            * WAVE_DEPTH * heightFactor,
        worldPosition.y + GLIMMER_WAVE_EPSILON
    );

    vec3 normal = normalize(cross(center - sampleX, center - sampleZ));
    normal = glimmerRotateBetween(
        normal,
        vec3(0.0, 1.0, 0.0),
        worldFaceNormal
    );
    return normalize(normal);
}

vec3 glimmerWaterSurfaceNormal(
    vec3 playerPosition,
    vec3 worldFaceNormal,
    float heightFactor,
    float jitter
) {
    #ifdef WATER_PARALLAX
        // The fixed-size refinement follows Glimmer's optional parallax path
        // without frame-varying noise, so it remains temporally stable.
        float denominator = max(abs(playerPosition.y), 0.001);
        float fraction = clamp(
            (abs(playerPosition.y) - WAVE_DEPTH) / denominator,
            0.0,
            1.0
        );
        vec3 origin = playerPosition * fraction;
        vec3 increment =
            (playerPosition - origin) / float(WATER_PARALLAX_SAMPLES);
        vec3 rayPosition = origin + increment * jitter;

        for (int sampleIndex = 0;
             sampleIndex < WATER_PARALLAX_SAMPLES;
             ++sampleIndex) {
            float height = glimmerWaveHeight(
                rayPosition.xz + cameraPosition.xz
            ) * WAVE_DEPTH;
            bool crossed = (playerPosition.y < 0.0)
                == (rayPosition.y < height);
            if (crossed) {
                increment *= 0.5;
            }
            rayPosition += increment * (crossed ? -1.0 : 1.0);
        }

        return glimmerWaveNormal(
            rayPosition.xz + cameraPosition.xz,
            worldFaceNormal,
            1.0
        );
    #else
        return glimmerWaveNormal(
            playerPosition.xz + cameraPosition.xz,
            worldFaceNormal,
            heightFactor
        );
    #endif
}

#endif
