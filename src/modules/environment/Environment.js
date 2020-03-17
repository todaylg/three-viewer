// refer: https://github.com/cedricpinson/osgjs

import * as THREE from 'three';
import EnvironmentCubeMap from './EnvironmentCubeMap';
import IntegrateBRDFMap from './IntegrateBRDFMap';
import EnvironmentSphericalHarmonics from './EnvironmentSphericalHarmonics';
import fileHelper from './fileHelper';

class Environment {
	constructor() {
		this._config = undefined;
		this._files = {};
	}

	async loadPackage(urlOfFile) {
		let filesMap = await fileHelper.unzip(urlOfFile);
		return this.readZipContent(filesMap, urlOfFile);
	}

	readZipContent(filesMap, url) {
		const envName = url
			.split('/')
			.pop()
			.split('.zip')[0];
		this.name = envName;

		for (let filename in filesMap) {
			let data = filesMap[filename];
			let name = filename.split('/').pop();
			this._files[name] = data;
		}

		return this.init(this._files['config.json']);
	}

	getImage(type, encoding, format) {
		let results = this.getTextures(type, encoding, format);
		if (!results.length) return undefined;
		// Add limitSize
		if (results[0].limitSize) results[0].images[0].limitSize = results[0].limitSize;
		return results[0].images[0];
	}

	// Filter texture by condition
	// Todo: Sync encoding param
	getTextures(type, encoding, format) {
		let textures = this._config.textures;
		let results = textures.filter(texture => {
			return texture.encoding === encoding && texture.format === format && texture.type === type;
		});
		return results;
	}

	init(config) {
		// LUV format only
		// Todo: More format
		this._config = config;

		// Todo: Panorama

		// CubeMap
		let cubeMapTextureData = this.getImage('specular_ue4', 'luv', 'cubemap');
		let cubeMapFile = cubeMapTextureData.file;
		let cubeMapSize = cubeMapTextureData.width;
		let cubeMapData = this._files[cubeMapFile];
		this.cubeMapEnv = new EnvironmentCubeMap(cubeMapData, cubeMapSize, config);
		this.cubeMapEnv.loadPacked();
		let minTextureSize = cubeMapTextureData.limitSize;
		let nbLod = Math.log(cubeMapSize) / Math.LN2;
        let maxLod = nbLod - Math.log(minTextureSize) / Math.LN2;
		this.uEnvironmentLodRange = [nbLod, maxLod];
		this.uEnvironmentSize = [cubeMapSize, cubeMapSize];

		// LUT
		let lutTextureData = this.getImage('brdf_ue4', 'rg16', 'lut');
		let lutFile = lutTextureData.file;
		let lutSize = lutTextureData.width;
		let lutData = this._files[lutFile];
		this._integrateBRDF = new IntegrateBRDFMap(lutData, lutSize);
		this.uIntegrateBRDF = this._integrateBRDF.loadPacked();

		// Background
		let bgTextureData = this.getImage('background', 'luv', 'cubemap');
		let bgFile = bgTextureData.file;
		let bgSize = bgTextureData.width;
		let bgData = this._files[bgFile];
		this.backgroundEnv = new EnvironmentCubeMap(bgData, bgSize, {
			minFilter: THREE.LinearFilter,
            magFilter: THREE.LinearFilter
		});
		this.backgroundEnv.loadPacked();
		this.uBGEnvironmentSize = [bgSize, bgSize];

		// EnvironmentSphericalHarmonics
		this._spherical = new EnvironmentSphericalHarmonics(config.diffuseSPH);
		this.uEnvironmentSphericalHarmonics = this._spherical._uniformSpherical;

		// Light
		if(config.Lights){
			let sunlight = config.Lights[0];
			this.sunlightInfo = {
				color: new THREE.Color().fromArray(sunlight.color),
				position: new THREE.Vector3().fromArray(sunlight.direction).negate(),
				intensity: sunlight.luminosity
			}
		}
		return this;
	}
}

export { Environment };
