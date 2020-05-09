import * as THREE from 'three';
import ModelViewer from './js/ModelViewer';
// Utils
import { getEleWidth, getEleHeight } from './js/Utils';

export default class MainScene {
	constructor(container, gltf, callback) {
		this.container = container;
		this.time = 0;
		this.width = getEleWidth(container);
		this.height = getEleHeight(container);
		// Camera
		const camera = (this.camera = new THREE.PerspectiveCamera(45, this.width / this.height, 0.1, 1000));
		camera.position.set(0, 0, 10);
		// Renderer
		const renderer = (this.renderer = new THREE.WebGLRenderer({
			antialias: false
		}));
		renderer.domElement.id = 'canvasWebGL';
		renderer.setPixelRatio(window.devicePixelRatio);
		renderer.setSize(this.width, this.height);
		renderer.setClearColor(0xffffff, 1.0);
		renderer.shadowMap.enabled = true;
		renderer.gammaFactor = 2.2;
		renderer.outputEncoding = THREE.sRGBEncoding;
		container.appendChild(renderer.domElement);
		// Scene
		this.initScene(gltf, callback);
		// Events
		this.initEvents();
	}

	initScene(gltf, callback) {
		this.scene = new THREE.Scene();
		this.modelViewer = new ModelViewer(this, gltf, () => {
			this.loaded = true;
			this.onWindowResize();
			typeof callback === 'function' && callback();
		});
		this.animete();
	}

	initEvents() {
		window.addEventListener('resize', this.onWindowResize.bind(this), false);
	}

	onWindowResize() {
		if(!this.loaded) return;
		this.width = getEleWidth(this.container);
		this.height = getEleHeight(this.container);
		this.modelViewer.resize(this.width, this.height);
	}

	animete(nowTime) {
		if(this.loaded) this.modelViewer.update(nowTime);
		requestAnimationFrame(this.animete.bind(this));
	}
}
