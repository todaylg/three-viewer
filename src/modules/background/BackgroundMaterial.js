import * as THREE from 'three';
import { bgDefaultUniforms } from '../../const/defaultParams';
import backgroundVS from './shaders/backgroundVS';
import backgroundFS from './shaders/backgroundFS';

class BackgroundMaterial extends THREE.ShaderMaterial {
	constructor(options) {
		let { envMap, uBGEnvironmentSize, uEnvBrightness, debug } = options;
		let { uEnvironmentTransform } = bgDefaultUniforms;
		let uniforms = {
			envMap: { value: envMap },
			uEnvironmentSize: { value: uBGEnvironmentSize},
			uEnvBrightness,
			uEnvironmentTransform
		};
		super({
			uniforms,
			vertexShader: backgroundVS,
			fragmentShader: backgroundFS,
			side: THREE.DoubleSide,
			depthTest: debug ? true : false
		});
	}
}

export { BackgroundMaterial }