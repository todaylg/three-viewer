import computeDiffuseSPH from './chunk/function/computeDiffuseSPH.glsl';
import integrateBRDFMobile from './chunk/function/integrateBRDFMobile.glsl';
import panoramaSampler from './chunk/function/panoramaSampler.glsl';
import precomputeLight from './chunk/function/precomputeLight.glsl';
import isotropyLightCompute from './chunk/function/isotropyLightCompute.glsl';

import math from './chunk/math.glsl';
import shadow from './chunk/shadow.glsl';
import light from './chunk/light.glsl';
import brdf from './chunk/brdf.glsl';
import ibl from './chunk/ibl.glsl';
import specularAO from './chunk/specularAO.glsl';

export default {
	computeDiffuseSPH,
	integrateBRDFMobile,
	panoramaSampler,
    precomputeLight,
    isotropyLightCompute,

	math,
	shadow,
	light,
	brdf,
	ibl,
	specularAO
};
