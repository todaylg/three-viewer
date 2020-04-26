// Refer: UE4

// ************************ Normal Distribution Functions(NDF) **************************

// [Blinn 1977, "Models of light reflection for computer synthesized pictures"]
float D_Blinn(vec3 precomputeLight, float NoH){
    float a2 = precomputeLight.y;
    float n = 2.0 / a2 - 2.0;
    return (n+2.0) / (2.0* PI) * pow(NoH, n);   // 1 mad, 1 exp, 1 mul, 1 log
}

// [Beckmann 1963, "The scattering of electromagnetic waves from rough surfaces"]
float D_Beckmann(vec3 precomputeLight, float NoH){
    float a2 = precomputeLight.y;
    float NoH2 = NoH * NoH;
    return exp( (NoH2 - 1.0) / (a2 * NoH2) ) / ( PI * a2 * NoH2 * NoH2 );
}

// GGX / Trowbridge-Reitz
// [Walter et al. 2007, "Microfacet models for refraction through rough surfaces"]
float D_GGX(vec3 precomputeLight, float NoH){
    float a2 = precomputeLight.y;
    float d = (NoH * a2 - NoH) * NoH + 1.0;	// 2 mad
    return a2 / (PI * d * d);	// 4 mul, 1 rcp
}

float D_GGX(float rougness, float NoH){
    float a2 = rougness * rougness;
    float d = (NoH * a2 - NoH) * NoH + 1.0;	// 2 mad
    return a2 / (PI * d * d);	// 4 mul, 1 rcp
}

float Specular_D(vec3 precomputeLight, float NoH){
#if defined(NDF_BLINNPHONG)
    return D_Blinn(precomputeLight, NoH);
#elif defined(NDF_BECKMANN)
    return D_Beckmann(precomputeLight, NoH);
#elif defined(NDF_GGX)
    return D_GGX(precomputeLight, NoH);
#else
    return D_GGX(precomputeLight, NoH);
#endif
}

// ************************************ Fresnel ************************************

// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
vec3 F_Schlick(float VoH, vec3 f0, float f90){
    return f0 + (vec3(f90) - f0) * pow5(1.0 - VoH);
}

float F_Schlick(float VoH, float f0, float f90) {
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

// [Cook-Torrance 1982]
vec3 F_CookTorrance(float VoH, vec3 f0, float f90){
    vec3 sqrtSpec = sqrt(f0);
    vec3 n = (1.0 + sqrtSpec) / (1.0 - sqrtSpec);
    float c = saturate(VoH);
    vec3 g = sqrt(n * n + c * c - 1.0);

    vec3 part1 = (g - c)/(g + c);
    vec3 part2 = ((g + c) * c - 1.0)/((g - c) * c + 1.0);

    return max(vec3(0.0), 0.5 * part1 * part1 * (1.0 + part2 * part2));
}

vec3 F_None(vec3 f0){
    return f0;
}

vec3 Specular_F(float VoH, vec3 f0, float f90) {
#if defined(F_SCHLICK)
    return F_Schlick(VoH, f0, f90);
#elif defined(F_COOKTORRANCE)
    return F_CookTorrance(VoH, f0, f90);
#else // FRESNSEL_NONE
    return F_None(f0);
#endif
}

// ******************************** Visibility Term *********************************
float Vis_Implicit(){
	return 0.25;
}

// [Neumann et al. 1999, "Compact metallic reflectance models"]
float Vis_Neumann(vec3 precomputeLight, float NoL){
	float NoV = precomputeLight.z;
	return 1. / (4. * max(NoL, NoV));
}

// [Kelemen 2001, "A microfacet based coupled specular-matte brdf model with importance sampling"]
float Vis_Kelemen(float VoH){
	// constant to prevent NaN
	return 1./(4. * VoH * VoH + 1e-5);
}

// Tuned to match behavior of Vis_Smith
// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
float Vis_Schlick(vec3 precomputeLight, float NoL){
	float a2 = precomputeLight.y;
	float NoV = precomputeLight.z;
	float k = sqrt(a2) * 0.5;
	float Vis_SchlickV = NoV * (1. - k) + k;
	float Vis_SchlickL = NoL * (1. - k) + k;
	return 0.25 / (Vis_SchlickV * Vis_SchlickL);
}

// Smith term for GGX
// [Smith 1967, "Geometrical shadowing of a random rough surface"]
float Vis_Smith(vec3 precomputeLight, float NoL){
	float a2 = precomputeLight.y;
	float NoV = precomputeLight.z;
	float Vis_SmithV = NoV + sqrt(NoV * (NoV - NoV * a2) + a2);
	float Vis_SmithL = NoL + sqrt(NoL * (NoL - NoL * a2) + a2);
	return 1./(Vis_SmithV * Vis_SmithL);
}

// Appoximation of joint Smith term for GGX
// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointApprox(vec3 precomputeLight, float NoL){
    float roughness = precomputeLight.x;
    float NoV = precomputeLight.z;
    float Vis_SmithV = NoL * (NoV * (1.0 - roughness) + roughness);
    float Vis_SmithL = NoV * (NoL * (1.0 - roughness) + roughness);
    return 0.5 / (Vis_SmithV + Vis_SmithL);
}

// Hammon 2017, "PBR Diffuse Lighting for GGX+Smith Microsurfaces"
float Vis_SmithJointApprox_Hammon(vec3 precomputeLight, float NoL) {
    float roughness = precomputeLight.x;
    float NoV = precomputeLight.z;

    float v = 0.5 / mix(2.0 * NoL * NoV, NoL + NoV, roughness);
    return v;
}

