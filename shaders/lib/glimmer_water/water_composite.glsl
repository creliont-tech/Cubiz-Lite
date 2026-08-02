/*
    Glimmer water surface and underwater composite for Cubiz Lite.
    Copyright (c) 2024 Josh Britain (jbritain)
    Licensed under the MIT License; see /licenses/Glimmer/LICENSE.

    Glimmer's wave, optical-depth, Fresnel, refraction, reflection, and
    caustic behavior is adapted to Kute's scene, depth, and sky buffers.
*/
#ifndef CUBIZ_GLIMMER_WATER_COMPOSITE
#define CUBIZ_GLIMMER_WATER_COMPOSITE

#include "/lib/glimmer_water/common.glsl"
#include "/lib/glimmer_water/wave_normals.glsl"
#include "/lib/glimmer_water/water_fog.glsl"
#include "/lib/glimmer_water/screen_refraction.glsl"
#include "/lib/glimmer_water/screen_reflection.glsl"

float glimmerCaustics(vec3 worldPosition) {
    vec2 coordinate = fract(
        worldPosition.xz / 4.0
        + vec2(frameTimeCounter * 0.1)
    );
    float firstSample = texture2D(causticsTex, coordinate).r;

    coordinate = fract(
        worldPosition.xz / 4.0
        - vec2(frameTimeCounter * 0.1, 0.0)
    );
    float secondSample = texture2D(causticsTex, coordinate).g;
    return clamp(min(firstSample, secondSample) * 2.0, 0.0, 1.0) * 4.0;
}

vec3 glimmerSkyReflection(
    vec3 reflectedViewDirection,
    vec3 surfacePlayerPosition,
    float skyLight
) {
    vec3 reflectedWorldDirection = normalize(
        mat3(gbufferModelViewInverse) * reflectedViewDirection
    );
    vec3 sunGlare = get_sun_glare(
        dot(reflectedViewDirection, sunPosN)
    );
    vec3 sky = get_sky_main(
        reflectedViewDirection,
        reflectedWorldDirection,
        sunGlare
    );

    #ifdef DIMENSION_OVERWORLD
        #ifdef ROUND_SUN
            sky += round_sun(dot(reflectedViewDirection, sunPosN));
        #endif
        #ifdef FANCY_CLOUDS
            if (reflectedWorldDirection.y > 0.0) {
                sky = get_clouds(
                    reflectedViewDirection,
                    surfacePlayerPosition
                        + reflectedWorldDirection * min(far, 512.0),
                    reflectedWorldDirection,
                    sunGlare,
                    sky
                );
            }
        #endif
    #endif

    return sky * smoothstep(0.1, 1.0, skyLight);
}

vec3 glimmerReflectionColor(
    vec3 surfaceViewPosition,
    vec3 surfacePlayerPosition,
    vec3 waveViewNormal,
    float skyLight,
    bool distantSurface
) {
    vec3 viewDirection = normalize(surfaceViewPosition);
    vec3 reflectedDirection = reflect(viewDirection, waveViewNormal);
    vec3 skyReflection = glimmerSkyReflection(
        reflectedDirection,
        surfacePlayerPosition,
        skyLight
    );
    vec3 reflectedColor = skyReflection;

    #if REFLECTION_MODE > 0
        if (!distantSurface) {
            #ifdef SSR_JITTER
                float jitter = max(bayer8(gl_FragCoord.xy), 0.125);
            #else
                float jitter = 1.0;
            #endif

            vec3 hitScreenPosition;
            float hitConfidence;
            if (glimmerTraceReflection(
                surfaceViewPosition,
                reflectedDirection,
                jitter,
                hitScreenPosition,
                hitConfidence
            )) {
                vec2 hitUV = glimmerClampUV(hitScreenPosition.xy);
                vec3 sceneReflection = texture2D(colortex0, hitUV).rgb;

                #ifdef FADE_REFLECTIONS
                    float edge = max(
                        abs(hitUV.x - 0.5),
                        abs(hitUV.y - 0.5)
                    ) * 2.0;
                    float edgeFade = 1.0 - smoothstep(0.82, 1.0, edge);
                #else
                    float edgeFade = 1.0;
                #endif

                reflectedColor = mix(
                    skyReflection,
                    sceneReflection,
                    edgeFade * hitConfidence
                );
            }
        }
    #endif

    // Glimmer's BRDF highlight is reduced to its water-only specular term.
    // Kute supplies the current sunlight or moonlight color.
    vec3 halfDirection = normalize(sunOrMoonPosN - viewDirection);
    float highlight = pow(
        max(dot(waveViewNormal, halfDirection), 0.0),
        96.0
    );
    highlight *= (1.0 - rainStrength * 0.8)
        * smoothstep(0.05, 1.0, skyLight);
    reflectedColor += SUN_DIRECT * highlight * 1.8;
    return reflectedColor;
}

