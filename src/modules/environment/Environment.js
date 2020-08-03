// refer: https://github.com/cedricpinson/osgjs

import * as THREE from 'three';
import EnvironmentCubeMap from './EnvironmentCubeMap';
import EnvironmentPanorama from './EnvironmentPanorama';
import IntegrateBRDFMap from './IntegrateBRDFMap';
import EnvironmentSphericalHarmonics from './EnvironmentSphericalHarmonics';

const brdfLUTPath = './assets/envMap/brdf_ue4.bin.gz';

class Environment {
	constructor(viewer) {
		let { renderer, isMobile } = viewer;
		this.isMobile = isMobile;
		let ctx = renderer.getContext();
		this.textureLODSupport = ctx.getExtension('EXT_shader_texture_lod');
		this._config = null;
		this._files = {};
		this.fileLoader = new THREE.FileLoader();
		this.uIntegrateBRDF = null;
	}

	async loadPackage(url) {
		this.url = url;
		const configSrc = `${url}config.json`;
		let config = await await this.loadDataFromFile(configSrc, 'json');
		return await this.init(config);
	}

	getImage(type, encoding, format) {
		let results = this.getTextures(type, encoding, format);
		if (!results.length) return undefined;
		// Check limitSize(Prefilter stop size)
		if (results[0].limitSize) results[0].images[0].limitSize = results[0].limitSize;
		return results[0].images[0];
	}

	// Filter texture by condition
	getTextures(type, encoding, format) {
		let textures = this._config.textures;
		let results = textures.filter(texture => {
			return texture.encoding === encoding && texture.format === format && texture.type === type;
		});
		return results;
	}

	loadDataFromFile(url, responseType = 'arraybuffer'){
		this.fileLoader.setResponseType(responseType);
		return new Promise(resolve => this.fileLoader.load(url, data => resolve(data)));
	}

	async init(config) {
		// LUV format only (Todo: Support More format)
		this._config = config;

		let envMapFormat = 'panorama';
		if(this.textureLODSupport) envMapFormat = 'cubemap';

		let textureData = this.getImage('specular_ue4', 'luv', envMapFormat);
		let mapFile = textureData.file;
		let mapSize = textureData.width;
		let mapData = await this.loadDataFromFile(`${this.url}${mapFile}`);
		if(envMapFormat === 'cubemap'){
			this.mapEnv = new EnvironmentCubeMap(mapData, mapSize, config);
		}else{
			this.mapEnv = new EnvironmentPanorama(mapData, mapSize, config);
		}
		this.mapEnv.loadPacked();
		let minTextureSize = textureData.limitSize;
		let nbLod = Math.log(mapSize) / Math.LN2;
		let maxLod = nbLod - Math.log(minTextureSize) / Math.LN2;
		this.uEnvironmentLodRange = [nbLod, maxLod];
		this.uEnvironmentSize = [mapSize, envMapFormat == 'cubemap'? mapSize: mapSize/2];
		
		if(!this.uIntegrateBRDF){
			// LUT
			let lutTextureData = this.getImage('brdf_ue4', 'rg16', 'lut');
			let lutSize = lutTextureData.width;
			let lutData = await this.loadDataFromFile(brdfLUTPath);
			this._integrateBRDF = new IntegrateBRDFMap(lutData, lutSize);
			this.uIntegrateBRDF = this._integrateBRDF.loadPacked();
		}

		// Background
		let bgTextureData = this.getImage('background', 'luv', 'cubemap');
		let bgFile = bgTextureData.file;
		let bgSize = bgTextureData.width;
		let bgData = await this.loadDataFromFile(`${this.url}${bgFile}`);
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
