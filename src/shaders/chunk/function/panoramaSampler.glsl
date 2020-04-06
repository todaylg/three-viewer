// For y up
vec2 normalToPanoramaUV(vec3 dir){
    float n = length(dir.xz);

    // to avoid bleeding the max(-1.0,dir.x / n) is needed
    vec2 pos = vec2( (n>0.0000001) ? max(-1.0,dir.x / n) : 0.0, dir.y);

    // fix edge bleeding
    if ( pos.x > 0.0 ) pos.x = min( 0.999999, pos.x );

    pos = acos(pos)*0.31830988618; // RECIPROCAL_PI

    pos.x = (dir.z > 0.0) ? pos.x*0.5 : 1.0-(pos.x*0.5);

    // shift u to center the panorama to -z
    pos.x = mod(pos.x-0.25+1.0, 1.0 );
    pos.y = 1.0-pos.y;
    return pos;
}


vec2 computeUVForMipmap(float level, vec2 uv, float size, float maxLOD){
    // width for level
    float widthForLevel = exp2( maxLOD-level);

    // the height locally for the level in pixel
    // to opimitize a bit we scale down the v by two in the inputs uv
    float heightForLevel = widthForLevel * 0.5;

    // compact version
    float texelSize = 1.0/size;
    vec2 uvSpaceLocal =  vec2(1.0) + uv * vec2(widthForLevel - 2.0, heightForLevel - 2.0);
    uvSpaceLocal.y += size - widthForLevel;
    return uvSpaceLocal * texelSize;
}

vec4 texturePanoramaLod(sampler2D tex, vec2 size , vec3 direction, float lod, float maxLOD){
    vec2 uvBase = normalToPanoramaUV(direction);
    // we scale down v here because it avoid to do twice in sub functions
    // uvBase.y *= 0.5;
    float lod0 = floor(lod);
    vec2 uv0 = computeUVForMipmap(lod0, uvBase, size.x, maxLOD);
    vec4 texel0 = texture2D(tex, uv0.xy);

    float lod1 = ceil(lod);
    vec2 uv1 = computeUVForMipmap(lod1, uvBase, size.x, maxLOD);
    vec4 texel1 = texture2D(tex, uv0.xy);

    return mix(texel0, texel1, fract(lod));
}