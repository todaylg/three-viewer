// Light
// DirectionalLight
#if NUM_DIR_LIGHTS > 0
	struct DirectionalLight {
		vec3 direction;
		vec3 color;

		int shadow;
		float shadowBias;
		float shadowRadius;
		vec2 shadowMapSize;
	};

	uniform DirectionalLight directionalLights[ NUM_DIR_LIGHTS ];

    void precomputeDirect(const in vec3 normal, const in vec3 viewDir, DirectionalLight directionalLight, out float attenuation, out vec3 lightDir, out float NoL) {
        attenuation = 1.0;
        lightDir = directionalLight.direction;
        NoL = dot(normal, lightDir);
    }
#endif

// Attenuation
#if NUM_POINT_LIGHTS > 0 || NUM_SPOT_LIGHTS > 0
    // Calculation of the attenuation
    float punctualLightIntensityToIrradianceFactor( const in float lightDistance, const in float cutoffDistance, const in float decayExponent ) {
    #if defined ( PHYSICALLY_CORRECT_LIGHTS )
        // based upon Frostbite 3 Moving to Physically-based Rendering
        // page 32, equation 26: E[window1]
        // https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf
        // this is intended to be used on spot and point lights who are represented as luminous intensity
        // but who must be converted to luminous irradiance for surface lighting calculation
        float distanceFalloff = 1.0 / max( pow( abs(lightDistance), decayExponent ), 0.01 );
        if( cutoffDistance > 0.0 ) {
            distanceFalloff *= pow2( saturate( 1.0 - pow4( lightDistance / cutoffDistance ) ) );
        }
        return distanceFalloff;
    #else
        if( cutoffDistance > 0.0 && decayExponent > 0.0 ) {
            return pow( saturate( -lightDistance / cutoffDistance + 1.0 ), decayExponent );
        }
        return 1.0;
    #endif
    }
#endif

// SpotLight
#if NUM_SPOT_LIGHTS > 0
	struct SpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;

		int shadow;
		float shadowBias;
		float shadowRadius;
		vec2 shadowMapSize;
	};

	uniform SpotLight spotLights[ NUM_SPOT_LIGHTS ];

	float getSpotDirectLightIrradiance( const in SpotLight spotLight, vec3 vViewPosition) {
		vec3 lVector = spotLight.position - vViewPosition;
		float lightDistance = length( lVector );
		float angleCos = dot( normalize( lVector ), spotLight.direction );

		if ( angleCos > spotLight.coneCos ) {
			float spotEffect = smoothstep( spotLight.coneCos, spotLight.penumbraCos, angleCos );
            return spotEffect * punctualLightIntensityToIrradianceFactor( lightDistance, spotLight.distance, spotLight.decay );
		} else {
			return 0.0;
		}
	}

    void precomputeSpot(const in vec3 normal, const in vec3 viewDir, const in vec3 viewVertex, SpotLight spotLight, out float attenuation, out vec3 lightDir, out float NoL) {
        vec3 lightViewPosition = spotLight.position;
        lightDir = lightViewPosition - viewVertex;
        float dist = length(lightDir);
        lightDir = dist > 0.0 ? lightDir / dist : vec3( 0.0, 1.0, 0.0 );
        NoL = dot(lightDir, normal);
        attenuation = getSpotDirectLightIrradiance(spotLight, vViewPosition);
    }
#endif

// PointLight
#if NUM_POINT_LIGHTS > 0
	struct PointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;

		int shadow;
		float shadowBias;
		float shadowRadius;
		vec2 shadowMapSize;
		float shadowCameraNear;
		float shadowCameraFar;
	};

	uniform PointLight pointLights[ NUM_POINT_LIGHTS ];

	float getPointDirectLightIrradiance( const in PointLight pointLight, vec3 vViewPosition) {
		vec3 lVector = pointLight.position - vViewPosition;
		float lightDistance = length( lVector );
		return punctualLightIntensityToIrradianceFactor( lightDistance, pointLight.distance, pointLight.decay );
	}

    void precomputePoint(const in vec3 normal, const in vec3 viewDir, const in vec3 viewVertex, PointLight pointLight, out float attenuation, out vec3 lightDir, out float NoL) {
        lightDir = pointLight.position - viewVertex;
        float dist = length(lightDir);
        attenuation = getPointDirectLightIrradiance(pointLight, vViewPosition);
        lightDir = dist > 0.0 ? lightDir / dist : vec3( 0.0, 1.0, 0.0 );
        NoL = dot(lightDir, normal);
    }
#endif