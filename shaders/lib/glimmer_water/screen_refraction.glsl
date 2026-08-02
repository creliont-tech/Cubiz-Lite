/*
    Depth-consistent screen-space refraction for Cubiz Lite.

    Glimmer's wave normal, refractive indices, Fresnel response, and fallback
    appearance are retained. This integration-specific tracer replaces the
    former single projection based on the opaque depth of the original pixel.
    Every accepted color sample is tied to an actual crossing of depthtex1.
*/
#ifndef CUBIZ_GLIMMER_SCREEN_REFRACTION
#define CUBIZ_GLIMMER_SCREEN_REFRACTION

#include "/lib/glimmer_water/common.glsl"

#define GLIMMER_REFRACTION_STEPS 16
#define GLIMMER_REFRACTION_REFINEMENTS 5

bool glimmerRefractionProbe(
    vec3 viewPosition,
    out vec3 screenPosition,
    out float sceneDepth
) {
    // Points behind the camera cannot be projected safely.
    if (viewPosition.z >= -near * 0.5) {
        screenPosition = vec3(0.0);
        sceneDepth = 1.0;
        return false;
    }

    screenPosition = view_screen(viewPosition, false);
    if (!glimmerInsideScreen(screenPosition.xy)
        || screenPosition.z <= 0.0
        || screenPosition.z >= 1.0) {
        sceneDepth = 1.0;
        return false;
    }

    sceneDepth = glimmerOpaqueDepthAt(screenPosition.xy);
    return true;
}

bool glimmerTraceRefraction(
    vec3 surfaceViewPosition,
    vec3 refractedDirection,
    float maximumDistance,
    out vec2 hitUV,
    out float hitDepth,
    out vec3 hitViewPosition
) {
    hitUV = vec2(0.0);
    hitDepth = 1.0;
    hitViewPosition = vec3(0.0);

    float previousDistance = 0.04;
    float previousDelta = -1.0;

    for (int stepIndex = 1;
         stepIndex <= GLIMMER_REFRACTION_STEPS;
         ++stepIndex) {
        float stepFraction = float(stepIndex)
            / float(GLIMMER_REFRACTION_STEPS);
        float rayDistance = mix(
            0.04,
            maximumDistance,
            stepFraction * stepFraction
        );
        vec3 rayViewPosition = surfaceViewPosition
            + refractedDirection * rayDistance;

        vec3 rayScreenPosition;
        float sceneDepth;
        if (!glimmerRefractionProbe(
            rayViewPosition,
            rayScreenPosition,
            sceneDepth
        )) {
            return false;
        }

        float depthDelta = -1.0;
        if (sceneDepth < 1.0) {
            // Both depths use the same projection, so their ordering is valid
            // here. Positive means the refracted ray crossed opaque geometry.
            depthDelta = rayScreenPosition.z - sceneDepth;
        }

        if (depthDelta >= 0.0 && previousDelta < 0.0) {
            float lowerDistance = previousDistance;
            float upperDistance = rayDistance;

            // Refine the first front-to-back depth crossing. Unlike the old
            // one-shot projection, this cannot jump directly to an unrelated
            // block merely because the original pixel had different depth.
            for (int refinement = 0;
                 refinement < GLIMMER_REFRACTION_REFINEMENTS;
                 ++refinement) {
                float middleDistance =
                    (lowerDistance + upperDistance) * 0.5;
                vec3 middleViewPosition = surfaceViewPosition
                    + refractedDirection * middleDistance;
                vec3 middleScreenPosition;
                float middleSceneDepth;

                if (!glimmerRefractionProbe(
                    middleViewPosition,
                    middleScreenPosition,
                    middleSceneDepth
                )) {
                    return false;
                }

                bool behindGeometry = middleSceneDepth < 1.0
                    && middleScreenPosition.z >= middleSceneDepth;
                if (behindGeometry) {
                    upperDistance = middleDistance;
                } else {
                    lowerDistance = middleDistance;
                }
            }

            vec3 finalRayPosition = surfaceViewPosition
                + refractedDirection * upperDistance;
            vec3 finalScreenPosition;
            float finalSceneDepth;
            if (!glimmerRefractionProbe(
                finalRayPosition,
                finalScreenPosition,
                finalSceneDepth
            ) || finalSceneDepth >= 1.0) {
                return false;
            }

            vec2 depthUV = glimmerPixelCenterUV(
                finalScreenPosition.xy
            );
            vec3 sceneViewPosition = to_view_pos(
                vec3(depthUV, finalSceneDepth),
                false
            );
            vec3 hitOffset = sceneViewPosition - surfaceViewPosition;
            float distanceAlongRay = dot(
                hitOffset,
                refractedDirection
            );
            if (distanceAlongRay <= 0.02) {
                return false;
            }

            // Reprojection and the sampled depth must describe the same 3-D
            // point. This rejects silhouette crossings and duplicated samples.
            float missDistance = length(
                hitOffset - refractedDirection * distanceAlongRay
            );
            float pixelRadius = abs(sceneViewPosition.z) * 2.0 * max(
                resolutionInv.x
                    / max(abs(gbufferProjection[0].x), 0.0001),
                resolutionInv.y
                    / max(abs(gbufferProjection[1].y), 0.0001)
            );
            float alignmentTolerance = max(pixelRadius * 3.0, 0.08);
            if (missDistance > alignmentTolerance) {
                return false;
            }

            hitUV = glimmerClampUV(finalScreenPosition.xy);
            hitDepth = finalSceneDepth;
            hitViewPosition = sceneViewPosition;
            return true;
        }

        previousDistance = rayDistance;
        previousDelta = depthDelta;
    }

    return false;
}

