vec3 computeDiffuseSPH(vec3 normal, vec3 sphericalHarmonics[9]){
    float x = normal.x;
    float y = normal.y;
    float z = normal.z;
    vec3 result = (
        sphericalHarmonics[0] +
        sphericalHarmonics[1] * y +
        sphericalHarmonics[2] * z +
        sphericalHarmonics[3] * x +
        sphericalHarmonics[4] * y * x +
        sphericalHarmonics[5] * y * z +
        sphericalHarmonics[6] * (3.0 * z * z - 1.0) +
        sphericalHarmonics[7] * (z * x) +
        sphericalHarmonics[8] * (x*x - y*y)
    );
    return max(result, vec3(0.0));
}