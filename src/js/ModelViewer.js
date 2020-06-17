import * as THREE from 'three';
// Control
import { OrbitControls } from 'LIB/threejs/controls/OrbitControls';
// Environment
import { Environment } from 'MODULES/environment/Environment';
import { PBRMaterial } from './PBRMaterial';
import { Background } from 'MODULES/background/Background';
import Program from './Program';
import {
	envMapList,
	envMapPath,
	diffuseEquation,
	specularNDFEquation,
	specularFresnelEquation,
	specularVisEquation,
	toneMappingList,
	specularAOList,
	panelDefinesRegs
} from '../const/config';
import { pbrDefaultDefines, pbrDefaultUniforms } from '../const/defaultParams';
// Utils
import { adjustCameraByBox, adjustSunLightByBox } from './ThreeUtils';
import { isMobile } from './Utils';
// Post Procssing
import {
	EffectComposer,
	RenderPass,
	EffectPass,
	NormalPass,
	ShaderPass,
	FXAAMaterial,
	CopyMaterial,
	DepthEffect,
	SSAOEffect,
	BloomEffect,
	BlendFunction
} from 'MODULES/postprocessing/';

// Test
import { GUI } from 'LIB/threejs/libs/dat.gui.module.js';

export default class ModelViewer {
	constructor(mainScene, gltf, callBack) {
		this.gltf = gltf;
		this.gltfScene = gltf.scene;
		this.clock = new THREE.Clock();
		this.animationMixer = null;
		this.debug = false;
		this.program = new Program();
		this.isMobile = isMobile();
		// Env Rotation
		this.envRotation = 0;
		this.envRotationFromPanel = new THREE.Matrix4().makeRotationY(this.envRotation);
		this.envRotationMat4 = new THREE.Matrix4().copy(this.envRotationFromPanel);
		this.envRotationMat = { value: new THREE.Matrix3().setFromMatrix4(this.envRotationMat4) };
		this.envRotationMatBG = { value: new THREE.Matrix3().copy(this.envRotationMat.value) };
		this.envBrightness = { value: 1.0 };

		this.cameraRotationMatrix = new THREE.Matrix4();
		this.sunLightPanelRotateMat = new THREE.Matrix4();

		this.renderer = mainScene.renderer;
		this.renderer.toneMapping = THREE[`${toneMappingList[0]}ToneMapping`];
		this.scene = mainScene.scene;
		this.camera = mainScene.camera;
		this.container = mainScene.container;
		this.width = mainScene.width;
		this.height = mainScene.height;
		this.callBack = callBack;

		// Init Post-processing status
		this.initBloomPass = false;
		this.initSSAOPass = false;
		this.initFXAAPass = true;

		this.control = new OrbitControls(this.camera, this.container);
		this.initScene();
		this.initPostProcessing();
	}

	loadEnvMap(envMapName = envMapList[0]) {
		const envMapSrc = `${envMapPath}${envMapName}/`;
		return new Environment(this).loadPackage(envMapSrc);
	}

	loadSunLight(sunlightInfo) {
		if (!this.sunLight) this.sunLight = new THREE.DirectionalLight(0xffffff, 1);
		this.sunLight.position.copy(sunlightInfo.position);
		this.sunLight.castShadow = true;
		this.scene.add(this.sunLight);
	}

	loadBackground(backgroundEnv, uBGEnvironmentSize) {
		if (!this.background) {
			this.background = new Background(
				{
					envMap: backgroundEnv.texture,
					uBGEnvironmentSize,
					uEnvBrightness: this.envBrightness,
					debug: this.debug
				},
				500
			);
			this.background.material.uniforms.uEnvironmentTransform = this.envRotationMatBG;
		} else {
			// Update new background
			this.background.material.uniforms.envMap.value = backgroundEnv.texture;
			this.background.material.uniforms.uEnvironmentSize.value = uBGEnvironmentSize;
		}
	}

	async updateEnvMap(envMapName, callBack) {
		let environment = await this.loadEnvMap(envMapName);
		let {
			mapEnv,
			backgroundEnv,
			uEnvironmentSphericalHarmonics,
			uEnvironmentLodRange,
			uEnvironmentSize,
			uBGEnvironmentSize,
			sunlightInfo
		} = environment;

		this.loadSunLight(sunlightInfo);
		this.sunLightStartPos = this.sunLight.position.clone();
		this.loadBackground(backgroundEnv, uBGEnvironmentSize);

		// Sync new envmap param
		this.gltfScene.traverse(child => {
			if (child.isMesh) {
				child.material.uniforms.envMap.value = mapEnv.texture;
				child.material.uniforms['uEnvironmentSphericalHarmonics'] = { value: uEnvironmentSphericalHarmonics };
				child.material.uniforms['uEnvironmentLodRange'] = { value: uEnvironmentLodRange };
				child.material.uniforms['uEnvironmentSize'] = { value: uEnvironmentSize };
				child.material.needsUpdate = true;
			}
		});
		typeof callBack == 'function' && callBack();
	}

