// refer: 
// https://github.com/cedricpinson/osgjs
// https://google.github.io/filament/Filament.html

uniform mat4 uEnvironmentTransform;
mat3 environmentTransform;
uniform float uEnvBrightness;
uniform vec3 uEnvironmentSphericalHarmonics[9];

uniform int uSpecularPeak;
uniform int uOcclusionHorizon;
uniform sampler2D uIntegrateBRDF;

uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;

uniform vec2 uShadowDepthRange;

varying vec3 vViewPosition;

#ifdef CUBEMAP_LOD
uniform samplerCube envMap;
#endif
#ifdef PANORAMA
uniform sampler2D envMap;
#endif
uniform vec2 uEnvironmentSize;
uniform vec2 uEnvironmentLodRange;

#ifdef SPECULAR_GLOSSINESS
    uniform vec3 specularFactor;
    uniform float glossinessFactor;
    #ifdef USE_SPECULARMAP
	    uniform sampler2D specularMap;
    #endif
    #ifdef USE_GLOSSINESSMAP
	    uniform sampler2D glossinessMap;
    #endif
#endif

varying vec3 vNormal;
#ifdef USE_TANGENT
    varying vec3 vTangent;
    varying vec3 vBitangent;
#endif

#include <common>
#include <uv_pars_fragment>
#include <uv2_pars_fragment>
#include <color_pars_fragment>
#include <normalmap_pars_fragment>
#include <map_pars_fragment>
#include <aomap_pars_fragment>
#include <emissivemap_pars_fragment>
#include <bumpmap_pars_fragment>
#include <roughnessmap_pars_fragment>
#include <metalnessmap_pars_fragment>
#include <packing>
#include <logdepthbuf_pars_fragment>
// ************************************ Shadow ************************************
uniform bool receiveShadow;
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	#if NUM_SPOT_LIGHT_SHADOWS > 0
		uniform sampler2D spotShadowMap[ NUM_SPOT_LIGHT_SHADOWS ];
		varying vec4 vSpotShadowCoord[ NUM_SPOT_LIGHT_SHADOWS ];
	#endif

	float texture2DShadowLerp( sampler2D depths, vec2 size, vec2 uv, float compare, float shadowDistance) {
        vec2 centroidCoord = uv / size;
        centroidCoord = centroidCoord + 0.5;
        vec2 f = fract(centroidCoord);

		vec2 texelSize = vec2( 1.0 ) / size;
		vec2 centroidUV = ( floor( uv * size - 0.5 ) + 0.5 ) * texelSize;

        vec4 fetches;
        const vec2 offset = vec2( 0.0, 1.0 );
        fetches.x = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.xx ));
        fetches.y = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.xy ));
        fetches.z = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.yx ));
        fetches.w = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.yy ));

        // Shadow distance
        float _a = mix(fetches.x, fetches.y, f.y);
        float _b = mix(fetches.z, fetches.w, f.y);
        shadowDistance = mix(_a, _b, f.x);

		vec4 st = step(fetches, vec4(0.0));

        float a = mix(st.x, st.y, f.y);
        float b = mix(st.z, st.w, f.y);
        return mix(a, b, f.x);
	}

	float getShadow(bool lighted, sampler2D shadowMap, vec2 shadowMapSize, float shadowBias, float shadowRadius, vec4 shadowCoord, out float shadowDistance ) {
        bool earlyOut = false;
        float shadow = 1.0;

        if (!lighted){
            shadow = 0.0;
            earlyOut = true;
        }

        if(uShadowDepthRange.x == uShadowDepthRange.y){
            earlyOut = true;
        }

        if (!earlyOut) {
            shadowCoord.xyz /= shadowCoord.w;
            shadowCoord.z += shadowBias;
            // if ( something && something ) breaks ATI OpenGL shader compiler
            // if ( all( something, something ) ) using this instead
            bvec4 inFrustumVec = bvec4 ( shadowCoord.x >= 0.0, shadowCoord.x <= 1.0, shadowCoord.y >= 0.0, shadowCoord.y <= 1.0 );
            bool inFrustum = all( inFrustumVec );
            bvec2 frustumTestVec = bvec2( inFrustum, shadowCoord.z <= 1.0 );
            bool frustumTest = all( frustumTestVec );
            if ( frustumTest ) {
                vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
                // TODO: Shadow jitter
                float res = texture2DShadowLerp( shadowMap, shadowMapSize, shadowCoord.xy, shadowCoord.z, shadowDistance);
                shadow = res;
            }
        }
		return shadow;
	}
