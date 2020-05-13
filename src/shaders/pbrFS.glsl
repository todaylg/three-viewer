// refer: 
// https://github.com/cedricpinson/osgjs
// https://google.github.io/filament/Filament.html

uniform mat3 uEnvironmentTransform;
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

varying vec3 vViewPosition;

#ifdef GEOMETRIC_SPECULAR_AA
uniform float uSpecularAAThreshold;
uniform float uSpecularAAVariance;
#endif

// Anisotropy
#if defined(USE_TANGENT) && defined(ENABLE_ANISOTROPY)
uniform float uAnisotropyRotation;
uniform float uAnisotropyFactor;
#endif

// ClearCoat
#ifdef ENABLE_CLEARCOAT
uniform float uClearCoat;
uniform float uClearCoatRoughness;
#endif

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
#preImport <clearCoat>

void main(){
    vec3 viewDir = -normalize(vViewPosition);

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
    float materialRoughness = clamp(roughnessVal, MIN_ROUGHNESS, 1.0);
    #ifdef GEOMETRIC_SPECULAR_AA
    materialRoughness = normalFiltering(materialRoughness, geometryNormal);
    #endif

    vec3 prepCompute = precomputeLight(normal, viewDir, max(0.045, materialRoughness));

    // Anisotropy
    vec3 bentAnisotropicNormal = normal;
    #if defined(USE_TANGENT) && defined(ENABLE_ANISOTROPY)
        float anisotropy = uAnisotropyFactor;
        vec3 anisotropicT = normalize(vTangent.xyz);
        vec3 anisotropicB = normalize(vBitangent.xyz);
        // Change direction
        mat3 anisotropyRotationMatrix = rotationMatrix3(normal, uAnisotropyRotation);
        anisotropicB *= anisotropyRotationMatrix;
        anisotropicT *= anisotropyRotationMatrix;
        bentAnisotropicNormal = computeAnisotropicBentNormal(normal, viewDir, materialRoughness, anisotropicT, anisotropicB, anisotropy);
	#endif

    // IBL
    float NoV = dot(bentAnisotropicNormal, viewDir);
    vec3 transformedNormal = uEnvironmentTransform * bentAnisotropicNormal;
    vec3 diffuseIBL = materialDiffuse * computeDiffuseSPH(transformedNormal, uEnvironmentSphericalHarmonics);
    vec3 specularDFG = integrateBRDF(materialSpecular, materialRoughness, NoV);
    vec3 specularIBL = computeIBLSpecularUE4(specularDFG, bentAnisotropicNormal, viewDir, materialRoughness);
    
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
    float specularAO = 1.0;
    #ifdef SPECULAR_AO_SEBLAGARDE
    specularAO = computeSpecularAO(materialAO, prepCompute);
    #elif defined(SPECULAR_AO_MARMOSETCO)
    specularAO = occlusionHorizon(materialAO, normal, viewDir);
    #endif
    float energyCompensation = 1.0;
    #ifdef ENERGY_COMPENSATION
    energyCompensation = getEnergyCompensation(specularDFG, materialSpecular.g);
    #endif
    #ifdef MS_SPECULAR_AO
    multiBounceSpecularAO(materialAO, materialSpecular, specularIBL);
    #endif

    specularIBL *= uEnvBrightness * specularAO * energyCompensation;

    // ClearCoat IBL
    #ifdef ENABLE_CLEARCOAT
    // Todo: ClearCoat normalMap
    // Use the geometric normal for the clear coat layer
    float clearCoatNoV = prepCompute.z;
    vec3 clearCoatNormal = geometryNormal;
    float clearCoatPerceptualRoughness = clamp(uClearCoatRoughness, MIN_ROUGHNESS, 1.0);
    #ifdef GEOMETRIC_SPECULAR_AA
    clearCoatPerceptualRoughness = normalFiltering(materialRoughness, geometryNormal);
    #endif
    float clearCoatRoughness = clearCoatPerceptualRoughness * clearCoatPerceptualRoughness;
    computeClearCoatIBL(clearCoatNoV, clearCoatNormal, clearCoatPerceptualRoughness, viewDir, specularAO, diffuseIBL, specularIBL);
    #endif

    // Light
    float attenuation, NoL;
    vec3 lightDir;
    vec3 lightSpecular;
    vec3 lightDiffuse;
    vec3 resultLightSpecular;
    vec3 resultLightDiffuse;
    float resultLightClearCoat = 0.;
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
            #if defined(USE_TANGENT) && defined(ENABLE_ANISOTROPY)
            anisotropicSurfaceShading(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, anisotropicT, anisotropicB, anisotropy, lightDiffuse, lightSpecular, lighted);
            #else
            surfaceShading(normal, viewDir, NoL, prepCompute, materialDiffuse, materialSpecular, attenuation, directionalLights[ i ].color, lightDir, materialF90, lightDiffuse, lightSpecular, lighted);
            #endif
            // ClearCoat
            #ifdef ENABLE_CLEARCOAT
            vec3 H = normalize(viewDir + lightDir);
            // Todo: ClearCoat normalMap
            float clearCoatNoH =  saturate(dot(clearCoatNormal, H));
            float clearCoatLoH =  saturate(dot(lightDir, H));
            float Fcc;
            float clearCoat = clearCoatLobe(H, clearCoatNoH, clearCoatLoH, clearCoatRoughness, Fcc);
            float clearCoatAttenuation = 1.0 - Fcc;

            lightDiffuse *= clearCoatAttenuation;
            lightSpecular *= energyCompensation * clearCoatAttenuation;
            resultLightClearCoat += clearCoat;
            #else
            lightSpecular *= energyCompensation;
            #endif
            
            // Shadow
            // Mobile texture unit too little! 
            #if !defined( MOBILE ) && defined( USE_SHADOWMAP ) && ( UNROLLED_LOOP_INDEX < NUM_DIR_LIGHT_SHADOWS )
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

    vec3 totalResult = resultDiffuse + resultSpecular + totalEmissiveRadiance + resultLightClearCoat;
    vec4 frag = vec4(totalResult, diffuseColor.a);
    gl_FragColor = frag;
    #include <tonemapping_fragment>
    #include <encodings_fragment>
}