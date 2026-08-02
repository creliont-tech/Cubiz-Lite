// Full-screen vertex stage for Glimmer water integration.
#include "/lib/all_the_libs.glsl"
#include "/global/light_colors.vsh"

void main() {
    init_colors();
    gl_Position = ftransform();
}
