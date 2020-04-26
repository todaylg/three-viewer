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
	'Venice'
];

const diffuseEquation = ['Lambert', 'Burley', 'OrenNayar', 'Gotanda', 'None'];

const specularFresnelEquation = ['Schlick', 'CookTorrance', 'None'];

const specularNDFEquation = ['GGX', 'BlinnPhong', 'Beckmann'];

const specularVisEquation = ['SmithJointApprox', 'Implicit', 'Neumann', 'Kelemen', 'Schlick', 'Smith', 'HammonApprox'];

const toneMappingList = ['ACESFilmic', 'Linear', 'Reinhard', 'Uncharted2', 'Cineon', 'No'];

const specularAOList = ['Seblagarde', 'Marmosetco', 'None'];

const panelDefinesRegs = /(ENABLE_IBL)|(ENABLE_LIGHT)|(ENABLE_ANISOTROPY)|(ENABLE_CLEARCOAT)|(ENERGY_COMPENSATION)|(DIFFUSE_*)|(F_*)|(NDF_*)|(V_*)|(SPECULAR_AO_*)|(GEOMETRIC_SPECULAR_AA)|(MS_SPECULAR_AO)|(MS_DIFFUSE_AO)/;

export {
	envMapPath,
	envMapList,
	diffuseEquation,
	specularFresnelEquation,
	specularNDFEquation,
	specularVisEquation,
	toneMappingList,
	specularAOList,
	panelDefinesRegs
};