#endif

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
#endif

// ************************************ Light ************************************
#if NUM_DIR_LIGHTS > 0
void precomputeDirect(const in vec3 normal, const in vec3 viewDir, DirectionalLight directionalLight, out float attenuation, out vec3 lightDir, out float NoL) {
    attenuation = 1.0;
    lightDir = directionalLight.direction;
    NoL = dot(normal, lightDir);
}
#endif

#if NUM_SPOT_LIGHTS > 0
void precomputeSpot(const in vec3 normal, const in vec3 viewDir, const in vec3 viewVertex, SpotLight spotLight, out float attenuation, out vec3 lightDir, out float NoL) {
    vec3 lightViewPosition = spotLight.position;
    lightDir = lightViewPosition - viewVertex;
    float dist = length(lightDir);
    lightDir = dist > 0.0 ? lightDir / dist : vec3( 0.0, 1.0, 0.0 );
    NoL = dot(lightDir, normal);
    attenuation = getSpotDirectLightIrradiance(spotLight, vViewPosition);
}
#endif

#if NUM_POINT_LIGHTS > 0
void precomputePoint(const in vec3 normal, const in vec3 viewDir, const in vec3 viewVertex, PointLight pointLight, out float attenuation, out vec3 lightDir, out float NoL) {
    lightDir = pointLight.position - viewVertex;
    float dist = length(lightDir);
    attenuation = getPointDirectLightIrradiance(pointLight, vViewPosition);
    lightDir = dist > 0.0 ? lightDir / dist : vec3( 0.0, 1.0, 0.0 );
    NoL = dot(lightDir, normal);
}
#endif

#pragma glslify: precomputeLight = require(./chunk/precomputeLight.glsl);

// Isotropy
#pragma glslify: computeLight = require(./chunk/isotropyLightCompute.glsl);

// ************************************ IBL ************************************
mat3 getEnvironmentTransfrom(mat4 transform) {
    vec3 x = vec3(transform[0][0], transform[1][0], transform[2][0]);
    vec3 y = vec3(transform[0][1], transform[1][1], transform[2][1]);
    vec3 z = vec3(transform[0][2], transform[1][2], transform[2][2]);
    mat3 m = mat3(x,y,z);
    return m;
}

#pragma glslify: computeDiffuseSPH = require(./chunk/computeDiffuseSPH.glsl);

#ifdef PANORAMA
    #pragma glslify: texturePanoramaLod = require(./chunk/panoramaSampler.glsl);
#endif

#ifdef MOBILE
    #pragma glslify: integrateBRDF = require(./chunk/integrateBRDFMobile.glsl);
#else
vec3 integrateBRDF(const in vec3 specular, const in float roughness, const in float NoV, const in float f90) {
    vec4 rgba = texture2D(uIntegrateBRDF, vec2(NoV, roughness));
    float b = (rgba[3] * 65280.0 + rgba[2] * 255.0);
    float a = (rgba[1] * 65280.0 + rgba[0] * 255.0);
    const float div = 1.0 / 65535.0;
    return (specular * a + b * f90) * div;
}
#endif

// frostbite, lagarde paper p67
// http://www.frostbite.com/wp-content/uploads/2014/11/course_notes_moving_frostbite_to_pbr.pdf
float linRoughnessToMipmap(float roughnessLinear){
    return sqrt(roughnessLinear);
}