void glimmerAccumulateRefractionTexel(
    vec2 pixel,
    float spatialWeight,
    float referenceDistance,
    inout vec3 colorSum,
    inout float weightSum
) {
    vec2 maximumPixel = max(resolution - vec2(1.0), vec2(0.0));
    pixel = clamp(pixel, vec2(0.0), maximumPixel);
    vec2 sampleUV = (pixel + vec2(0.5)) * resolutionInv;
    float sampleDepth = glimmerOpaqueDepthAt(sampleUV);
    if (sampleDepth >= 1.0) {
        return;
    }

    vec3 sampleViewPosition = to_view_pos(
        vec3(sampleUV, sampleDepth),
        false
    );
    float sampleDistance = length(sampleViewPosition);
    float depthTolerance = max(referenceDistance * 0.015, 0.08);
    float depthWeight = 1.0 - smoothstep(
        depthTolerance,
        depthTolerance * 4.0,
        abs(sampleDistance - referenceDistance)
    );
    float weight = spatialWeight * depthWeight;

    colorSum += texture2D(colortex0, sampleUV).rgb * weight;
    weightSum += weight;
}

vec3 glimmerSampleRefractedScene(
    vec2 hitUV,
    float hitDepth,
    vec3 fallbackColor
) {
    // Depth-aware bilinear filtering preserves smooth motion without blending
    // sky or foreground colors across an opaque silhouette.
    vec2 pixelPosition = hitUV * resolution - vec2(0.5);
    vec2 basePixel = floor(pixelPosition);
    vec2 interpolation = fract(pixelPosition);
    vec2 referenceUV = glimmerPixelCenterUV(hitUV);
    float referenceDistance = length(to_view_pos(
        vec3(referenceUV, hitDepth),
        false
    ));

    vec3 colorSum = vec3(0.0);
    float weightSum = 0.0;
    glimmerAccumulateRefractionTexel(
        basePixel,
        (1.0 - interpolation.x) * (1.0 - interpolation.y),
        referenceDistance,
        colorSum,
        weightSum
    );
    glimmerAccumulateRefractionTexel(
        basePixel + vec2(1.0, 0.0),
        interpolation.x * (1.0 - interpolation.y),
        referenceDistance,
        colorSum,
        weightSum
    );
    glimmerAccumulateRefractionTexel(
        basePixel + vec2(0.0, 1.0),
        (1.0 - interpolation.x) * interpolation.y,
        referenceDistance,
        colorSum,
        weightSum
    );
    glimmerAccumulateRefractionTexel(
        basePixel + vec2(1.0, 1.0),
        interpolation.x * interpolation.y,
        referenceDistance,
        colorSum,
        weightSum
    );

    if (weightSum <= 0.0001) {
        return fallbackColor;
    }
    return colorSum / weightSum;
}

#endif