float Specular_V(vec3 precomputeLight, float NoL, float VoH){
#if defined(V_IMPLICIT)
    return Vis_Implicit();
#elif defined(V_NEUMANN)
    return Vis_Neumann(precomputeLight, NoL);
#elif defined(V_KELEMEN)
    return Vis_Kelemen(VoH);
#elif defined(V_SCHLICK)
    return Vis_Schlick(precomputeLight, NoL);
#elif defined(V_SMITH)
    return Vis_Smith(precomputeLight, NoL);
#elif defined(V_SMITHJOINTAPPROX)
    return Vis_SmithJointApprox(precomputeLight, NoL);
#elif defined(V_HAMMONAPPROX)
    return Vis_SmithJointApprox_Hammon(precomputeLight, NoL);
#else
	return 0.25;
#endif
}

vec3 specularLobe(vec3 precomputeLight, vec3 specular, float NoL, float NoH, float VoH, float f90) {
    float D = Specular_D(precomputeLight, NoH);
    vec3 F = Specular_F(VoH, specular, f90);
    float V = Specular_V(precomputeLight, NoL, VoH);
	
    return (D * V) * F;
}

// ************************************ Diffuse ************************************
vec3 Diffuse_Lambert(vec3 diffuse){
	return diffuse / PI;
}

// [Burley 2012, "Physically-Based Shading at Disney"]
vec3 Diffuse_Burley(vec3 precomputeLight, vec3 diffuse, float NoL, float VoH){
    float Roughness = precomputeLight.x;
    float NoV =  precomputeLight.z;

	float FD90 = 0.5 + 2. * VoH * VoH * Roughness;
	float FdV = 1. + (FD90 - 1.) * pow5(1. - NoV);
	float FdL = 1. + (FD90 - 1.) * pow5(1. - NoL);
	return diffuse * ((1. / PI) * FdV * FdL);
}

// [Gotanda 2012, "Beyond a Simple Physically Based Blinn-Phong Model in Real-Time"]
vec3 Diffuse_OrenNayar(vec3 precomputeLight, vec3 diffuse, float NoL, float VoH){
    float Roughness = precomputeLight.x;
	float a = precomputeLight.y;
    float NoV = precomputeLight.z;
	float s = a; // / ( 1.29 + 0.5 * a );
	float s2 = s * s;
	float VoL = 2. * VoH * VoH - 1.;  // double angle identity
	float Cosri = VoL - NoV * NoL;
	float C1 = 1. - 0.5 * s2 / (s2 + 0.33);
	float C2 = 0.45 * s2 / (s2 + 0.09) * Cosri * (Cosri >= 0. ? 1./(max(NoL, NoV)) : 1.);
	return diffuse / PI * (C1 + C2) * (1. + Roughness * 0.5);
}

// [Gotanda 2014, "Designing Reflectance Models for New Consoles"]
vec3 Diffuse_Gotanda(vec3 precomputeLight, vec3 diffuse, float NoL, float VoH){
    float Roughness = precomputeLight.x;
	float a = precomputeLight.y;
    float NoV = precomputeLight.z;
	float a2 = a * a;
	float F0 = 0.04;
	float VoL = 2. * VoH * VoH - 1.;    // double angle identity
	float Cosri = VoL - NoV * NoL;

	float a2_13 = a2 + 1.36053;
	float Fr = ( 1. - ( 0.542026*a2 + 0.303573*a ) / a2_13 ) * ( 1. - pow( 1. - NoV, 5. - 4.*a2 ) / a2_13 ) * ( ( -0.733996*a2*a + 1.50912*a2 - 1.16402*a ) * pow( 1. - NoV, 1. + 1./(39.*a2*a2+1.) ) + 1. );
	float Lm = ( max( 1. - 2.*a, 0. ) * ( 1. - pow5( 1. - NoL ) ) + min( 2.*a, 1. ) ) * ( 1. - 0.5*a * (NoL - 1.) ) * NoL;
	float Vd = ( a2 / ( (a2 + 0.09) * (1.31072 + 0.995584 * NoV) ) ) * ( 1. - pow( 1. - NoL, ( 1. - 0.3726732 * NoV * NoV ) / ( 0.188566 + 0.38841 * NoV ) ) );
	float Bp = Cosri < 0. ? 1.4 * NoV * NoL * Cosri : Cosri;
	float Lr = (21.0 / 20.0) * (1. - F0) * ( Fr * Lm + Vd + Bp );
	return diffuse / PI * Lr;
}

vec3 diffuseLobe(vec3 precomputeLight, vec3 diffuse, float NoL, float VoH){
#if defined(DIFFUSE_LAMBERT)
    return Diffuse_Lambert(diffuse);
#elif defined(DIFFUSE_BURLEY)
    return Diffuse_Burley(precomputeLight, diffuse, NoL, VoH);
#elif defined(DIFFUSE_ORENNAYAR)
    return Diffuse_OrenNayar(precomputeLight, diffuse, NoL, VoH);
#elif defined(DIFFUSE_GOTANDA)
    return Diffuse_Gotanda(precomputeLight, diffuse, NoL, VoH);
#else // DIFFUSE_NONE
    return vec3(0.0);
#endif
}

void surfaceShading(in vec3 normal, in vec3 viewDir, in float NoL, in vec3 precomputeLight, in vec3 diffuse, in vec3 specular, in float attenuation, in vec3 lightColor, in vec3 lightDir, in float f90, out vec3 diffuseOut, out vec3 specularOut, out bool lighted) {
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
    specularOut = colorAttenuate * specularLobe(precomputeLight, specular, NoL, NoH, VoH, f90);
}