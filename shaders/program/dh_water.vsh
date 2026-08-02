// Distant Horizons translucent vertex stage.
// It maps only DH water to Glimmer's reserved material ID.
#include "/lib/all_the_libs.glsl"
#include "/global/lighting.vsh"

void main() {
    init_generic();

    if (dhMaterialId == DH_BLOCK_WATER) {
        material = 1001.0;
    }
}
