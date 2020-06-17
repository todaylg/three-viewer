import * as THREE from 'three';

const syncMapArr = [
	'map',
	'normalMap',
	'lightMap',
	'bumpMap',
	'roughnessMap',
	'metalnessMap',
	'aoMap',
	'emissiveMap',
	'displacementmap',
];

const syncUniformArr = [
	'color',
	'roughness',
	'metalness',
	'emissive',
]

const bgDefaultUniforms = {
	uEnvBrightness:{
		value: 1.0
	},
	uEnvironmentTransform: {
		value: new THREE.Matrix3()
	},
}

const pbrDefaultUniforms = {
	roughness: {
		value: .5
	},
	metalness: {
		value: 0.
	},
	color: {
		value: new THREE.Color(0xffffff)
	},
	emissive: {
		value: new THREE.Color(0x000000)
	},
	uEnvironmentTransform: {
		value: new THREE.Matrix3()
	},
	uEnvBrightness:{
		value: 1.0
	},
	uSpecularAAVariance:{
		value: .1
	},
	uSpecularAAThreshold:{
		value: 1.0
	},
	// Anisotropy
	uAnisotropyRotation: {
		value: 0
	},
	uAnisotropyFactor: {
		value: 0.5
	},
	// ClearCoat
	uClearCoatRoughness: {
		value: 0.5
	},
	uClearCoat: {
		value: 0.5
	},
};

const pbrDefaultDefines = {
	ENABLE_IBL: 1,
	ENABLE_LIGHT: 1,
	ENERGY_COMPENSATION: 1,
	DIFFUSE_LAMBERT: 1,
	NDF_GGX: 1,
	F_SCHLICK: 1,
	V_SMITHJOINTAPPROX: 1,
	// ENABLE_ANISOTROPY: 1,
	// ENABLE_CLEARCOAT: 1,
	// GEOMETRIC_SPECULAR_AA: 1
	SPECULAR_AO_SEBLAGARDE: 1,
	MS_SPECULAR_AO: 1,
	MS_DIFFUSE_AO: 1
};

export { syncMapArr, syncUniformArr, pbrDefaultUniforms, bgDefaultUniforms, pbrDefaultDefines };
