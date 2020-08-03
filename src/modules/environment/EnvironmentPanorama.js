import * as THREE from 'three';
import { isGunzipBuffer, gunzip } from './zlib';

export default class PanoramaEnv {
	constructor(data, size, options) {
		this._options = options || {};
		this._size = size;
		this._data = data;
		this._texture = null;
	}

	get texture() {
		return this._texture;
	}

	// Convert to RGBA Buffer
	deinterleaveImage4(size, src, dst) {
		let npixel = size * size;
		let npixel2 = 2 * size * size;
		let npixel3 = 3 * size * size;
		let idx = 0;
		for (let i = 0; i < npixel; i++) {
			dst[idx++] = src[i];
			dst[idx++] = src[i + npixel];
			dst[idx++] = src[i + npixel2];
			dst[idx++] = src[i + npixel3];
		}
	}

	loadPacked() {
		let readInputArray = inputArray => {
			let data = inputArray;
			if (isGunzipBuffer(data)) data = gunzip(data);

			let size = this._size;
			let imageData, deinterleave;

			imageData = new Uint8Array(data);
			deinterleave = new Uint8Array(data.byteLength);
			this.deinterleaveImage4(size, imageData, deinterleave);

			imageData = deinterleave;

			let dataTexture = new THREE.DataTexture(imageData, size, size, THREE.RGBAFormat);
			dataTexture.encoding = THREE.LogLuvEncoding;
			dataTexture.flipY = true;
			dataTexture.needsUpdate = true;
			dataTexture.magFilter = THREE.LinearFilter;
			dataTexture.minFilter = THREE.LinearFilter;
			this._texture = dataTexture;
		};

		return readInputArray(this._data);
	}
}
