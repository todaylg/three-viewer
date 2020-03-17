vec3 precomputeLight(vec3 normal, vec3 eyeVector, float perceptualRoughness){
    // perceptually linear roughness to roughness
    float roughness = perceptualRoughness * perceptualRoughness;
    float NoV =  clamp(dot(normal, eyeVector), 0., 1.);
    return vec3(roughness, roughness * roughness, NoV);
}

#pragma glslify: export(precomputeLight)