vec3 prefilterEnvMap(const in float rLinear, const in vec3 R) {
    vec3 dir = R;
    float lod = linRoughnessToMipmap(rLinear) * uEnvironmentLodRange[1]; //(uEnvironmentMaxLod - 1.0);
    lod = min(uEnvironmentLodRange[0], lod);
#ifdef CUBEMAP_LOD
    // http://seblagarde.wordpress.com/2012/06/10/amd-cubemapgen-for-physically-based-rendering/
    float scale = 1.0 - exp2(lod) / uEnvironmentSize[0];
    vec3 absDir = abs(dir);
    float M = max(max(absDir.x, absDir.y), absDir.z);
    // cubemapSeamlessFixDirection
    if (absDir.x != M) dir.x *= scale;
    if (absDir.y != M) dir.y *= scale;
    if (absDir.z != M) dir.z *= scale;
	return LogLuvToLinear(textureCubeLodEXT(envMap, dir, lod)).rgb;
#else
    return LogLuvToLinear(texturePanoramaLod(envMap, uEnvironmentSize, R, lod, uEnvironmentLodRange[0])).rgb;
	#endif

}

// From Sebastien Lagarde Moving Frostbite to PBR page 69
// We have a better approximation of the off specular peak
// but due to the other approximations we found this one performs better.
// N is the normal direction
// R is the mirror vector
// This approximation works fine for G smith correlated and uncorrelated
vec3 getSpecularDominantDir(const in vec3 N, const in vec3 R, const in float realRoughness) {
    float smoothness = 1.0 - realRoughness;
    float lerpFactor = smoothness * (sqrt(smoothness) + realRoughness);
    return mix(N, R, lerpFactor);
}

vec3 getPrefilteredEnvMapColor(const in vec3 normal, const in vec3 viewDir, const in float roughness, const in vec3 frontNormal) {
    vec3 R = reflect(-viewDir, normal);
    // From Sebastien Lagarde Moving Frostbite to PBR page 69
    // so roughness = linRoughness * linRoughness
    R = getSpecularDominantDir(normal, R, roughness);

    vec3 prefilteredColor = prefilterEnvMap(roughness, environmentTransform * R);

    float factor = clamp(1.0 + dot(R, frontNormal), 0.0, 1.0);
    prefilteredColor *= factor * factor;
    return prefilteredColor;
}

vec3 computeIBLSpecularUE4(const in vec3 normal, const in vec3 viewDir, const in float roughness, const in vec3 specular, const in vec3 frontNormal, const in float f90) {
    float NoV = dot(normal, viewDir);
    return getPrefilteredEnvMapColor(normal, viewDir, roughness, frontNormal) * integrateBRDF(specular, roughness, NoV, f90);
}

float occlusionHorizon(const in float ao, const in vec3 normal, const in vec3 viewDir) {
    if (uOcclusionHorizon == 0) return 1.0;
    // http://marmosetco.tumblr.com/post/81245981087
    float d = dot(normal, viewDir) + ao;
    return clamp((d * d) - 1.0 + ao, 0.0, 1.0);
}

