import * as THREE from 'three';
import { isGunzipBuffer, gunzip } from './zlib';

export default class CubeMapEnv {
	constructor(data, size, options) {
		this._options = options || {};
		this._size = size;
		this._data = data;
	}

	// Convert to RGBA Buffer
    deinterleaveImage4(size, src, dst){
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

			const maxLevel = Math.log(this._size) / Math.LN2;
			let offset = 0;
			let images = {};
			// Load cube mipmaps data
			// Per mipmaps level => 6 faces data
			for (let i = 0; i <= maxLevel; i++) {
				let size = Math.pow(2, maxLevel - i);
				let byteSize;
				if (offset >= data.byteLength) break;
				for (let face = 0; face < 6; face++) {
					// Add entry if does not exist
					if (!images[face]) images[face] = [];
					let imageData;
					let deinterleave;
					
					// RGBA
					byteSize = size * size * 4;
					// Read a block of data
					imageData = new Uint8Array(data, offset, byteSize);
					// Split it
					deinterleave = new Uint8Array(byteSize);
					// Todo: deinterleave all just once
					this.deinterleaveImage4(size, imageData, deinterleave);

					imageData = deinterleave;
					images[face].push(imageData);
					// Next block
					offset += byteSize;
				}
			}
			this._packedImages = images;
			this.createRGBA8Packed();
		};

		return readInputArray(this._data);
    }

    createRGBA8Packed(){
        let cubeTextures = this.cubeTextures = [];
		let size = this._size;
		let packedImages = this._packedImages;
		// CubeTexture Mipmap
		const numMips = packedImages[0].length;
		// Todo: encoding
		let textureEncoding = THREE.LogLuvEncoding;

        for (let mip = 0; mip < numMips; mip++) {
			let cubeTexture = new THREE.CubeTexture();
            cubeTextures.push(cubeTexture);
			cubeTexture.format = THREE.RGBAFormat;
			cubeTexture.encoding = textureEncoding; 
			// Todo: cubeTexture.type
            cubeTexture.minFilter = THREE.LinearMipMapLinearFilter;
            cubeTexture.magFilter = THREE.LinearFilter;
			cubeTexture.generateMipmaps = false;
			
			// Get per face data	
			for (let face = 0; face < 6; face++) {
				let dataTexture = new THREE.DataTexture(packedImages[face][mip], size, size, THREE.RGBAFormat);
				dataTexture.format = cubeTexture.format;
				dataTexture.encoding = textureEncoding;
				dataTexture.type = cubeTexture.type;
				dataTexture.generateMipmaps = false;
				cubeTexture.images[face] = dataTexture;
				cubeTexture.needsUpdate = true;
			}
			cubeTexture.needsUpdate = true;
			size = size / 2;
		}
		// Integrate
		this.texture = new THREE.CubeTexture();
        this.texture.format = THREE.RGBAFormat;
        this.texture.encoding = textureEncoding;
        this.texture.minFilter = this._options.minFilter || THREE.LinearMipMapLinearFilter;
        this.texture.magFilter = this._options.magFilter || THREE.LinearFilter;
        this.texture.generateMipmaps = false;
        
        for(let i = 0; i < 6; i ++) {
            this.texture.image[i] = this.cubeTextures[0].images[i];
            for( let m = 1; m < numMips; m++ ) {
                this.texture.mipmaps[m-1] = this.cubeTextures[m];
                this.cubeTextures[m].needsUpdate = true;
            }
        }
		this.texture.needsUpdate = true;
    }
}
