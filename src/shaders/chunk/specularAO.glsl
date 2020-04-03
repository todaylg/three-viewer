float occlusionHorizon(const in float ao, const in vec3 normal, const in vec3 viewDir) {
    if (uOcclusionHorizon == 0) return 1.0;
    // http://marmosetco.tumblr.com/post/81245981087
    float d = dot(normal, viewDir) + ao;
    return clamp((d * d) - 1.0 + ao, 0.0, 1.0);
}