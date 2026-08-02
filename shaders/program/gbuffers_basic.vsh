#include "/lib/all_the_libs.glsl"

#include "/global/lighting.vsh"

flat varying vec4 glcolor_flat;
void main() {
	
	init_generic();
    glcolor_flat = glcolor;    
}
