import { ShaderMaterial, Uniform, Vector2 } from "three";

import fragmentShader from "./glsl/fxaa/shader.frag";
import vertexShader from "./glsl/common/shader.vert";

export class FXAAMaterial extends ShaderMaterial {
	constructor() {
		super({
            type: "FXAAMaterial",
            
			uniforms: {
				inputBuffer: new Uniform(null),
				resolution: { value: new Vector2(1 / 1024, 1 / 512) },
			},
            
            fragmentShader,
            vertexShader,
            
			depthWrite: false,
			depthTest: false

        });
        
		/** @ignore */
		this.toneMapped = false;
	}

}
