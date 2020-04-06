float pow5(float x) {
	float xx = x * x;
	return xx * xx * x;
}

mat3 getEnvironmentTransfrom(mat4 transform) {
    vec3 x = vec3(transform[0][0], transform[1][0], transform[2][0]);
    vec3 y = vec3(transform[0][1], transform[1][1], transform[2][1]);
    vec3 z = vec3(transform[0][2], transform[1][2], transform[2][2]);
    mat3 m = mat3(x,y,z);
    return m;
}