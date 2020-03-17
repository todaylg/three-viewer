import * as THREE from 'three';
import { isGunzipBuffer, gunzip } from './zlib';

export default class IntegrateBRDF {
	constructor(data, size) {
        this._data = data;
		this._size = size;
    }
    
	loadPacked() {
		let readInputArray = inputArray => {
			let size = this._size;
			let data = inputArray;
            if (isGunzipBuffer(data)) data = gunzip(data);
            
            let byteSize = size * size * 4;
			let imageData = new Uint8Array(data, 0, byteSize);
            let _texture = new THREE.DataTexture(imageData, size, size, THREE.RGBAFormat);
            return _texture;
		};

		return readInputArray(this._data);
    }

}
