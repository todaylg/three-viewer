uniform mat3 uModelNormalMatrix;
varying vec3 vViewPosition;

varying vec3 vNormal;
varying vec3 vWorldNormal;

#ifdef USE_TANGENT
	varying vec3 vTangent;
	varying vec3 vBitangent;
#endif

#include <uv_pars_vertex>
#include <uv2_pars_vertex>
#include <color_pars_vertex>
#include <morphtarget_pars_vertex>
#include <skinning_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>

void main(){
	#include <uv_vertex>
	#include <uv2_vertex>
    #include <color_vertex>
    #include <beginnormal_vertex>
	#include <morphnormal_vertex>
	#include <skinbase_vertex>
	#include <skinnormal_vertex>
	#include <defaultnormal_vertex>

	vNormal = normalize(transformedNormal);
	vWorldNormal = uModelNormalMatrix * objectNormal;

	#ifdef USE_TANGENT
		vTangent = normalize(transformedTangent);
		vBitangent = normalize(cross(vNormal, vTangent) * tangent.w);
	#endif

    #include <begin_vertex>
	#include <morphtarget_vertex>
	#include <skinning_vertex>
	#include <project_vertex>

    vViewPosition = mvPosition.xyz;

	#include <worldpos_vertex>
	#include <logdepthbuf_vertex>
	#include <shadowmap_vertex>
}
