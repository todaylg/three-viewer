// refer: 
// https://github.com/cedricpinson/osgjs
// https://google.github.io/filament/Filament.html

uniform mat4 uEnvironmentTransform;
mat3 environmentTransform;
uniform float uEnvBrightness;
uniform vec3 uEnvironmentSphericalHarmonics[9];
uniform sampler2D uIntegrateBRDF;

const float MIN_ROUGHNESS = 0.001;

uniform vec3 diffuse;
uniform vec3 emissive;
uniform float roughness;
uniform float metalness;
uniform float opacity;
uniform vec2 uShadowDepthRange;

uniform float uSpecularAAThreshold;
uniform float uSpecularAAVariance;

varying vec3 vViewPosition;

// Anisotropy
uniform float uAnisotropyRotation;
uniform float uAnisotropyFactor;

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
varying vec3 vWorldNormal;
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

#preImport <math>
#preImport <shadow>
#preImport <light>
#preImport <ibl>
#preImport <brdf>
#preImport <advance>

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
        // materialSpecular = 0.16 * reflectance * reflectance * (1.0 - metallic) + baseColor * metallic;
        materialDiffuse = diffuseColor.rgb * (1.0 - metalnessFactor);
    #endif

    float materialF90 = 1.0;
    #ifndef MOBILE
    materialF90 = saturate(dot(materialSpecular, vec3(50.0 * 0.33)));
    // cheap luminance approximation
    // materialF90 = saturate(50.0 * materialSpecular.g);
    #endif

    // Roughness
    float materialRoughness = max(MIN_ROUGHNESS, roughnessVal);
    #ifdef GEOMETRIC_SPECULAR_AA
    materialRoughness = normalFiltering(materialRoughness, geometryNormal);
    #endif

    vec3 prepCompute = precomputeLight(normal, viewDir, max(0.045, materialRoughness));

    // Anisotropy
    vec3 bentAnisotropicNormal = normal;
    float anisotropy = uAnisotropyFactor;
    #ifdef USE_TANGENT
        #ifdef ENABLE_ANISOTROPY
        vec3 anisotropicT = normalize(vTangent.xyz);
        vec3 anisotropicB = normalize(vBitangent.xyz);
        // Change direction
        mat3 anisotropyRotationMatrix = rotationMatrix3(normal, uAnisotropyRotation);
        anisotropicB *= anisotropyRotationMatrix;
        anisotropicT *= anisotropyRotationMatrix;
        bentAnisotropicNormal = computeAnisotropicBentNormal(normal, viewDir, materialRoughness, anisotropicT, anisotropicB, anisotropy);
        #endif
	#endif

    // IBL
    vec3 specularDFG = vec3(1.0);
    vec3 transformedNormal = environmentTransform * normal;
    vec3 diffuseIBL = materialDiffuse * computeDiffuseSPH(transformedNormal, uEnvironmentSphericalHarmonics);
    vec3 specularIBL = computeIBLSpecularUE4(bentAnisotropicNormal, viewDir, materialRoughness, materialSpecular, vNormal, specularDFG);
    
    // Diffuse AO
    float materialAO = 1.0;
    #ifdef USE_AOMAP
	materialAO = (texture2D(aoMap, vUv2).r - 1.0) * aoMapIntensity + 1.0;
    #endif
    #ifdef MS_DIFFUSE_AO
    multiBounceAO(materialAO, materialDiffuse, diffuseIBL);
    #else
    diffuseIBL *= materialAO;
    #endif
    diffuseIBL *= uEnvBrightness;
    
    // Specular AO
    float aoSpec = 1.0;
    #ifdef SPECULAR_AO_SEBLAGARDE
    aoSpec = computeSpecularAO(materialAO, prepCompute);
    #elif defined(SPECULAR_AO_MARMOSETCO)
    aoSpec = occlusionHorizon(materialAO, normal, viewDir);
    #endif
    float energyCompensation = 1.0;
    #ifdef ENERGY_COMPENSATION
    energyCompensation = getEnergyCompensation(specularDFG, materialSpecular.g);
    #endif
    #ifdef MS_SPECULAR_AO
    multiBounceSpecularAO(materialAO, materialSpecular, specularIBL);
    #endif

    specularIBL *= uEnvBrightness * aoSpec * energyCompensation;

    // Light
    float attenuation, NoL;
    vec3 lightDir;
    vec3 lightSpecular;
    vec3 lightDiffuse;
    vec3 resultLightSpecular;
    vec3 resultLightDiffuse;
    bool lighted;
    float shadow = 1.0;
    float shadowDistance;

    #if NUM_DIR_LIGHTS > 0
        DirectionalLight directionalLight;
        #if defined( USE_SHADOWMAP ) && NUM_DIR_LIGHT_SHADOWS > 0
        DirectionalLightShadow directionalLightShadow;
        #endif
        #pragma unroll_loop_start
	    for ( int i = 0; i < NUM_DIR_LIGHTS; i ++ ) {
            directionalLight = directionalLights[ i ];
            precomputeDirect(normal, viewDir, directionalLight, attenuation, lightDir, NoL);
            // Todo: combine methods
            #ifdef USE_TANGENT
                #ifdef ENABLE_ANISOTROPY
                anisotropicSurfaceShading(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, anisotropicT, anisotropicB, anisotropy, lightDiffuse, lightSpecular, lighted);
                #else
                surfaceShading(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
                #endif
            #else
            surfaceShading(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
            #endif
            
            lightSpecular *= energyCompensation;
            // Shadow
            #if defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
            directionalLightShadow = directionalLightShadows[ i ];
            shadow *= all( bvec2( directionalLight.visible, receiveShadow ) ) ? getShadow( lighted, directionalShadowMap[ i ], directionalLightShadow.shadowMapSize, directionalLightShadow.shadowBias, directionalLightShadow.shadowRadius, vDirectionalShadowCoord[ i ], shadowDistance ) : 1.0;
            lightDiffuse *= shadow;
            lightSpecular *= shadow;
            #endif

            resultLightDiffuse += lightDiffuse;
            resultLightSpecular += lightSpecular;
        }
        #pragma unroll_loop_end
    #endif
    // Todo: Spot/Point Light

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
    vec4 frag = vec4(totalResult, diffuseColor.a);
    gl_FragColor = frag;
    #include <tonemapping_fragment>
    #include <encodings_fragment>
}