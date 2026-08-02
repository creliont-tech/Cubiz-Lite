/*
    Glimmer screen-space water reflection, adapted for GLSL 1.20.
    Copyright (c) 2024 Josh Britain (jbritain)
    Licensed under the MIT License; see /licenses/Glimmer/LICENSE.

    No history buffer is used. Optional jitter is a stable Bayer value, so the
    reflection does not shimmer from a changing random seed.

    Glimmer's original source credits Belmu for the ray-march basis:
    https://gist.github.com/BelmuTM/af0fe99ee5aab386b149a53775fe94a3
    It also credits DrDesten for the depth-lenience expression retained here.
*/
#ifndef CUBIZ_GLIMMER_SCREEN_REFLECTION
#define CUBIZ_GLIMMER_SCREEN_REFLECTION

#include "/lib/glimmer_water/common.glsl"

float glimmerReflectionHitConfidence(
    vec3 viewOrigin,
    vec3 viewDirection,
    vec3 rayScreenPosition
) {
    if (!glimmerInsideScreen(rayScreenPosition.xy)) {
        return 0.0;
    }

    vec2 hitUV = glimmerClampUV(rayScreenPosition.xy);
    float sceneDepth = glimmerOpaqueDepthAt(hitUV);
    if (sceneDepth >= 1.0) {
        return 0.0;
    }

    vec2 depthUV = glimmerPixelCenterUV(hitUV);
    vec3 sceneViewPosition = to_view_pos(
        vec3(depthUV, sceneDepth),
        false
    );
    vec3 hitOffset = sceneViewPosition - viewOrigin;
    float distanceAlongRay = dot(hitOffset, viewDirection);
    if (distanceAlongRay <= 0.05) {
        return 0.0;
    }

    // Reject hits that are not spatially close to the reflected view ray.
    // This prevents the ray from catching the opaque floor below the water.
    float perpendicularDistance = length(
        hitOffset - viewDirection * distanceAlongRay
    );
    float alignmentTolerance = max(
        0.35,
        distanceAlongRay * 0.035
    );
    float alignment = 1.0 - smoothstep(
        alignmentTolerance * 0.35,
        alignmentTolerance,
        perpendicularDistance
    );

    float edgeDistance = max(
        abs(hitUV.x - 0.5),
        abs(hitUV.y - 0.5)
    ) * 2.0;
    float edgeConfidence = 1.0 - smoothstep(0.84, 1.0, edgeDistance);
    return alignment * edgeConfidence;
}

bool glimmerTraceReflection(
    vec3 viewOrigin,
    vec3 viewDirection,
    float jitter,
    out vec3 hitScreenPosition,
    out float hitConfidence
) {
    hitScreenPosition = vec3(0.0);
    hitConfidence = 0.0;
    if (viewDirection.z > 0.0 && viewDirection.z >= -viewOrigin.z) {
        return false;
    }

    #if REFLECTION_MODE == 0
        hitScreenPosition = vec3(0.0);
        return false;
    #elif REFLECTION_MODE == 1
        hitScreenPosition = view_screen(
            viewOrigin + viewDirection * 76.0,
            false
        );
        if (!glimmerInsideScreen(hitScreenPosition.xy)) {
            return false;
        }
        float sceneDepth = glimmerOpaqueDepthAt(
            hitScreenPosition.xy
        );
        if (sceneDepth >= 1.0
            || sceneDepth < view_screen(viewOrigin, false).z) {
            return false;
        }
        hitConfidence = glimmerReflectionHitConfidence(
            viewOrigin,
            viewDirection,
            hitScreenPosition
        );
        return hitConfidence > 0.001;
    #else
        vec3 rayPosition = view_screen(viewOrigin, false);
        vec3 rayDirection = view_screen(
            viewOrigin + viewDirection,
            false
        ) - rayPosition;
        rayDirection = normalize(rayDirection);

        vec3 boundaryDistance = abs(
            sign(rayDirection) - rayPosition
        ) / max(abs(rayDirection), vec3(0.00001));
        float rayLength = min(
            boundaryDistance.x,
            min(boundaryDistance.y, boundaryDistance.z)
        );
        vec3 rayStep = rayDirection
            * rayLength / float(SSR_STEPS * 4);
        rayPosition += rayStep * jitter
            + length(resolutionInv) * rayDirection;

        float startDepth = view_screen(viewOrigin, false).z;
        float depthTolerance = max(
            abs(rayStep.z) * 3.0,
            0.02 / max(viewOrigin.z * viewOrigin.z, 0.001)
        );
        bool hit = false;

        for (int stepIndex = 0;
             stepIndex < SSR_STEPS * 4;
             ++stepIndex) {
            if (!glimmerInsideScreen(rayPosition.xy)
                || rayPosition.z <= 0.0
                || rayPosition.z >= 1.0) {
                hitScreenPosition = rayPosition;
                return false;
            }

            float sceneDepth = glimmerOpaqueDepthAt(rayPosition.xy);
            if (abs(sceneDepth - startDepth) > 0.00001) {
                float depthDelta = rayPosition.z - sceneDepth;
                hit = sceneDepth < rayPosition.z
                    && depthDelta > 0.0
                    && depthDelta < depthTolerance * 2.0
                    && rayPosition.z > 0.56
                    && sceneDepth < 1.0;
            }
            if (hit) {
                break;
            }
            rayPosition += rayStep;
        }

        if (!hit) {
            hitScreenPosition = rayPosition;
            return false;
        }

        // Five fixed refinements reduce stair stepping without temporal data.
        for (int refinement = 0; refinement < 5; ++refinement) {
            rayStep *= 0.5;
            if (!glimmerInsideScreen(rayPosition.xy)
                || rayPosition.z <= 0.0
                || rayPosition.z >= 1.0) {
                hitScreenPosition = rayPosition;
                return false;
            }
            float sceneDepth = glimmerOpaqueDepthAt(rayPosition.xy);
            rayPosition += (sceneDepth < rayPosition.z ? -1.0 : 1.0)
                * rayStep;
        }

        hitScreenPosition = rayPosition;
        hitConfidence = glimmerReflectionHitConfidence(
            viewOrigin,
            viewDirection,
            hitScreenPosition
        );
        return hitConfidence > 0.001;
    #endif
}

#endif
