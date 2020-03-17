uniform mat3 uModelNormalMatrix;
varying vec3 vViewPosition;

varying vec3 vNormal;

#ifdef USE_TANGENT
	varying vec3 vTangent;
	varying vec3 vBitangent;
#endif

#include <uv_pars_vertex>
#include <uv2_pars_vertex>
#include <color_pars_vertex>
#include <logdepthbuf_pars_vertex>
#include <shadowmap_pars_vertex>

void main(){
	#include <uv_vertex>
	#include <uv2_vertex>
    #include <color_vertex>
    #include <beginnormal_vertex>
	#include <defaultnormal_vertex>
	// Todo: morph and skin

	vNormal = normalize( transformedNormal );
	#ifdef USE_TANGENT
		vTangent = normalize( transformedTangent );
		vBitangent = normalize( cross( vNormal, vTangent ) * tangent.w );
	#endif

    #include <begin_vertex>
	#include <project_vertex>

    vViewPosition = mvPosition.xyz;

	#include <worldpos_vertex>
	#include <logdepthbuf_vertex>
	#include <shadowmap_vertex>
}
