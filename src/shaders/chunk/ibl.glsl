// IBL
#preImport <precomputeLight>
#preImport <computeDiffuseSPH>

mat3 getEnvironmentTransfrom(mat4 transform) {
    vec3 x = vec3(transform[0][0], transform[1][0], transform[2][0]);
    vec3 y = vec3(transform[0][1], transform[1][1], transform[2][1]);
    vec3 z = vec3(transform[0][2], transform[1][2], transform[2][2]);
    mat3 m = mat3(x,y,z);
    return m;
}

#ifdef PANORAMA
    #preImport <panoramaSampler>
#endif

#ifdef MOBILE
    #preImport <integrateBRDFMobile>
#else
vec3 integrateBRDF(const in vec3 specular, const in float roughness, const in float NoV, const in float f90) {
    vec4 rgba = texture2D(uIntegrateBRDF, vec2(NoV, roughness));
    float b = (rgba[3] * 65280.0 + rgba[2] * 255.0);
    float a = (rgba[1] * 65280.0 + rgba[0] * 255.0);
    const float div = 1.0 / 65535.0;
    return (specular * a + b * f90) * div;
}
#endif

// frostbite, lagarde paper p67
// http://www.frostbite.com/wp-content/uploads/2014/11/course_notes_moving_frostbite_to_pbr.pdf
float linRoughnessToMipmap(float roughnessLinear){
    return sqrt(roughnessLinear);
}

vec3 prefilterEnvMap(const in float rLinear, const in vec3 R) {
    vec3 dir = R;
    float lod = linRoughnessToMipmap(rLinear) * uEnvironmentLodRange[1]; //(uEnvironmentMaxLod - 1.0);
    lod = min(uEnvironmentLodRange[0], lod);
#ifdef CUBEMAP_LOD
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    float scale = 1.0 - exp2(lod) / uEnvironmentSize[0];
    vec3 absDir = abs(dir);
    float M = max(max(absDir.x, absDir.y), absDir.z);
    // cubemapSeamlessFixDirection
    if (absDir.x != M) dir.x *= scale;
    if (absDir.y != M) dir.y *= scale;
    if (absDir.z != M) dir.z *= scale;
	return LogLuvToLinear(textureCubeLodEXT(envMap, dir, lod)).rgb;
#else
    return LogLuvToLinear(panoramaSampler(envMap, uEnvironmentSize, R, lod, uEnvironmentLodRange[0])).rgb;
	#endif

}

// From Sebastien Lagarde Moving Frostbite to PBR page 69
// We have a better approximation of the off specular peak
// but due to the other approximations we found this one performs better.
// N is the normal direction
// R is the mirror vector
// This approximation works fine for G smith correlated and uncorrelated
vec3 getSpecularDominantDir(const in vec3 N, const in vec3 R, const in float realRoughness) {
    float smoothness = 1.0 - realRoughness;
    float lerpFactor = smoothness * (sqrt(smoothness) + realRoughness);
    return mix(N, R, lerpFactor);
}

vec3 getPrefilteredEnvMapColor(const in vec3 normal, const in vec3 viewDir, const in float roughness, const in vec3 frontNormal) {
    vec3 R = reflect(-viewDir, normal);
    // From Sebastien Lagarde Moving Frostbite to PBR page 69
    // so roughness = linRoughness * linRoughness
    R = getSpecularDominantDir(normal, R, roughness);

    vec3 prefilteredColor = prefilterEnvMap(roughness, environmentTransform * R);

    float factor = clamp(1.0 + dot(R, frontNormal), 0.0, 1.0);
    prefilteredColor *= factor * factor;
    return prefilteredColor;
}

vec3 computeIBLSpecularUE4(const in vec3 normal, const in vec3 viewDir, const in float roughness, const in vec3 specular, const in vec3 frontNormal, const in float f90) {
    float NoV = dot(normal, viewDir);
    return getPrefilteredEnvMapColor(normal, viewDir, roughness, frontNormal) * integrateBRDF(specular, roughness, NoV, f90);
}
