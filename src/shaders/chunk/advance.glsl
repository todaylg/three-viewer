#ifdef ENERGY_COMPENSATION
float getEnergyCompensation(vec3 dfg, float f0) {
   return 1.0 + f0 * (1.0 / dfg.y - 1.0);
}
#endif

#ifdef SPECULAR_AO_MARMOSETCO
// http://marmosetco.tumblr.com/post/81245981087
float occlusionHorizon(float ao, vec3 normal, vec3 viewDir) {
    float d = dot(normal, viewDir) + ao;
    return clamp((d * d) - 1.0 + ao, 0.0, 1.0);
}
#endif

#ifdef SPECULAR_AO_SEBLAGARDE
// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
float computeSpecularAO(float ao, vec3 precomputeLight) {
    float roughness = precomputeLight.x;
    float NoV =  precomputeLight.z;
    return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
}
#endif

/**
* Returns a color ambient occlusion based on a pre-computed visibility term.
* The albedo term is meant to be the diffuse color or f0 for the diffuse and
* specular terms respectively.
*/
vec3 gtaoMultiBounce(float visibility, const vec3 albedo) {
    // Jimenez et al. 2016, "Practical Realtime Strategies for Accurate Indirect Occlusion"
    vec3 a =  2.0404 * albedo - 0.3324;
    vec3 b = -4.7951 * albedo + 0.6417;
    vec3 c =  2.7552 * albedo + 0.6903;

    return max(vec3(visibility), ((visibility * a + b) * visibility + c) * visibility);
}
#ifdef MS_DIFFUSE_AO
void multiBounceAO(float visibility, const vec3 albedo, inout vec3 color) {
    color *= gtaoMultiBounce(visibility, albedo);
}
#endif

#ifdef MS_SPECULAR_AO
void multiBounceSpecularAO(float visibility, const vec3 albedo, inout vec3 color) {
    color *= gtaoMultiBounce(visibility, albedo);
}
#endif

#ifdef GEOMETRIC_SPECULAR_AA
float normalFiltering(float perceptualRoughness, const vec3 geometricNormal) {
    // Kaplanyan 2016, "Stable specular highlights"
    // Tokuyoshi 2017, "Error Reduction and Simplification for Shading Anti-Aliasing"
    // Tokuyoshi and Kaplanyan 2019, "Improved Geometric Specular Antialiasing"

    // This implementation is meant for deferred rendering in the original paper but
    // we use it in forward rendering as well (as discussed in Tokuyoshi and Kaplanyan
    // 2019). The main reason is that the forward version requires an expensive transform
    // of the half vector by the tangent frame for every light. This is therefore an
    // approximation but it works well enough for our needs and provides an improvement
    // over our original implementation based on Vlachos 2015, "Advanced VR Rendering".

    vec3 du = dFdx(geometricNormal);
    vec3 dv = dFdy(geometricNormal);

    float variance = uSpecularAAVariance * (dot(du, du) + dot(dv, dv));

    float roughness = perceptualRoughness * perceptualRoughness;
    float kernelRoughness = min(2.0 * variance, uSpecularAAThreshold);
    float squareRoughness = saturate(roughness * roughness + kernelRoughness);

    return sqrt(sqrt(squareRoughness));
}
#endif