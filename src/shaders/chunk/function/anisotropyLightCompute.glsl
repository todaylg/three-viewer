// Refer: Filament
// Anisotropy(GGX)
#if defined(USE_TANGENT) && defined(ENABLE_ANISOTROPY)
float D_GGX_Anisotropic(float at, float ab, float ToH, float BoH, float NoH) {
    // Burley 2012, "Physically-Based Shading at Disney"

    // The values at and ab are perceptualRoughness^2, a2 is therefore perceptualRoughness^4
    // The dot product below computes perceptualRoughness^8. We cannot fit in fp16 without clamping
    // the roughness to too high values so we perform the dot product and the division in fp32
    float a2 = at * ab;
    vec3 v = vec3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / v2;
    return a2 * w2 * w2 * (1.0 / PI);
}

float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV, float ToL, float BoL, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    // TODO: lambdaV can be pre-computed for all the lights, it should be moved out of this function
    float lambdaV = NoL * length(vec3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(vec3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL);
    return v;
}

vec3 anisotropicLobe(vec3 precomputeGGX, vec3 H, vec3 viewDir, vec3 lightDir, float NoH, float VoH, float NoL, vec3 specular, float f90, in vec3 anisotropicT, in vec3 anisotropicB, in float anisotropy) {
    float roughness = precomputeGGX.x;
    float NoV =  precomputeGGX.z;

    float ToV = dot(anisotropicT, viewDir);
    float BoV = dot(anisotropicB, viewDir);
    float ToL = dot(anisotropicT, lightDir);
    float BoL = dot(anisotropicB, lightDir);
    float ToH = dot(anisotropicT, H);
    float BoH = dot(anisotropicB, H);

    // Anisotropic parameters: at and ab are the roughness along the tangent and bitangent
    // to simplify materials, we derive them from a single roughness parameter
    // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
    float at = max(roughness * (1.0 + anisotropy), MIN_ROUGHNESS);
    float ab = max(roughness * (1.0 - anisotropy), MIN_ROUGHNESS);

    // Specular anisotropic BRDF
    float D = D_GGX_Anisotropic(at, ab, ToH, BoH, NoH);
    float V = V_SmithGGXCorrelated_Anisotropic(at, ab, ToV, BoV, ToL, BoL, NoV, NoL);
    vec3 F = Specular_F(VoH, specular, f90);

    return (D * V) * F;
}

void anisotropicSurfaceShading(vec3 normal, vec3 viewDir, float NoL, vec3 precomputeLight, vec3 diffuse, vec3 specular, float attenuation, vec3 lightColor, vec3 lightDir, float f90, vec3 anisotropicT, vec3 anisotropicB, float anisotropy, out vec3 diffuseOut, out vec3 specularOut, out bool lighted) {
    lighted = NoL > 0.0;
    if (!lighted) {
        specularOut = diffuseOut = vec3(0.0);
        return;
    }
    vec3 H = normalize(viewDir + lightDir);
    float NoH =  saturate(dot(normal, H));
    float VoH =  saturate(dot(viewDir, H));

    vec3 colorAttenuate = attenuation * NoL * lightColor;
    diffuseOut = colorAttenuate * diffuseLobe(precomputeLight, diffuse, NoL, VoH);
    specularOut = colorAttenuate * anisotropicLobe(precomputeLight, H, viewDir, lightDir, NoH, VoH, NoL, specular, f90, anisotropicT, anisotropicB, anisotropy);
}
#endif