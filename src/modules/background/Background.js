import * as THREE from 'three';
import { BackgroundMaterial } from './BackgroundMaterial';

 class Background extends THREE.Mesh {
	constructor(uniforms, size = 1000) {
		const radius = size / 2;
		let sphere = new THREE.SphereGeometry(radius, 20, 20);
		let material = new BackgroundMaterial(uniforms);
		super(sphere, material);
		this.radius = radius;
		this.sphere = sphere;
	}

	get envMap() {
		return this.material.envMap;
	}
	
	set envMap(envMap) {
		this.material.envMap = envMap;
	}

	get mesh() {
		return this.sphere;
	}

	setSize(size){
		let scale = size / this.radius;
		// Half
		this.scale.setScalar(scale);
	}
}

export { Background };