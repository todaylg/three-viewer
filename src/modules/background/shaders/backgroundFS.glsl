uniform samplerCube envMap;
uniform mat3 uEnvironmentTransform;
uniform float uEnvBrightness;
uniform vec2 uEnvironmentSize;

varying vec3 vViewNormal;

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
    direction = uEnvironmentTransform * direction;
    vec4 samplerColor = uEnvBrightness * textureCubeFixed(envMap, direction);
    
    gl_FragColor = samplerColor;
    #include <tonemapping_fragment>
    #include <encodings_fragment>
}
