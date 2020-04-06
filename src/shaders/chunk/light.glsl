// Light
// DirectionalLight
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;
		bool visible;
	};

	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];

    void precomputeDirect(vec3 normal, vec3 viewDir, inout DirectionalLight directionalLight, out float attenuation, out vec3 lightDir, out float NoL) {
        attenuation = 1.0;
        lightDir = directionalLight.direction;
        NoL = dot(normal, lightDir);
		directionalLight.visible = true;
    }
#endif
// Todo: Spot/Point Light