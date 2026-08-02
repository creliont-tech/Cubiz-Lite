// Cubiz Lite translucent vertex stage.
// Kute supplies the shared lighting transform; Glimmer water geometry remains
// flat here because Glimmer v1.5.2 ships its vertex displacement disabled.
#include "/lib/all_the_libs.glsl"
#include "/global/lighting.vsh"

void main() {
    init_generic();

    // Water animation is generated from Glimmer's procedural surface normal in
    // composite1. Leaving the mesh undisplaced prevents shoreline cracks.
}
