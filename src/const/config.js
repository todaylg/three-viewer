const envMapPath = './assets/envMap/';

const envMapList = [
    'Arches',
    'GCanyon',
    'Milkyway',
    'PaperMill',
    'Venice',
    'TropicalRuins',
    'Alexs',
    'Pedestrian'
];

const diffuseEquation = [
	'Lambert',
	'Burley',
	'OrenNayar',
	'Gotanda',
	'None'
];

const specularFresnelEquation = [
	'Schlick',
	'CookTorrance',
	'None',
];

const specularNDFEquation = [
	'GGX',
	'BlinnPhong',
	'Beckmann',
];

const specularVisEquation = [
	'SmithJointApprox',
	'Implicit',
	'Neumann',
	'Kelemen',
	'Schlick',
	'Smith',
];

const toneMappingList = [
	'Linear',
	'Reinhard',
	'Uncharted2',
	'Cineon',
	'ACESFilmic',
	'No',
];

export {
    envMapPath,
    envMapList,
    diffuseEquation,
    specularFresnelEquation,
    specularNDFEquation,
	specularVisEquation,
	toneMappingList
}