vec3 glimmerSurfaceWater(
    vec2 screenUV,
    vec3 originalScene,
    vec4 waterData
) {
    bool surfaceIsDistant;
    float surfaceDepth = get_depth(screenUV, surfaceIsDistant);
    vec3 surfaceViewPosition = to_view_pos(
        vec3(screenUV, surfaceDepth),
        surfaceIsDistant
    );
    vec3 surfacePlayerPosition = to_player_pos(surfaceViewPosition);

    bool opaqueIsDistant;
    float opaqueDepth = get_depth_solid(screenUV, opaqueIsDistant);
    vec3 opaqueViewPosition = to_view_pos(
        vec3(screenUV, opaqueDepth),
        opaqueIsDistant
    );

    vec3 worldFaceNormal = glimmerDecodeNormal(waterData.xy);
    vec3 viewFaceNormal = normalize(
        mat3(gbufferModelView) * worldFaceNormal
    );
    vec3 viewDirection = normalize(surfaceViewPosition);
    float heightFactor = sqrt(
        sin(
            PI * 0.5
            * clamp(abs(dot(viewFaceNormal, viewDirection)), 0.0, 1.0)
        )
    );
    vec3 worldWaveNormal = glimmerWaterSurfaceNormal(
        surfacePlayerPosition,
        worldFaceNormal,
        heightFactor,
        max(bayer8(gl_FragCoord.xy), 0.125)
    );
    // Glimmer's animated field belongs to horizontal water surfaces. Blending
    // back to the packed face normal on vertical/underside faces prevents a
    // normal discontinuity where shoreline faces meet the top surface.
    float horizontalSurface = smoothstep(
        0.78,
        0.98,
        worldFaceNormal.y
    );
    worldWaveNormal = normalize(mix(
        worldFaceNormal,
        worldWaveNormal,
        horizontalSurface
    ));
    bool cameraUnderwater = isEyeInWater == 1;
    vec3 waveViewNormal = normalize(
        mat3(gbufferModelView) * worldWaveNormal
    );
    if (!cameraUnderwater
        && dot(waveViewNormal, -viewDirection) < 0.0) {
        waveViewNormal = -waveViewNormal;
    }
    // GLSL refract expects the interface normal to oppose the incident ray.
    // The packed Minecraft face normal is not automatically face-forwarded on
    // underwater back faces, so orient a dedicated copy for refraction only.
    vec3 refractionViewNormal = waveViewNormal;
    if (dot(refractionViewNormal, viewDirection) > 0.0) {
        refractionViewNormal = -refractionViewNormal;
    }

    vec3 refractedColor = originalScene;
    bool totalInternalReflection = false;

    #ifdef REFRACTION
        if (!surfaceIsDistant) {
            if (cameraUnderwater) {
                vec3 refractedDirection = refract(
                    viewDirection,
                    refractionViewNormal,
                    1.33
                );
                float refractedLengthSquared = dot(
                    refractedDirection,
                    refractedDirection
                );

                if (refractedLengthSquared > 0.00001) {
                    refractedDirection *= inversesqrt(
                        refractedLengthSquared
                    );
                    float traceDistance = clamp(
                        distance(
                            surfaceViewPosition,
                            opaqueViewPosition
                        ) * 1.25 + 2.0,
                        8.0,
                        min(far, 96.0)
                    );
                    vec2 refractedUV;
                    float refractedDepth;
                    vec3 refractedOpaqueViewPosition;
                    vec3 refractedSky = glimmerSkyReflection(
                        refractedDirection,
                        surfacePlayerPosition,
                        waterData.z
                    );

                    if (glimmerTraceRefraction(
                        surfaceViewPosition,
                        refractedDirection,
                        traceDistance,
                        refractedUV,
                        refractedDepth,
                        refractedOpaqueViewPosition
                    )) {
                        refractedColor = glimmerSampleRefractedScene(
                            refractedUV,
                            refractedDepth,
                            refractedSky
                        );
                        opaqueViewPosition =
                            refractedOpaqueViewPosition;
                    } else {
                        refractedColor = refractedSky;
                    }
                } else {
                    totalInternalReflection = true;
                }
            } else {
                vec3 refractedDirection = refract(
                    viewDirection,
                    refractionViewNormal,
                    1.0 / 1.33
                );

                if (dot(refractedDirection, refractedDirection) > 0.00001) {
                    float baseWaterDistance = min(
                        distance(
                            surfaceViewPosition,
                            opaqueViewPosition
                        ),
                        96.0
                    );
                    vec3 refractedViewPosition = surfaceViewPosition
                        + normalize(refractedDirection)
                        * max(baseWaterDistance, 1.0);
                    vec2 projectedUV = view_screen(
                        refractedViewPosition,
                        false
                    ).xy;

                    // The exterior path keeps the continuity filtering used to
                    // stabilize shorelines in the current Cubiz Lite build.
                    vec2 maximumOffset = resolutionInv * 14.0;
                    vec2 candidateUV = screenUV + clamp(
                        projectedUV - screenUV,
                        -maximumOffset,
                        maximumOffset
                    );
                    candidateUV = glimmerClampUV(candidateUV);

                    bool candidateSurfaceIsDistant;
                    float candidateSurfaceDepth = get_depth(
                        candidateUV,
                        candidateSurfaceIsDistant
                    );
                    vec3 candidateSurfaceViewPosition = to_view_pos(
                        vec3(candidateUV, candidateSurfaceDepth),
                        candidateSurfaceIsDistant
                    );

                    bool candidateOpaqueIsDistant;
                    float candidateOpaqueDepth = get_depth_solid(
                        candidateUV,
                        candidateOpaqueIsDistant
                    );
                    vec3 candidateOpaqueViewPosition = to_view_pos(
                        vec3(candidateUV, candidateOpaqueDepth),
                        candidateOpaqueIsDistant
                    );

                    float candidateWaterDistance = min(
                        distance(
                            candidateSurfaceViewPosition,
                            candidateOpaqueViewPosition
                        ),
                        96.0
                    );
                    float relativeDepthChange = abs(
                        candidateWaterDistance - baseWaterDistance
                    ) / max(
                        max(candidateWaterDistance, baseWaterDistance),
                        1.0
                    );
                    float waterContinuity = smoothstep(
                        0.35,
                        0.9,
                        texture2D(colortex4, candidateUV).a
                    );
                    float behindSurface = smoothstep(
                        0.02,
                        0.35,
                        length(candidateOpaqueViewPosition)
                            - length(candidateSurfaceViewPosition)
                    );
                    float depthContinuity = 1.0 - smoothstep(
                        0.28,
                        0.82,
                        relativeDepthChange
                    );
                    float edgeMargin = min(
                        min(candidateUV.x, candidateUV.y),
                        min(1.0 - candidateUV.x, 1.0 - candidateUV.y)
                    );
                    float screenContinuity = smoothstep(
                        0.0,
                        max(
                            resolutionInv.x,
                            resolutionInv.y
                        ) * 3.0,
                        edgeMargin
                    );
                    float refractionConfidence = waterContinuity
                        * behindSurface
                        * depthContinuity
                        * screenContinuity;

                    vec3 candidateColor = texture2D(
                        colortex0,
                        candidateUV
                    ).rgb;
                    refractedColor = mix(
                        originalScene,
                        candidateColor,
                        refractionConfidence
                    );
                    opaqueViewPosition = mix(
                        opaqueViewPosition,
                        candidateOpaqueViewPosition,
                        refractionConfidence
                    );
                } else {
                    totalInternalReflection = true;
                }
            }
        }
    #endif

    float waterDistance = min(
        distance(surfaceViewPosition, opaqueViewPosition),
        96.0
    );
    float waterInterior = clamp(glimmerWaterBlend, 0.0, 1.0);
    float skyVisibility = smoothstep(0.05, 1.0, waterData.z)
        * (1.0 - rainStrength * 0.45);
    vec3 exteriorFoggedColor = glimmerWaterFog(
        refractedColor,
        surfaceViewPosition,
        opaqueViewPosition,
        vec3(skyVisibility)
    );
    refractedColor = mix(
        exteriorFoggedColor,
        refractedColor,
        waterInterior
    );

    #ifdef CAUSTICS
        vec3 floorWorldPosition = to_player_pos(opaqueViewPosition)
            + cameraPosition;
        float causticPattern = glimmerCaustics(floorWorldPosition);
        float shallowVisibility = exp(-waterDistance * 0.16)
            * skyVisibility
            * (1.0 - waterInterior)
            * max(dayStrength + sunriseStrength + sunsetStrength, 0.15);
        float causticLight = clamp(
            0.78 + causticPattern * 0.16,
            0.72,
            1.28
        );
        refractedColor *= mix(
            1.0,
            causticLight,
            shallowVisibility
        );
    #endif

    vec3 reflection = glimmerReflectionColor(
        surfaceViewPosition,
        surfacePlayerPosition,
        waveViewNormal,
        waterData.z,
        surfaceIsDistant
    );

    float facing = clamp(
        abs(dot(waveViewNormal, -viewDirection)),
        0.0,
        1.0
    );
    float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
    if (totalInternalReflection) {
        fresnel = 1.0;
    }

    return mix(refractedColor, reflection, fresnel);
}

