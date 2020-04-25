import * as THREE from 'three';
import { syncMapArr, syncUniformArr, pbrDefaultUniforms, pbrDefaultDefines } from '../const/defaultParams';

class PBRMaterial extends THREE.ShaderMaterial {
	constructor(mesh, environment, shaderData) {
		let sourceMaterial = mesh.material;
		super();
		this.modelNormalMatrix = new THREE.Matrix3();
		this.copy(sourceMaterial);
		
		this.defines = Object.assign({}, pbrDefaultDefines);
		// Tips: USE_TANGENT rely on (vertexTangents && normalMap) in threejs. But gltf spec only rely vertexTangents
		// if(this.vertexTangents) this.defines.USE_TANGENT = 1;
		// Copy method no include normalMapType、vertexTangents
		this.vertexTangents = sourceMaterial.vertexTangents;
		this.normalMapType = sourceMaterial.normalMapType;
		
		// Uniforms
		let UniformsLib = THREE.UniformsLib;
		this.uniforms = THREE.UniformsUtils.merge([
			UniformsLib.common,
			UniformsLib.normalmap,
			UniformsLib.lightmap,
			UniformsLib.bumpmap,
			UniformsLib.roughnessmap,
			UniformsLib.metalnessmap,
			UniformsLib.aomap,
			UniformsLib.emissivemap,
			UniformsLib.displacementmap,
			UniformsLib.envmap,
			UniformsLib.fog,
			UniformsLib.lights,
			pbrDefaultUniforms
		]);
		this.uniforms['uShadowDepthRange'] = { value: shaderData.shadowDepthRange };
		this.uniforms['uModelNormalMatrix'] = { value: this.modelNormalMatrix };
		this.syncEnvSetting(environment);

		// PBR param sync
		this.syncParam(sourceMaterial);

		this.vertexShader = shaderData.pbrVS;
		this.fragmentShader = shaderData.pbrFS;
		this.lights = true;

		// Other
		if (sourceMaterial.isGLTFSpecularGlossinessMaterial === true) this.initSGWorkflow(sourceMaterial);

		// Sync worldNormal matrix
		mesh.onBeforeRender = () => {
			this.modelNormalMatrix.getNormalMatrix(mesh.matrixWorld);
		};

		// Extensions
		this.extensions = {
			derivatives: true,
			shaderTextureLOD: true
		};
		this.needsUpdate = true;
	}

	syncEnvSetting(environment) {
		let { mapEnv, uEnvironmentSphericalHarmonics, uEnvironmentLodRange, uEnvironmentSize, textureLODSupport } = environment;
		if (textureLODSupport) {
			// CubeMap
			this.defines[`CUBEMAP_LOD`] = 1;
		} else {
			// Panorama
			this.defines[`PANORAMA`] = 1;
		}
		// Common
		this.envMap = mapEnv.texture;
		this.uniforms['envMap'] = { value: mapEnv.texture };
		this.uniforms['uEnvironmentSphericalHarmonics'] = { value: uEnvironmentSphericalHarmonics };
		this.uniforms['uEnvironmentLodRange'] = { value: uEnvironmentLodRange };
		this.uniforms['uEnvironmentSize'] = { value: uEnvironmentSize };
		this.uniforms['uIntegrateBRDF'] = { value: environment.uIntegrateBRDF };
		// Mobile 
		if (environment.isMobile) this.defines[`MOBILE`] = 1;
	}

	syncParam(sourceMaterial) {
		// Map sync
		syncMapArr.forEach(key => {
			if (sourceMaterial[key] != undefined) {
				this[key] = sourceMaterial[key];
				this.uniforms[key].value = sourceMaterial[key];
			}
		});
		// Uniform sync
		syncUniformArr.forEach(key => {
			if (sourceMaterial[key] != undefined) {
				this.uniforms[key].value = sourceMaterial[key];
			}
		});
		// Special key
		this.uniforms.diffuse.value = sourceMaterial.color || new Color(0xffffff);
	}

	initSGWorkflow(sourceMaterial) {
		this.defines[`SPECULAR_GLOSSINESS`] = 1;
		let { specular, glossiness, specularMap, glossinessMap } = sourceMaterial._extraUniforms;
		if (specularMap.value) {
			this.defines[`USE_SPECULARMAP`] = 1;
			this.uniforms[`specularMap`] = specularMap;
		}
		if (glossinessMap.value) {
			this.defines[`USE_GLOSSINESSMAP`] = 1;
			this.uniforms[`glossinessMap`] = glossinessMap;
		}
		this.uniforms[`specularFactor`] = specular;
		this.uniforms[`glossinessFactor`] = glossiness;
	}
}

export { PBRMaterial };
