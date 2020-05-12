 // ClearCoat
#ifdef ENABLE_CLEARCOAT
void computeClearCoatIBL(float clearCoatNoV, vec3 clearCoatNormal, float clearCoatPerceptualRoughness, vec3 viewDir, float specularAO, inout vec3 Fd, inout vec3 Fr){
    // The clear coat layer assumes an IOR of 1.5 (4% reflectance)
    vec3 materialSpecular = vec3(0.04);
    float materialF90 = 1.0;
    float Fc = F_Schlick(clearCoatNoV, materialSpecular.x, materialF90) * uClearCoat;
    float attenuation = 1.0 - Fc;
    Fd *= attenuation;
    Fr *= attenuation;

    vec3 specularDFG = integrateBRDF(materialSpecular, clearCoatPerceptualRoughness, clearCoatNoV);
    vec3 clearCoatLobe = computeIBLSpecularUE4(specularDFG, clearCoatNormal, viewDir, clearCoatPerceptualRoughness);
    Fr += clearCoatLobe * (specularAO * uClearCoat);
}

float distributionClearCoat(float roughness, float NoH, const vec3 h) {
    return D_GGX(roughness, NoH);
}

float visibilityClearCoat(float LoH) {
    return Vis_Kelemen(LoH);
}

float clearCoatLobe(vec3 h, float clearCoatNoH, float clearCoatLoH, float clearCoatRoughness, out float Fcc){
    // clear coat specular lobe
    float D = distributionClearCoat(clearCoatRoughness, clearCoatNoH, h);
    float V = visibilityClearCoat(clearCoatLoH);
    float F = F_Schlick(clearCoatLoH, 0.04, 1.0) * uClearCoat; // fix IOR to 1.5

    Fcc = F;
    return D * V * F;
}
#endif