vec3 glimmerUnderwater(
    vec2 screenUV,
    vec3 sceneColor
) {
    bool visibleIsDistant;
    float visibleDepth = get_depth(screenUV, visibleIsDistant);
    vec3 visibleViewPosition = to_view_pos(
        vec3(screenUV, visibleDepth),
        visibleIsDistant
    );

    float skyVisibility = clamp(
        float(eyeBrightnessSmooth.y) / 240.0,
        0.08,
        1.0
    );
    vec3 underwaterColor = glimmerWaterFog(
        sceneColor,
        vec3(0.0),
        visibleViewPosition,
        vec3(skyVisibility)
    );

    #ifdef CAUSTICS
        if (visibleDepth < 1.0) {
            vec3 visibleWorldPosition = to_player_pos(visibleViewPosition)
                + cameraPosition;
            float pattern = glimmerCaustics(visibleWorldPosition);
            float distanceFade = exp(-length(visibleViewPosition) * 0.07);
            float daylight = max(
                dayStrength + sunriseStrength + sunsetStrength,
                0.1
            ) * (1.0 - rainStrength * 0.65);
            float causticLight = clamp(
                0.8 + pattern * 0.14,
                0.74,
                1.24
            );
            underwaterColor *= mix(
                1.0,
                causticLight,
                distanceFade * daylight * skyVisibility
            );
        }
    #endif

    return mix(
        sceneColor,
        underwaterColor,
        clamp(glimmerWaterBlend, 0.0, 1.0)
    );
}

#endif
