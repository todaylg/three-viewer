// http://marmosetco.tumblr.com/post/81245981087
float occlusionHorizon(float ao, vec3 normal, vec3 viewDir) {
    float d = dot(normal, viewDir) + ao;
    return clamp((d * d) - 1.0 + ao, 0.0, 1.0);
}

// https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
float computeSpecularAO(float ao, vec3 precomputeLight) {
    float roughness = precomputeLight.x;
    float NoV =  precomputeLight.z;
    return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
}

float getEnergyCompensation(vec3 dfg, float f0) {
   return 1.0 + f0 * (1.0 / dfg.y - 1.0);
}

// Todo: Normal AA Test
float adjustRoughness(float roughness, vec3 normal) {
    // Based on The Order : 1886 SIGGRAPH course notes implementation (page 21 notes)
    float normalLen = length(normal * 2.0 - 1.0);
    if ( normalLen < 1.0) {
        float normalLen2 = normalLen * normalLen;
        float kappa = ( 3.0 * normalLen -  normalLen2 * normalLen )/( 1.0 - normalLen2 );
        // http://www.frostbite.com/2014/11/moving-frostbite-to-pbr/
        // page 91 : they use 0.5/kappa instead
        return min(1.0, sqrt(roughness * roughness + 1.0 / kappa));
    }
    return roughness;
}