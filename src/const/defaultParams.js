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
	uBrightness:{
		value: 1.0
	},
	uEnvironmentTransform: {
		value: new THREE.Matrix4()
	},
}

const pbrDefaultUniforms = {
	roughness: {
		value: 1.0
	},
	metalness: {
		value: 0.5
	},
	color: {
		value: new THREE.Color(0xffffff)
	},
	emissive: {
		value: new THREE.Color(0x000000)
	},
	uEnvironmentTransform: {
		value: new THREE.Matrix4()
	},
	uBrightness:{
		value: 1.0
	},
};

const pbrDefaultDefines = {
	ENABLE_IBL: 1,
	ENABLE_LIGHT: 1,
	DIFFUSE_LAMBERT: 1,
	NDF_GGX: 1,
	F_SCHLICK: 1,
	V_SMITHJOINTAPPROX: 1,
};

export { syncMapArr, syncUniformArr, pbrDefaultUniforms, bgDefaultUniforms, pbrDefaultDefines };
