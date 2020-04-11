uniform samplerCube envMap;
uniform mat4 uEnvironmentTransform;
uniform float uEnvBrightness;
uniform vec2 uEnvironmentSize;

varying vec3 vViewNormal;

mat3 getEnvironmentTransfrom(mat4 transform) {
    vec3 x = vec3(transform[0][0], transform[1][0], transform[2][0]);
    vec3 y = vec3(transform[0][1], transform[1][1], transform[2][1]);
    vec3 z = vec3(transform[0][2], transform[1][2], transform[2][2]);
    mat3 m = mat3(x,y,z);
    return m;
}

vec3 cubemapSeamlessFixDirection(const in vec3 direction, const in float scale ){
    vec3 dir = direction;
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    float M = max(max(abs(dir.x), abs(dir.y)), abs(dir.z));

    if (abs(dir.x) != M) dir.x *= scale;
    if (abs(dir.y) != M) dir.y *= scale;
    if (abs(dir.z) != M) dir.z *= scale;

    return dir;
}

vec4 textureCubemap(const in samplerCube tex, const in vec3 dir){
    vec4 rgba = textureCube(tex, dir);
    return LogLuvToLinear(rgba);
}

// Seamless cubemap for background
vec4 textureCubeFixed(const in samplerCube tex, const in vec3 direction){
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    float scale = 1.0 - 1.0 / uEnvironmentSize[0];
    vec3 dir = cubemapSeamlessFixDirection(direction, scale);
    return textureCubemap(tex, dir);
}

void main(){
    vec3 direction = normalize(vViewNormal);
    direction = getEnvironmentTransfrom(uEnvironmentTransform) * direction;
    vec4 samplerColor = uEnvBrightness * textureCubeFixed(envMap, direction);
    
    gl_FragColor = samplerColor;
    #include <tonemapping_fragment>
    #include <encodings_fragment>
}
