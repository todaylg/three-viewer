vec3 precomputeLight(vec3 normal, vec3 viewDir, float perceptualRoughness){
    // perceptually linear roughness to roughness
    float roughness = perceptualRoughness * perceptualRoughness;
    float NoV =  saturate(dot(normal, viewDir));
    return vec3(roughness, roughness * roughness, NoV);
}