	async initScene() {
		let environment = await this.loadEnvMap();
		let { backgroundEnv, uBGEnvironmentSize, sunlightInfo } = environment;
		let { scene } = this;

		this.loadSunLight(sunlightInfo);
		this.loadBackground(backgroundEnv, uBGEnvironmentSize);
		scene.add(this.background);

		// Load Model
		let gltfScene = this.gltfScene;
		// Animation
		let animations = this.gltf.animations;
		if (animations && animations.length) {
			this.animationMixer = new THREE.AnimationMixer(gltfScene);
			for (let i = 0; i < animations.length; i++) {
				let animation = animations[i];
				let action = this.animationMixer.clipAction(animation);
				action.play();
			}
		}

		scene.add(gltfScene);
		this.adjustFactorFromBox(gltfScene);

		// Load Shader
		let { pbrVS, pbrFS } = this.program.getPBRShader();
		let shadowDepthRange = (this.shadowDepthRange = new THREE.Vector2(
			this.sunLight.shadow.camera.near,
			this.sunLight.shadow.camera.far
		));

		// Replace PBR Material
		gltfScene.traverse(child => {
			if (child.isMesh) {
				child.material = new PBRMaterial(child, environment, {
					pbrVS,
					pbrFS,
					shadowDepthRange
				});
				child.material.uniforms.uEnvironmentTransform = this.envRotationMat;
				child.material.uniforms.uEnvBrightness = this.envBrightness;
				child.castShadow = true;
				child.receiveShadow = true;
			}
		});

		this.initEvent();
		this.initGUI();
		typeof this.callBack === 'function' && this.callBack();
	}

	adjustFactorFromBox(object) {
		// Compute box for scale
		let box = (this.box = new THREE.Box3().setFromObject(object));
		let size = box.getSize(new THREE.Vector3());
		const maxSize = Math.max(size.x, size.y, size.z);
		// At least 100
		if (maxSize < 100) {
			let scale = 100 / maxSize;
			object.scale.setScalar(scale);
		}
		// Recompute box for center
		box = this.box = new THREE.Box3().setFromObject(object);
		let center = box.getCenter(new THREE.Vector3());
		// Move object to origin
		object.position.sub(center);
		if (this.debug) {
			let boxObj = new THREE.BoxHelper(object, 0xffff00);
			this.scene.add(boxObj);
		}
		// Camera
		adjustCameraByBox(this.camera, object, this.control, 2);
		// Background
		this.background.setSize(this.camera.far);
		// Light/Shadow
		adjustSunLightByBox(this.sunLight, this.scene, object, this.debug);
		this.sunLightStartPos = this.sunLight.position.clone();
		// Material factor
	}

	initEvent() {
		let lastMousePosition = { x: 0 };
		window.addEventListener(
			'mousemove',
			event => {
				let button = event.which || event.button;
				if (event.altKey && button) {
					event.stopPropagation();
					let deltaX = event.clientX - lastMousePosition.x;
					this.envRotation += deltaX * 0.01;
				}
				lastMousePosition.x = event.clientX;
			},
			true
		);
	}

