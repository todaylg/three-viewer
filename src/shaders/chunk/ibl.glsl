// IBL
#preImport <precomputeLight>
#preImport <computeDiffuseSPH>

#ifdef PANORAMA
    #preImport <panoramaSampler>
#endif

#ifdef MOBILE
    #preImport <integrateBRDFMobile>
#else
vec3 integrateBRDF(vec3 specular, float roughness, float NoV, float f90, inout vec3 specularDFG) {
    vec4 rgba = texture2D(uIntegrateBRDF, vec2(NoV, roughness));
    // return specular * rgba.r + rgba.g * f90;
    specularDFG = mix(rgba.xxx, rgba.yyy, specular);
    return specularDFG;
}
#endif

// frostbite, lagarde paper p67
// http://www.frostbite.com/wp-content/uploads/2014/11/course_notes_moving_frostbite_to_pbr.pdf
float linRoughnessToMipmap(float roughnessLinear){
    return sqrt(roughnessLinear);
}

vec3 prefilterEnvMap(float rLinear, vec3 R) {
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
vec3 getSpecularDominantDir(vec3 N, vec3 R, float realRoughness) {
    float smoothness = 1.0 - realRoughness;
    float lerpFactor = smoothness * (sqrt(smoothness) + realRoughness);
    return mix(N, R, lerpFactor);
}

vec3 getPrefilteredEnvMapColor(vec3 normal, vec3 viewDir, float roughness, vec3 frontNormal) {
    vec3 R = reflect(-viewDir, normal);
    // From Sebastien Lagarde Moving Frostbite to PBR page 69
    // so roughness = linRoughness * linRoughness
    R = getSpecularDominantDir(normal, R, roughness);

    vec3 prefilteredColor = prefilterEnvMap(roughness, environmentTransform * R);
    return prefilteredColor;
}

vec3 computeIBLSpecularUE4(vec3 normal, vec3 viewDir, float roughness, vec3 specular, vec3 frontNormal, float f90, inout vec3 specularDFG) {
    float NoV = dot(normal, viewDir);
#ifdef MOBILE
    vec3 brdfLUT = integrateBRDF(specular, roughness, NoV, f90);
#else
    vec3 brdfLUT = integrateBRDF(specular, roughness, NoV, f90, specularDFG);
#endif
    return getPrefilteredEnvMapColor(normal, viewDir, roughness, frontNormal) * brdfLUT;
}
