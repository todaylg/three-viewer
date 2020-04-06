vec3 precomputeLight(vec3 normal, vec3 eyeVector, float perceptualRoughness){
    // perceptually linear roughness to roughness
    float roughness = perceptualRoughness * perceptualRoughness;
    float NoV =  saturate(dot(normal, eyeVector));
    return vec3(roughness, roughness * roughness, NoV);
}