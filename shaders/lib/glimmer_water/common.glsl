/*
    Glimmer water integration for Cubiz Lite.
    Copyright (c) 2024 Josh Britain (jbritain)
    Licensed under the MIT License; see /licenses/Glimmer/LICENSE.

    This compatibility layer adapts Glimmer's packed surface data to the
    Kute-based GLSL 1.20 pipeline used by Cubiz Lite.
*/
#ifndef CUBIZ_GLIMMER_WATER_COMMON
#define CUBIZ_GLIMMER_WATER_COMMON

float glimmerSignNotZero(float value) {
    return value >= 0.0 ? 1.0 : -1.0;
}

vec2 glimmerEncodeNormal(vec3 normal) {
    normal /= abs(normal.x) + abs(normal.y) + abs(normal.z);
    vec2 encoded = normal.xy;
    if (normal.z < 0.0) {
        encoded = (1.0 - abs(encoded.yx)) * vec2(
            glimmerSignNotZero(encoded.x),
            glimmerSignNotZero(encoded.y)
        );
    }
    return encoded * 0.5 + 0.5;
}

vec3 glimmerDecodeNormal(vec2 encoded) {
    vec2 value = encoded * 2.0 - 1.0;
    vec3 normal = vec3(value, 1.0 - abs(value.x) - abs(value.y));
    if (normal.z < 0.0) {
        normal.xy = (1.0 - abs(normal.yx)) * vec2(
            glimmerSignNotZero(normal.x),
            glimmerSignNotZero(normal.y)
        );
    }
    return normalize(normal);
}

vec3 glimmerRotateBetween(vec3 value, vec3 from, vec3 to) {
    float cosine = clamp(dot(from, to), -1.0, 1.0);
    if (abs(cosine) >= 0.9999) {
        return cosine < 0.0 ? -value : value;
    }

    vec3 axis = normalize(cross(from, to));
    float sine = sqrt(max(1.0 - cosine * cosine, 0.0));
    return cosine * value
        + sine * cross(axis, value)
        + (1.0 - cosine) * dot(axis, value) * axis;
}

bool glimmerInsideScreen(vec2 uv) {
    return uv.x > resolutionInv.x
        && uv.y > resolutionInv.y
        && uv.x < 1.0 - resolutionInv.x
        && uv.y < 1.0 - resolutionInv.y;
}

vec2 glimmerClampUV(vec2 uv) {
    return clamp(uv, resolutionInv, vec2(1.0) - resolutionInv);
}

// Returns the exact center of the framebuffer texel containing uv. Depth and
// material data must not be linearly mixed across geometry or water edges.
vec2 glimmerPixelCenterUV(vec2 uv) {
    vec2 maximumPixel = max(resolution - vec2(1.0), vec2(0.0));
    vec2 pixel = clamp(floor(uv * resolution), vec2(0.0), maximumPixel);
    return (pixel + vec2(0.5)) * resolutionInv;
}

// The opaque depth buffer is sampled at texel centers. Scene color remains
// linearly filterable, but interpolating depth creates false surfaces that
// screen-space refraction can stretch into visible bands.
float glimmerOpaqueDepthAt(vec2 uv) {
    return texture2D(depthtex1, glimmerPixelCenterUV(uv)).r;
}

#endif
