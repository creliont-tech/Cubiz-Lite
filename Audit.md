# Cubiz Lite Technical Audit

> **Version:** Current Development Build  
> **Document Type:** Technical Audit  
> **Status:** Informational

---

# Table of Contents

- [Overview](#overview)
- [Repository Statistics](#repository-statistics)
- [Project Composition](#project-composition)
- [Subsystem Matrix](#subsystem-matrix)

---

# Overview

This document explains the technical composition of **Cubiz Lite**.

Its purpose is **not** to claim originality for third-party work, but to clearly distinguish between:

- original Cubiz Lite development;
- systems adapted from **Kute**;
- systems adapted from **Glimmer**.

Every subsystem listed below was compared against the retained source trees used during development rather than relying solely on project credits or licensing information.

---

# Repository Statistics

| Item | Count |
|------|------:|
| Total shader files | **281** |
| Byte-identical to Kute | **237** |
| Modified Kute files | **29** |
| New shader files/resources | **15** |

### Additional observations

- The **caustics texture** is byte-for-byte identical to Glimmer's original resource.
- No active **Mellow** shader code remains.
- Mellow only exists inside preserved licensing and provenance files.

---

# Project Composition

At a high level, Cubiz Lite consists of three major parts.

## Kute

Provides the majority of the rendering framework, including:

- renderer architecture
- lighting
- sky
- clouds
- fog
- bloom
- post-processing
- most rendering passes

---

## Glimmer

Provides the visual foundation for water rendering, including:

- wave generation
- Fresnel response
- optical water behavior
- absorption
- scattering
- underwater appearance
- caustics
- screen-space water reflections

---

## Original Cubiz Lite

Cubiz Lite contributes the systems required to integrate Glimmer's water renderer into Kute's lightweight GLSL 1.20 / Iris pipeline.

These additions primarily focus on:

- compatibility
- renderer integration
- buffer management
- pipeline stabilization
- underwater rendering improvements
- artifact reduction

Cubiz Lite does **not** replace Kute's renderer with Glimmer's renderer.

Instead, it builds a compatibility layer that allows selected Glimmer systems to operate correctly inside Kute.

---

# Subsystem Matrix

The following table summarizes the origin of every major subsystem.

| Subsystem | Provenance |
|------------|------------|
| Folder architecture and dimension wrappers | **Kute** |
| Terrain rendering | **Kute** |
| Entity rendering | **Kute** |
| Hand rendering | **Kute** |
| Particle rendering | **Kute** |
| Glint rendering | **Kute** |
| Damage rendering | **Kute** |
| Sky texture passes | **Kute** |
| General lighting | **Kute** |
| Minecraft lightmaps | **Kute** |
| Ambient / minimum light | **Kute** |
| Directional lighting ("shadows") | **Kute** *(Cubiz Lite added configurable strength)* |
| Minecraft shadow-map rendering | **Not Present** |
| Sunlight colors | **Kute** |
| Moonlight colors | **Kute** |
| Dimension lighting | **Kute** |
| Sky gradient | **Kute** |
| Stars | **Kute** |
| Aurora | **Kute** |
| End sky | **Kute** |
| Clouds | **Kute** |
| Terrain fog | **Kute** |
| Distance fog | **Kute** |
| Height fog | **Kute** |
| Lava fog | **Kute** |
| Powder snow fog | **Kute** |
| Blindness fog | **Kute** |
| Kute underwater fog | **Removed by Cubiz Lite** |
| Weather | **Kute** |
| Rain rendering | **Kute** |
| Vegetation animation | **Kute** |
| Distant Horizons terrain | **Kute** |
| Distant Horizons water bridge | **Original Cubiz Lite** |
| Water material detection | **Original Cubiz Lite** |
| Water material mask | **Original Cubiz Lite** |
| Wave height | **Glimmer** |
| Wave normals | **Glimmer** |
| Water parallax | **Glimmer** *(ported to GLSL 1.20)* |
| Water vertex displacement | **Disabled** |
| Water absorption | **Glimmer** |
| Water scattering | **Glimmer** *(using Kute lighting inputs)* |
| Fresnel response | **Glimmer** |
| Refraction indices | **Glimmer** |
| Above-water refraction | **Glimmer + Original Cubiz Lite validation** |
| Underwater refraction | **Original Cubiz Lite** |
| Screen-space reflections | **Glimmer + Original Cubiz Lite validation** |
| Sky reflections | **Glimmer + Kute sky renderer** |
| Water highlights | **Glimmer + Original Cubiz Lite integration** |
| Underwater fog | **Glimmer + Original Cubiz Lite adaptation** |
| Water transition | **Original Cubiz Lite** |
| Caustic pattern | **Glimmer** |
| Caustic integration | **Original Cubiz Lite** |
| Bloom | **Kute** |
| Exposure | **Kute** |
| Tone mapping | **Kute** *(plus Cubiz Lite divide-by-zero guard)* |
| Color grading | **Kute** |
| Saturation | **Kute** |
| Contrast | **Kute** |
| Vibrance | **Kute** |
| Vignette | **Kute** |
| Film grain | **Kute** |
| Sharpening | **Kute** |
| SMAA | **Kute** |
| TAA | **Removed by Cubiz Lite** |
| SSAO | **Kute** *(disabled by default)* |
| God Rays | **Kute** |
| Core rendering buffers | **Kute** |
| Water material buffer | **Original Cubiz Lite** |
| GLSL 1.20 / Iris compatibility | **Original Cubiz Lite** |

---

The following sections describe each category in detail:

- **Original Cubiz Lite**
- **Adapted from Glimmer**
- **Adapted from Kute**

---

# Original Cubiz Lite

This section describes the systems that were written specifically for **Cubiz Lite**.

These components were **not found in either retained Kute or Glimmer source tree in their current form**. While some techniques are well-known in real-time rendering, the implementations listed below were developed specifically to integrate and stabilize Glimmer-style water inside Kute's lightweight GLSL 1.20 / Iris rendering pipeline.

---

## Water Material & Buffer Bridge

Cubiz Lite introduces a dedicated **water-only material buffer** stored in `colortex4`.

The buffer records:

- Octahedrally packed surface normals
- Skylight values
- An exact water / non-water mask

Only water pixels write to this attachment, while all other translucent surfaces explicitly write zero.

### Why?

Glimmer's original renderer relies on a completely different G-buffer layout and material encoding. Those structures cannot be copied directly into Kute's rendering pipeline.

---

## Strict Material Buffer Lifecycle

Cubiz Lite adds several safety mechanisms for the water material buffer:

- `colortex4Clear=true`
- Explicit four-component clear color
- Disabled blending on the water attachment
- Explicit zero writes for non-water translucent fragments
- Pixel-center material reads

### Why?

Without these safeguards, stale data from previous frames could remain inside the buffer, producing:

- ghost water
- invalid masks
- incorrect underwater rendering

---

## Dedicated Water Composite Pass

Cubiz Lite introduces an entirely new rendering stage: **composite1**.

This pass:

- reads the completed Kute scene;
- reads the dedicated water material buffer;
- renders only valid water pixels;
- applies underwater effects;
- executes before bloom and tone mapping.

### Why?

Glimmer's translucent composite expects:

- its own G-buffer layout;
- its own lighting model;
- GLSL 4.30 features;
- its own atmosphere system.

A direct copy was therefore impossible.

---

## Depth-Consistent Underwater Refraction

One of Cubiz Lite's largest original rendering contributions is a completely new underwater refraction tracer.

The algorithm performs:

- sixteen quadratic-distance ray steps;
- front-to-back depth crossing detection;
- five binary refinement passes;
- view-space reconstruction;
- geometric validation of the hit point.

### Why?

Glimmer's original implementation projects a refracted ray using only the depth stored at the original screen pixel.

During integration into Kute's pipeline this produced:

- torn geometry;
- unstable intersections;
- white bands;
- incorrect underwater refraction.

Cubiz Lite replaces that approach with a depth-consistent ray tracer while preserving Glimmer's visual style.

> Screen-space ray marching itself is **not claimed as an original Cubiz invention**. The originality lies in this implementation and its integration within Cubiz Lite.

---

## Refraction Depth Validation

Cubiz Lite validates every potential refraction hit.

Checks include:

- camera-space direction;
- framebuffer bounds;
- opaque geometry confirmation;
- forward intersection tests;
- projection-dependent tolerance.

### Why?

A simple depth crossing is insufficient.

Without validation the renderer can incorrectly select:

- unrelated silhouettes;
- foreground blocks;
- distant geometry.

---

## Edge-Aware Scene Sampling

Cubiz Lite replaces ordinary bilinear sampling with a depth-aware neighborhood filter.

The filter:

- reconstructs neighboring depths;
- compares view-space distances;
- rejects incompatible samples;
- prevents foreground and sky colors from bleeding across geometry edges.

### Why?

Simple bilinear filtering produced bright seams around discontinuities in the depth buffer.

---

## Pixel-Center Sampling

GLSL 1.20 does not provide the same texel-fetch functionality used by Glimmer.

Cubiz Lite therefore introduces helper functions that force all material and depth reads to occur at exact texel centers.

### Benefits

- Stable material masks
- Accurate depth sampling
- Reduced interpolation artifacts
- Fewer underwater bands

---

## Screen Bounds Handling

Cubiz Lite adds dedicated framebuffer-edge protection.

The implementation:

- validates screen coordinates;
- clamps UVs one pixel inside the framebuffer;
- rejects invalid samples.

### Why?

Some drivers duplicate or corrupt colors when sampling exactly at framebuffer borders.

---

## Continuous Water Normals

Minecraft water consists of:

- top faces;
- side faces;
- bottom faces.

Glimmer's procedural waves primarily target horizontal surfaces.

Cubiz Lite therefore adds:

- orientation-aware normal blending;
- shoreline normal correction;
- separate refraction normals;
- underwater back-face correction.

This keeps lighting continuous across all water geometry.

---

## Shoreline Continuity Validation

Cubiz Lite validates:

- water continuity;
- surrounding geometry;
- local depth variation;
- maximum refraction displacement;
- framebuffer proximity.

### Why?

Without these checks, refraction could incorrectly cross:

- shorelines;
- disconnected water bodies;
- unrelated nearby geometry.

---

## Reflection Confidence System

Cubiz Lite extends Glimmer's screen-space reflections with additional validation.

New checks include:

- view-space alignment;
- perpendicular distance;
- water-floor rejection;
- screen-edge confidence;
- pixel-center depth sampling.

These additions compensate for the reduced information available inside Kute's G-buffer.

---

## Kute ↔ Glimmer Compatibility Layer

Cubiz Lite provides the integration layer that connects Glimmer water with Kute's renderer.

The adapter supplies:

- Kute sky gradients;
- Kute clouds;
- Kute sunlight;
- Kute moonlight;
- Kute rain response;
- Kute skylight visibility;
- simplified water highlights.

Rather than replacing Kute's renderer, Cubiz Lite allows Glimmer's water systems to operate within it.

---

# Adapted from Glimmer

This section documents the systems derived from **Glimmer**.

Cubiz Lite preserves Glimmer's visual approach to water while adapting it to Kute's renderer and GLSL 1.20 / Iris compatibility requirements.

The goal was **not** to replace Kute's renderer, but to integrate Glimmer's water into an entirely different rendering pipeline.

---

# Procedural Waves

Cubiz Lite uses Glimmer's procedural wave system.

This includes:

- multi-octave wave height generation;
- wave drag;
- frequency progression;
- derivative-based normal generation;
- optional parallax.

Although the implementation has been rewritten for GLSL 1.20 and renamed to match Cubiz Lite's codebase, the underlying wave algorithm originates from Glimmer.

---

# Normal Packing & Rotation

Cubiz Lite adapts Glimmer's:

- octahedral normal encoding;
- octahedral normal decoding;
- Rodrigues-style normal rotation.

The surrounding compatibility layer, material handling, and sampling helpers are original Cubiz Lite code.

---

# Water Absorption & Scattering

Cubiz Lite preserves Glimmer's optical water model.

This includes:

- absorption coefficients;
- scattering coefficients;
- exponential transmittance;
- underwater light scattering.

However, Cubiz Lite replaces Glimmer's original atmospheric inputs with data from Kute, including:

- sunlight;
- skylight;
- rain response;
- ambient lighting.

---

# Fresnel & Refraction

The following optical properties remain based on Glimmer:

- water index of refraction (IOR);
- Fresnel reflection;
- total internal reflection;
- above-water refraction behavior;
- underwater refraction model.

Cubiz Lite does **not** replace these optical equations.

Instead, it introduces new tracing and validation around them.

---

# Screen-Space Reflections

Cubiz Lite retains Glimmer's screen-space reflection approach.

The original algorithm still performs:

- ray projection;
- screen-space marching;
- depth testing;
- hit refinement.

Cubiz Lite extends this system with:

- confidence testing;
- depth validation;
- compatibility fixes;
- GLSL 1.20 adaptation;
- Kute buffer integration.

---

# Sky Reflections

Reflection behavior remains based on Glimmer.

When reflections fail or leave the screen, Cubiz Lite falls back to Kute's sky renderer instead of Glimmer's original atmosphere.

This preserves Glimmer's reflection logic while matching the visual style of Kute.

---

# Water Depth Appearance

Water coloration remains primarily derived from Glimmer's optical-depth model.

This includes:

- shallow transparency;
- deep-water coloration;
- underwater color transitions.

These effects replace Kute's simpler RGB water tint.

---

# Caustics

Cubiz Lite uses Glimmer's animated caustic pattern.

The included `caustics.png` texture is identical to the original Glimmer resource.

However, Cubiz Lite rewrites:

- placement;
- intensity;
- integration with lighting.

This adaptation is necessary because Glimmer's original implementation depends on rendering systems that are not present in Kute.

---

# Underwater Rendering

The overall underwater appearance remains based on Glimmer.

This includes:

- optical absorption;
- scattering;
- underwater color;
- skylight response;
- caustics.

Cubiz Lite contributes:

- depth reconstruction;
- renderer integration;
- compatibility;
- transition smoothing.

---

# Imported Settings

The following user settings originate from Glimmer:

- `REFLECTION_MODE`
- `SSR_STEPS`
- `FADE_REFLECTIONS`
- `SSR_JITTER`
- `REFRACTION`
- `CAUSTICS`
- `WATER_SCATTERING_MOD`
- `WATER_ABSORPTION_MOD`
- `WAVE_DEPTH`
- `WATER_PARALLAX`
- `WATER_PARALLAX_SAMPLES`

These options preserve Glimmer's configuration while integrating with Cubiz Lite.

---

# Features Not Imported

Cubiz Lite intentionally does **not** include Glimmer's complete rendering pipeline.

The following systems were **not** transferred:

- Atmospheric renderer
- Cloud renderer
- PBR material pipeline
- BRDF system
- Shadow renderer
- Temporal filtering
- Infinite ocean system
- Active water mesh displacement

As a result, Cubiz Lite should **not** be considered a direct copy of Glimmer.

Likewise, the visual appearance of the water should **not** be described as entirely original to Cubiz Lite.

Instead, Cubiz Lite combines Glimmer's optical water model with a significant amount of original integration, compatibility, and stabilization work.

---

# Adapted from Kute

This section describes the systems inherited from **Kute**.

Kute serves as the primary rendering foundation of Cubiz Lite. Most of the non-water renderer remains based on Kute, while Cubiz Lite removes, modifies, or extends selected components where necessary to support the integrated water pipeline.

---

# Project Architecture

Cubiz Lite retains Kute's overall project structure.

This includes:

- `program/`
- `world-1/`
- `world0/`
- `world1/`
- `global/`
- `lib/`

The dimension wrapper files remain almost entirely identical to Kute.

The only major architectural addition is the new **composite1** rendering stage introduced by Cubiz Lite.

---

# Rendering Pipeline

The following rendering passes originate from Kute:

- Terrain rendering
- Entity rendering
- Player hand rendering
- Held items
- Basic rendering
- Textured rendering
- Particle rendering
- Armor glint
- Spider eyes
- Damaged block rendering
- Weather rendering
- Cloud rendering

Several vertex programs differ only because Cubiz Lite removed Kute's temporal projection jitter.

---

# Lighting

Cubiz Lite continues using Kute's lighting system.

This includes:

- Minecraft lightmap handling
- Torch lighting
- Ambient skylight
- Minimum light
- Handheld light sources
- Day lighting
- Sunrise lighting
- Sunset lighting
- Night lighting
- Nether lighting
- End lighting
- Entity lighting
- Hand lighting

No replacement lighting engine has been introduced.

---

# Directional Lighting

Despite the settings menu referring to "Directional Shadows", Cubiz Lite does **not** render Minecraft shadow maps.

Instead, this system remains Kute's lightweight approximation based on:

- surface normals;
- sunlight direction;
- skylight visibility;
- fake shadow attenuation.

Cubiz Lite contributes only one functional addition:

- configurable **Shadow Strength**.

---

# Sky & Atmosphere

The sky renderer remains Kute.

This includes:

- Sky gradients
- Sunrise colors
- Sunset colors
- Sun rendering
- Moon rendering
- Stars
- Aurora
- Nether sky
- End sky
- Rain desaturation
- Atmospheric darkening

Cubiz Lite intentionally preserves Kute's visual identity rather than replacing it with Glimmer's atmosphere.

---

# Fog

All non-water fog continues to use Kute.

Supported fog types include:

- Distance fog
- Height fog
- Border fog
- Lava fog
- Powder snow fog
- Blindness
- Darkness

The original Kute underwater fog has been removed to avoid conflicting with Glimmer's underwater renderer.

---

# Weather

Weather rendering remains based on Kute.

This includes:

- Rain rendering
- Rain direction
- Rain intensity
- Weather darkening

No major functional changes have been introduced.

---

# Vegetation Animation

Cubiz Lite preserves Kute's vegetation animation system.

Supported animated blocks include:

- Leaves
- Grass
- Tall grass
- Crops
- Flowers
- Other supported foliage

The original Kute water animation has been removed because water rendering is now handled separately.

---

# Distant Horizons

Cubiz Lite continues to use Kute's Distant Horizons implementation.

This includes:

- Terrain rendering
- Terrain depth selection
- Transition dithering
- Terrain noise

Only the **water bridge** connecting Distant Horizons to Glimmer's water renderer is original Cubiz Lite code.

---

# Bloom

Bloom remains Kute's implementation.

Cubiz Lite has **not** introduced a new bloom algorithm.

The following systems remain unchanged:

- Bloom pyramid
- Blur passes
- Gaussian filtering
- Final bloom composition

---

# Exposure & Tone Mapping

Cubiz Lite retains Kute's exposure system.

Current exposure remains fully manual.

No automatic eye adaptation or temporal exposure system exists.

Supported tone mapping operators include:

- ACES Film
- Reinhard Jodie
- ACES
- Hejl

Cubiz Lite contributes only a small divide-by-zero safeguard inside the tone mapping library.

---

# Final Image Processing

The following post-processing effects remain Kute implementations:

- Vibrance
- Saturation
- Contrast
- Minimum output colors
- Vignette
- Film grain
- Bayer dithering
- CAS sharpening

Cubiz Lite preserves these systems without replacing them.

---

# Anti-Aliasing & Optional Effects

Current implementation:

| Feature | Status |
|----------|--------|
| SMAA | Kute |
| SSAO | Kute (disabled by default) |
| God Rays | Kute |
| TAA | Removed by Cubiz Lite |

Rather than replacing TAA with another temporal solution, Cubiz Lite removes the incomplete history pipeline to improve stability.

---

# Core Utilities

Most low-level utility code remains inherited from Kute.

This includes:

- Noise textures
- SMAA lookup textures
- Coordinate transforms
- Distant Horizons helpers
- Noise functions
- Color utilities
- Phase functions
- Common uniforms

Cubiz Lite builds on top of these utilities rather than replacing them.

---

# Summary

Kute remains the primary rendering foundation of Cubiz Lite.

It provides:

- renderer architecture;
- lighting;
- atmosphere;
- sky;
- clouds;
- fog;
- bloom;
- post-processing;
- utility libraries.

Cubiz Lite intentionally preserves these systems while extending the renderer with original integration code that enables Glimmer's water to operate inside Kute's lightweight GLSL 1.20 / Iris pipeline.

---

# Final Conclusion

Cubiz Lite is **not** a shader pack written entirely from scratch.

It is also **not** a simple merge of existing projects.

Instead, Cubiz Lite combines carefully selected technologies from multiple open-source shader packs with original engineering work focused on compatibility, integration, and rendering stability.

---

# What Comes from Kute

Kute provides the foundation of the renderer, including:

- Project architecture
- Rendering pipeline
- Lighting
- Sky and atmosphere
- Clouds
- Fog
- Bloom
- Tone mapping
- Post-processing
- Utility libraries

Most non-water rendering continues to rely on Kute.

---

# What Comes from Glimmer

Glimmer provides the visual and optical foundation of the water renderer, including:

- Procedural waves
- Fresnel response
- Refraction model
- Water absorption
- Water scattering
- Caustics
- Underwater appearance
- Screen-space reflection model

Cubiz Lite intentionally preserves Glimmer's overall water appearance.

---

# Original Cubiz Lite

Cubiz Lite's primary contribution is the engineering work required to integrate Glimmer's water into Kute's lightweight GLSL 1.20 / Iris rendering pipeline.

This includes:

- Water material buffer
- Material-buffer lifecycle
- Dedicated water composite pass
- Underwater refraction tracer
- Refraction validation
- Reflection validation
- Edge-aware scene sampling
- Pixel-center sampling
- Continuous water normals
- Shoreline continuity validation
- Distant Horizons water bridge
- Stable non-temporal rendering pipeline
- GLSL 1.20 compatibility
- Iris compatibility
- Numerous stability and rendering fixes

These systems allow two independent rendering architectures to operate together while preserving the strengths of both.

---

# Design Philosophy

Cubiz Lite does not attempt to replace every rendering system.

Instead, it focuses on:

- keeping Kute's lightweight renderer;
- preserving Glimmer's water quality;
- removing incompatible systems;
- replacing unstable behavior;
- introducing only the integration necessary for both renderers to function together.

The objective is stability, compatibility, and visual consistency rather than rewriting every subsystem.

---

# Attribution

Cubiz Lite would not exist without the work of the original shader authors.

The project preserves all required copyright notices and license files.

Every major subsystem remains credited to its original source where applicable.

Original Cubiz Lite code is limited to the integration, compatibility, and stabilization work documented in this audit.

---

# Closing Statement

Cubiz Lite should be viewed as an integration project rather than a completely original rendering engine.

Its originality lies in the technical work required to bridge two independent shader architectures into a stable renderer for Iris and GLSL 1.20 while maintaining high visual quality.

The purpose of this document is to accurately describe the origin of every major subsystem, acknowledge third-party contributions, and clearly distinguish original Cubiz Lite development from adapted work.