void main(){
    vec3 viewDir = -normalize(vViewPosition);
    environmentTransform = getEnvironmentTransfrom(uEnvironmentTransform);

    vec4 diffuseColor = vec4(diffuse, opacity);
    vec3 totalEmissiveRadiance = emissive;
    #include <logdepthbuf_fragment>
    #include <color_fragment>
    #include <normal_fragment_begin>
	#include <normal_fragment_maps>
    #include <map_fragment>
    #include <emissivemap_fragment>

    float roughnessVal;
    #ifdef SPECULAR_GLOSSINESS
        roughnessVal = glossinessFactor;
        #ifdef USE_GLOSSINESSMAP
            roughnessVal = texture2D(glossinessMap, vUv).a * glossinessFactor;
        #endif
        roughnessVal = 1.0 - roughnessVal;
    #else
        #include <roughnessmap_fragment>
        roughnessVal = roughnessFactor;
    #endif

    vec3 materialSpecular;
    vec3 materialDiffuse = diffuseColor.rgb;
    #ifdef SPECULAR_GLOSSINESS
        materialSpecular = specularFactor;
        #ifdef USE_SPECULARMAP
            materialSpecular = sRGBToLinear(texture2D(specularMap, vUv)).rgb * specularFactor;
        #endif
    #else
        #include <metalnessmap_fragment>
        float f0 = 0.04;
        materialSpecular = mix(vec3(f0), diffuseColor.rgb, metalnessFactor);
        materialDiffuse = diffuseColor.rgb * (1.0 - metalnessFactor);
    #endif

    float materialF90 = clamp(50.0 * materialSpecular.g, 0.0, 1.0);
    // Roughness
    const float minRoughness = 0.001;
    float materialRoughness = max(minRoughness , roughnessVal);

    // IBL
    vec3 transformedNormal = environmentTransform * normal;
    vec3 diffuseIBL = materialDiffuse * computeDiffuseSPH(transformedNormal, uEnvironmentSphericalHarmonics);
    vec3 specularIBL = computeIBLSpecularUE4(normal, viewDir, materialRoughness, materialSpecular, normal, materialF90);
    // AO
    float materialAO = 1.0;
    #ifdef USE_AOMAP
	materialAO = (texture2D(aoMap, vUv2).r - 1.0) * aoMapIntensity + 1.0;
    #endif
    diffuseIBL *= uEnvBrightness * materialAO;

    float aoSpec = 1.0;
    aoSpec = occlusionHorizon(materialAO, normal, viewDir);
    specularIBL *= uEnvBrightness * aoSpec;

    // Light
    float attenuation, NoL;
    vec3 lightDir;
    vec3 lightSpecular;
    vec3 lightDiffuse;
    vec3 resultLightSpecular;
    vec3 resultLightDiffuse;
    bool lighted;
    float shadow = 1.0;
    vec3 prepCompute = precomputeLight(normal, viewDir, max(0.045, materialRoughness));
    float shadowDistance;

    #if NUM_DIR_LIGHTS > 0
        DirectionalLight directionalLight;
        #pragma unroll_loop
	    for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
            directionalLight = directionalLights[ i ];
            precomputeDirect(normal, viewDir, directionalLight, attenuation, lightDir, NoL);
            computeLight(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
            // Shadow
            #if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
            shadow *= all( bvec2( directionalLight.shadow, receiveShadow ) ) ? getShadow( lighted, directionalShadowMap[ i ], directionalLight.shadowMapSize, directionalLight.shadowBias, directionalLight.shadowRadius, vDirectionalShadowCoord[ i ], shadowDistance ) : 1.0;
            lightDiffuse *= shadow;
            lightSpecular *= shadow;
            #endif

            resultLightDiffuse += lightDiffuse;
            resultLightSpecular += lightSpecular;
        }
    #endif
    #if NUM_SPOT_LIGHTS > 0
        SpotLight spotLight;
        #pragma unroll_loop
	    for ( int i = 0; i < NUM_SPOT_LIGHTS; i ++ ) {
            spotLight = spotLights[ i ];
            precomputeSpot(normal, viewDir, vViewPosition, spotLight, attenuation, lightDir, NoL);
            computeLight(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, spotLight.color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
            // TODO: Shadow && Anisotropy
            resultLightDiffuse += lightDiffuse;
            resultLightSpecular += lightSpecular;
        }
    #endif
    #if NUM_POINT_LIGHTS > 0
        PointLight pointLight;
        #pragma unroll_loop
	    for ( int i = 0; i < NUM_POINT_LIGHTS; i ++ ) {
            pointLight = pointLights[ i ];
            // TODO: Shadow && Anisotropy
            precomputePoint(normal, viewDir, vViewPosition, pointLight, attenuation, lightDir, NoL);
            computeLight(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, pointLight.color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
            resultLightDiffuse += lightDiffuse;
            resultLightSpecular += lightSpecular;
        }
    #endif

    // Test
    #ifndef ENABLE_IBL
        diffuseIBL = vec3(0.);
        specularIBL = vec3(0.);
    #endif
    #ifndef ENABLE_LIGHT
        resultLightDiffuse = vec3(0.);
        resultLightSpecular = vec3(0.);
    #endif

    vec3 resultDiffuse = diffuseIBL + resultLightDiffuse;
    vec3 resultSpecular = specularIBL + resultLightSpecular;

    vec3 totalResult = resultDiffuse + resultSpecular + totalEmissiveRadiance;
    vec4 frag = vec4( totalResult, diffuseColor.a );
    gl_FragColor = LinearTosRGB(frag);

    #include <tonemapping_fragment>
    #include <encodings_fragment>
}