const envMapPath = './assets/envMap/';

const envMapList = [
    'Arches',
    'Alexs',
	'GCanyon',
	'Industrial',
	'Milkyway',
	'Outside',
	'PaperMill',
	'Royal',
    'TropicalRuins',
    'Venice',
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
	'HammonApprox'
];

const toneMappingList = [
	'ACESFilmic',
	'Linear',
	'Reinhard',
	'Uncharted2',
	'Cineon',
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