	initPostProcessing() {
		let { scene, camera, renderer } = this;
		const renderPass = (this.renderPass = new RenderPass(scene, camera));
		const normalPass = (this.normalPass = new NormalPass(scene, camera));
		const depthEffect = new DepthEffect({
			blendFunction: BlendFunction.SKIP
		});
		const ssaoEffect = (this.ssaoEffect = new SSAOEffect(camera, normalPass.renderTarget.texture, {
			// For Test
			blendFunction: BlendFunction.MULTIPLY,
			samples: 11,
			rings: 4,
			distanceThreshold: 0.02, // Render up to a distance of ~20 world units
			distanceFalloff: 0.0025, // with an additional ~2.5 units of falloff.
			rangeThreshold: 0.0003, // Occlusion proximity of ~0.3 world units
			rangeFalloff: 0.0001, // with ~0.1 units of falloff.
			luminanceInfluence: 0.7,
			radius: 30,
			scale: 1.0,
			bias: 0.05
		}));

		// SSAO
		const ssaoEffectPass = (this.ssaoEffectPass = new EffectPass(camera, ssaoEffect, depthEffect));
		ssaoEffectPass.enabled = this.initSSAOPass;

		// Bloom
		const bloomEffect = new BloomEffect();
		const bloomEffectPass = this.bloomEffectPass = new EffectPass(camera, bloomEffect);
		bloomEffectPass.enabled = this.initBloomPass;
		
		// AA
		let fxaaMaterial = new FXAAMaterial();
		let pixelRatio = renderer.getPixelRatio();
		fxaaMaterial.uniforms[ 'resolution' ].value.x = 1 / ( this.width * pixelRatio );
		fxaaMaterial.uniforms[ 'resolution' ].value.y = 1 / ( this.height * pixelRatio );
		const fxaaPass = this.fxaaPass = new ShaderPass(fxaaMaterial);
		fxaaPass.enabled = this.initFXAAPass;

		const copyPass = new ShaderPass(new CopyMaterial());
		const composer = (this.composer = new EffectComposer(renderer, {
			frameBufferType: THREE.HalfFloatType,
		}));

		composer.addPass(renderPass);
		composer.addPass(normalPass);
		composer.addPass(ssaoEffectPass);
		composer.addPass(bloomEffectPass);
		composer.addPass(fxaaPass);
		// For keep render to screen
		composer.addPass(copyPass);
	}

	toggleBloomEffect(enable){
		this.bloomEffectPass.enabled = enable;
	}

	toggleSSAOEffect(enable) {
		this.ssaoEffectPass.enabled = enable;
	}

	toggleAAEffect(enable) {
		this.fxaaPass.enabled = enable;
	}

