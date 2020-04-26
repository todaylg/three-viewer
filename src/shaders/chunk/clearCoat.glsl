 // ClearCoat
void computeClearCoatIBL(float clearCoatNoV, vec3 clearCoatNormal, float clearCoatPerceptualRoughness, vec3 viewDir, vec3 frontNormal, float specularAO, inout vec3 Fd, inout vec3 Fr){
    // The clear coat layer assumes an IOR of 1.5 (4% reflectance)
    vec3 materialSpecular = vec3(0.04);
    float materialF90 = 1.0;
    float Fc = F_Schlick(clearCoatNoV, materialSpecular.x, materialF90) * uClearCoat;
    float attenuation = 1.0 - Fc;
    Fd *= attenuation;
    Fr *= attenuation;

    vec3 specularDFG = integrateBRDF(materialSpecular, clearCoatPerceptualRoughness, clearCoatNoV);
    vec3 clearCoatLobe = computeIBLSpecularUE4(specularDFG, clearCoatNormal, viewDir, clearCoatPerceptualRoughness, frontNormal);
    Fr += clearCoatLobe * (specularAO * uClearCoat);
}
