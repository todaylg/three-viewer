import * as THREE from 'three';
import pbrVS from '../shaders/pbrVS';
import pbrFS from '../shaders/pbrFS';
import { syncMapArr, syncUniformArr, pbrDefaultUniforms, pbrDefaultDefines } from '../const/defaultParams';

class PBRMaterial extends THREE.ShaderMaterial {
	constructor(mesh, uniformsOpt) {
		let sourceMaterial = mesh.material;
		super();
		this.modelNormalMatrix = new THREE.Matrix3();
		this.copy(sourceMaterial);
		this.defines = pbrDefaultDefines;
		// VertexTangents rely on (vertexTangents && normalMap) in threejs
		// if(this.vertexTangents) this.defines.USE_TANGENT = 1;
		// Copy method no include normalMapType
		this.normalMapType = sourceMaterial.normalMapType;

		if(uniformsOpt.isMobile) this.defines.MOBILE = 1;
		// Uniforms
		let UniformsLib = THREE.UniformsLib;
		// Todo: Support specular-glossiness 
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
		this.uniforms['uShadowDepthRange'] = { value: uniformsOpt.shadowDepthRange };
		this.uniforms['uEnvironmentSphericalHarmonics'] = { value: uniformsOpt.uEnvironmentSphericalHarmonics };
		this.uniforms['uEnvironmentLodRange'] = { value: uniformsOpt.uEnvironmentLodRange };
		this.uniforms['uEnvironmentSize'] = { value: uniformsOpt.uEnvironmentSize };
		this.uniforms['uIntegrateBRDF'] = { value: uniformsOpt.uIntegrateBRDF };
		this.uniforms['uModelNormalMatrix'] = { value: this.modelNormalMatrix };

		// PBR param sync
		this.syncParam(sourceMaterial);

		this.vertexShader = pbrVS;
		this.fragmentShader = pbrFS;
		this.lights = true;
		// Sync worldNormal matrix
		mesh.onBeforeRender = () =>{
			this.modelNormalMatrix.getNormalMatrix(mesh.matrixWorld);
		}
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
}

export { PBRMaterial };
