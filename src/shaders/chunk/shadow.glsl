// Shadow
uniform bool receiveShadow;
#ifdef USE_SHADOWMAP
	#if NUM_DIR_LIGHT_SHADOWS > 0
        struct DirectionalLightShadow {
			float shadowBias;
			float shadowRadius;
			vec2 shadowMapSize;
		};
        uniform DirectionalLightShadow directionalLightShadows[ NUM_DIR_LIGHT_SHADOWS ];
        
		uniform sampler2D directionalShadowMap[ NUM_DIR_LIGHT_SHADOWS ];
		varying vec4 vDirectionalShadowCoord[ NUM_DIR_LIGHT_SHADOWS ];
	#endif
	
	float texture2DShadowLerp( sampler2D depths, vec2 size, vec2 uv, float compare, float shadowDistance) {
        vec2 centroidCoord = uv / size;
        centroidCoord = centroidCoord + 0.5;
        vec2 f = fract(centroidCoord);

		vec2 texelSize = vec2( 1.0 ) / size;
		vec2 centroidUV = ( floor( uv * size - 0.5 ) + 0.5 ) * texelSize;

        vec4 fetches;
        const vec2 offset = vec2( 0.0, 1.0 );
        fetches.x = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.xx ));
        fetches.y = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.xy ));
        fetches.z = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.yx ));
        fetches.w = compare - unpackRGBAToDepth( texture2D( depths, centroidUV + texelSize * offset.yy ));

        // Shadow distance
        float _a = mix(fetches.x, fetches.y, f.y);
        float _b = mix(fetches.z, fetches.w, f.y);
        shadowDistance = mix(_a, _b, f.x);

		vec4 st = step(fetches, vec4(0.0));

        float a = mix(st.x, st.y, f.y);
        float b = mix(st.z, st.w, f.y);
        return mix(a, b, f.x);
	}

	float getShadow(bool lighted, sampler2D shadowMap, vec2 shadowMapSize, float shadowBias, float shadowRadius, vec4 shadowCoord, out float shadowDistance ) {
        bool earlyOut = false;
        float shadow = 1.0;

        if (!lighted){
            shadow = 0.0;
            earlyOut = true;
        }

        if(uShadowDepthRange.x == uShadowDepthRange.y){
            earlyOut = true;
        }

        if (!earlyOut) {
            shadowCoord.xyz /= shadowCoord.w;
            shadowCoord.z += shadowBias;
            // if ( something && something ) breaks ATI OpenGL shader compiler
            // if ( all( something, something ) ) using this instead
            bvec4 inFrustumVec = bvec4 ( shadowCoord.x >= 0.0, shadowCoord.x <= 1.0, shadowCoord.y >= 0.0, shadowCoord.y <= 1.0 );
            bool inFrustum = all( inFrustumVec );
            bvec2 frustumTestVec = bvec2( inFrustum, shadowCoord.z <= 1.0 );
            bool frustumTest = all( frustumTestVec );
            if ( frustumTest ) {
                vec2 texelSize = vec2( 1.0 ) / shadowMapSize;
                // TODO: Shadow jitter
                float res = texture2DShadowLerp( shadowMap, shadowMapSize, shadowCoord.xy, shadowCoord.z, shadowDistance);
                shadow = res;
            }
        }
		return shadow;
	}
#endif