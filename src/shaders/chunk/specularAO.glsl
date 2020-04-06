// http://marmosetco.tumblr.com/post/81245981087
float occlusionHorizon(float ao, vec3 normal, vec3 viewDir) {
    float d = dot(normal, viewDir) + ao;
    return clamp((d * d) - 1.0 + ao, 0.0, 1.0);
}

float computeSpecularAO(float NoV, float ao, float roughness) {
    return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
}