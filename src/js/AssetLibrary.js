// Todo: Resolve the conflict with the Environment loading
import * as THREE from 'three';
import Signal from './Signal';
import { GLTFLoader } from 'LIB/threejs/loaders/GLTFLoader';

export default class AssetLibrary {
	constructor(basePath = './') {
		if (basePath.charAt(basePath.length - 1) != '/') basePath += '/';
		this.basePath = basePath;
		this.loadedNumber = 0;
		this.loadQueue = [];
		this.assets = {};
		this.onCompleteEvent = new Signal();
		this.onProgressEvent = new Signal();
	}

	get onComplete() {
		return this.onCompleteEvent;
	}

	get onProgress() {
		return this.onProgressEvent;
	}

	get(key) {
		return this.assets[key];
	}

	set(key, value) {
		this.assets[key] = value;
	}

	addLoadQueue(key, path, type, parser) {
		this.loadQueue.push({ key, filePath: this.basePath + path, type, parser });
	}

	load() {
		if (this.loadQueue.length === 0) return void this.onComplete.dispatch();
		let asset = this.loadQueue[this.loadedNumber];
		switch (asset.type) {
			case 'Texture':
				this.loadTexture(asset.filePath, asset.key, asset.parser);
				break;
			case 'Model':
				this.loadModel(asset.filePath, asset.key, asset.parser);
				break;
			default:
				console.error(`No support ${asset.type} type asset!`);
				break;
		}
	}

	loadTexture(filePath, key, parser) {
		let loader = new (parser || THREE.TextureLoader)();
		this.assets[key] = loader.load(filePath, () => {
			this.onAssetLoaded();
		});
	}

	loadModel(filePath, key, parser) {
		let loader = new (parser || GLTFLoader)();
		loader.load(filePath, model => {
			this.assets[key] = model;
			this.onAssetLoaded();
		});
	}

	onAssetLoaded() {
		this.onProgress.dispatch(this.loadedNumber / this.loadQueue.length);
		if (this.loadedNumber === this.loadQueue.length - 1) {
			this.onComplete.dispatch(this);
		} else {
			// Continue load next asset
			this.load();
		}
	}
}