	initGUI() {
		let gui = new GUI();
		if (this.isMobile) gui.close();
		let gltfScene = this.gltfScene;
		let params = (this.guiParams = {
			enableIBL: !!pbrDefaultDefines.ENABLE_IBL,
			enableLight: !!pbrDefaultDefines.ENABLE_LIGHT,
			envRotation: this.envRotation,
			envBrightness: this.envBrightness.value,
			envMap: envMapList[0],
			metalness: pbrDefaultUniforms.metalness.value,
			roughness: pbrDefaultUniforms.roughness.value,
			// Equations
			diffuseEquation: diffuseEquation[0],
			specularFresnelEquation: specularFresnelEquation[0],
			specularNDFEquation: specularNDFEquation[0],
			specularVisEquation: specularVisEquation[0],
			// Anisotropy
			enableAnisotropy: !!pbrDefaultDefines.ENABLE_ANISOTROPY,
			anisotropyFactor: pbrDefaultUniforms.uAnisotropyFactor.value,
			anisotropyRotation: pbrDefaultUniforms.uAnisotropyRotation.value,
			// ClearCoat
			enableClearCoat: !!pbrDefaultDefines.ENABLE_CLEARCOAT,
			clearCoatRoughness: pbrDefaultUniforms.uClearCoatRoughness.value,
			clearCoat: pbrDefaultUniforms.uClearCoat.value,
			// Advance
			enableCompensation: !!pbrDefaultDefines.ENERGY_COMPENSATION,
			enableSpecularAA: !!pbrDefaultDefines.GEOMETRIC_SPECULAR_AA,
			specularAAVariance: pbrDefaultUniforms.uSpecularAAVariance.value,
			specularAAThreshold: pbrDefaultUniforms.uSpecularAAThreshold.value,
			specularAO: specularAOList[0],
			enableMSSpecularAO: !!pbrDefaultDefines.MS_SPECULAR_AO,
			enableMSDiffuseAO: !!pbrDefaultDefines.MS_DIFFUSE_AO,
			// Post
			toneMapping: toneMappingList[0],
			enableSSAO: this.initSSAOPass,
			enableFXAA: this.initFXAAPass,
			enableBloom: this.initBloomPass
		});
		// PBR
		const pbrFolder = gui.addFolder('PBR');
		pbrFolder.add(params, 'enableIBL').onChange(value => {
			this.guiParams.enableIBL = value;
			this.reCompileShader();
		});
		pbrFolder
			.add(params, 'enableLight')
			.name('enableSunLight')
			.onChange(value => {
				this.guiParams.enableLight = value;
				this.reCompileShader();
			});
		pbrFolder.add(params, 'envMap', envMapList).onChange(value => {
			document.querySelector('#wrapper').classList.add('isLoading');
			this.updateEnvMap(value, () => {
				document.querySelector('#wrapper').classList.remove('isLoading');
			});
		});
		pbrFolder
			.add(params, 'envRotation', -Math.PI, Math.PI)
			.step(0.1)
			.onChange(value => {
				this.envRotation = value;
			});
		pbrFolder
			.add(params, 'envBrightness', 0, 2)
			.step(0.1)
			.onChange(value => {
				this.envBrightness.value = value;
			});
		pbrFolder
			.add(params, 'metalness', 0, 1)
			.step(0.01)
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.metalness.value = value;
					}
				});
			});
		pbrFolder
			.add(params, 'roughness', 0, 1)
			.step(0.01)
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.roughness.value = value;
					}
				});
			});
		pbrFolder.open();

		// Equations
		const equationsFolder = gui.addFolder('Equations');
		equationsFolder
			.add(params, 'diffuseEquation', diffuseEquation)
			.name('diffuse')
			.onChange(value => {
				this.guiParams.diffuseEquation = value;
				this.reCompileShader();
			});
		equationsFolder
			.add(params, 'specularFresnelEquation', specularFresnelEquation)
			.name('fresnel')
			.onChange(value => {
				this.guiParams.specularFresnelEquation = value;
				this.reCompileShader();
			});
		equationsFolder
			.add(params, 'specularNDFEquation', specularNDFEquation)
			.name('NDF')
			.onChange(value => {
				this.guiParams.specularNDFEquation = value;
				this.reCompileShader();
			});
		equationsFolder
			.add(params, 'specularVisEquation', specularVisEquation)
			.name('geometry')
			.onChange(value => {
				this.guiParams.specularVisEquation = value;
				this.reCompileShader();
			});
		equationsFolder.open();

		// Anisotropy
		let anisotropyFolader = gui.addFolder('Anisotropy');
		anisotropyFolader
			.add(params, 'enableAnisotropy')
			.name('enable')
			.onChange(value => {
				this.guiParams.enableAnisotropy = value;
				this.reCompileShader();
			});
		anisotropyFolader
			.add(params, 'anisotropyRotation', -3.14, 3.14)
			.step(0.01)
			.name('rotation')
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.uAnisotropyRotation.value = value;
					}
				});
			});
		anisotropyFolader
			.add(params, 'anisotropyFactor', 0, 1)
			.name('factor')
			.step(0.01)
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.uAnisotropyFactor.value = value;
					}
				});
			});

		// ClearCoat
		let clearCoatFolader = gui.addFolder('ClearCoat');
		clearCoatFolader
			.add(params, 'enableClearCoat')
			.name('enable')
			.onChange(value => {
				this.guiParams.enableClearCoat = value;
				this.reCompileShader();
			});
		clearCoatFolader
			.add(params, 'clearCoat', 0, 1)
			.step(0.01)
			.name('clearCoat')
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.uClearCoat.value = value;
					}
				});
			});
		clearCoatFolader
			.add(params, 'clearCoatRoughness', 0, 1)
			.step(0.01)
			.name('roughness')
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.uClearCoatRoughness.value = value;
					}
				});
			});

		// Advance
		const advanceFolder = gui.addFolder('Advance');
		advanceFolder
			.add(params, 'enableCompensation')
			.name('compensation')
			.onChange(value => {
				this.guiParams.enableCompensation = value;
				this.reCompileShader();
			});
		advanceFolder
			.add(params, 'enableSpecularAA')
			.name('specularAA')
			.onChange(value => {
				this.guiParams.enableSpecularAA = value;
				this.reCompileShader();
			});
		// advanceFolder
		// 	.add(params, 'specularAAThreshold', 0, 1)
		// 	.name('sAAThreshold')
		// 	.step(0.01)
		// 	.onChange(value => {
		// 		gltfScene.traverse(child => {
		// 			if (child.isMesh) {
		// 				child.material.uniforms.uSpecularAAThreshold.value = value;
		// 			}
		// 		});
		// 	});
		advanceFolder
			.add(params, 'specularAAVariance', 0, 1)
			.name('sAAVariance')
			.step(0.01)
			.onChange(value => {
				gltfScene.traverse(child => {
					if (child.isMesh) {
						child.material.uniforms.uSpecularAAVariance.value = value;
					}
				});
			});
		advanceFolder
			.add(params, 'enableMSSpecularAO')
			.name('msSpecularAO')
			.onChange(value => {
				this.guiParams.enableMSSpecularAO = value;
				this.reCompileShader();
			});
		advanceFolder
			.add(params, 'enableMSDiffuseAO')
			.name('msDiffuseAO')
			.onChange(value => {
				this.guiParams.enableMSDiffuseAO = value;
				this.reCompileShader();
			});
		advanceFolder.add(params, 'specularAO', specularAOList).onChange(value => {
			this.guiParams.specularAO = value;
			this.reCompileShader();
		});

		// Post-Processing
		const postFolder = gui.addFolder('Post-Processing');
		postFolder.add(params, 'toneMapping', toneMappingList).onChange(value => {
			this.renderer.toneMapping = THREE[`${value}ToneMapping`];
			this.reCompileShader(true);
		});
		postFolder
			.add(params, 'enableSSAO')
			.name('SSAO')
			.onChange(value => {
				this.toggleSSAOEffect(value);
			});
		postFolder
			.add(params, 'enableBloom')
			.name('Bloom')
			.onChange(value => {
				this.toggleBloomEffect(value);
			});
		postFolder
			.add(params, 'enableFXAA')
			.name('FXAA')
			.onChange(value => {
				this.toggleAAEffect(value);
			});
	}

	setDefinesFromGUI(defines) {
		let guiParams = this.guiParams;
		// Clean
		let reg = panelDefinesRegs;
		Object.keys(defines).map(key => {
			if (reg.test(key)) {
				delete defines[key];
			}
		});
		// Reset
		if (guiParams.enableIBL) defines.ENABLE_IBL = 1;
		if (guiParams.enableLight) defines.ENABLE_LIGHT = 1;
		if (guiParams.enableAnisotropy) defines.ENABLE_ANISOTROPY = 1;
		if (guiParams.enableClearCoat) defines.ENABLE_CLEARCOAT = 1;
		if (guiParams.enableCompensation) defines.ENERGY_COMPENSATION = 1;
		if (guiParams.enableSpecularAA) defines.GEOMETRIC_SPECULAR_AA = 1;
		if (guiParams.enableMSSpecularAO) defines.MS_SPECULAR_AO = 1;
		if (guiParams.enableMSDiffuseAO) defines.MS_DIFFUSE_AO = 1;

		defines[`DIFFUSE_${guiParams.diffuseEquation.toUpperCase()}`] = 1;
		defines[`F_${guiParams.specularFresnelEquation.toUpperCase()}`] = 1;
		defines[`NDF_${guiParams.specularNDFEquation.toUpperCase()}`] = 1;
		defines[`V_${guiParams.specularVisEquation.toUpperCase()}`] = 1;
		defines[`SPECULAR_AO_${guiParams.specularAO.toUpperCase()}`] = 1;
		return defines;
	}

	reCompileShader(updateBG) {
		this.gltfScene.traverse(child => {
			if (child.isMesh && child.material) {
				this.setDefinesFromGUI(child.material.defines);
				child.material.needsUpdate = true;
			}
		});
		if (updateBG) this.background.material.needsUpdate = true;
	}

	updateEnvironmentRotation(value) {
		// Get panel rotation
		this.envRotationFromPanel.makeRotationY(value);
		// Sync camera roatation
		this.cameraRotationMatrix.makeRotationFromQuaternion(this.camera.quaternion);
		this.envRotationMat4.multiplyMatrices(this.envRotationFromPanel, this.cameraRotationMatrix);
		this.envRotationMat.value.setFromMatrix4(this.envRotationMat4);
		this.envRotationMatBG.value.setFromMatrix4(this.envRotationFromPanel);
		// Direction compute by position
		let resultSunlight = this.sunLightStartPos.clone();
		this.sunLightPanelRotateMat.getInverse(this.envRotationFromPanel);
		resultSunlight.applyMatrix4(this.sunLightPanelRotateMat);
		this.sunLight.position.copy(resultSunlight);
	}

	resize(width, height) {
		this.width = width;
		this.height = height;
		this.camera.aspect = this.width / this.height;
		this.camera.updateProjectionMatrix();
		this.composer.setSize(width, height);
	}

	update() {
		let deltaTime = this.clock.getDelta();
		this.updateEnvironmentRotation(this.envRotation);
		if (this.animationMixer) this.animationMixer.update(deltaTime);
		// this.renderer.render(this.scene, this.camera);
		this.composer.render(deltaTime);
	}
}
