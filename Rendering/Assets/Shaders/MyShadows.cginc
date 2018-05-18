#ifndef MY_SHADOWS_INCLUDED
#define MY_SHADOWS_INCLUDED

#include "UnityCG.cginc"

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
};

float4 vert(VertexData v) : SV_POSITION
{
    return UnityObjectToClipPos(v.position);
    // float position =  UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
    // return UnityApplyLinearShadowBias(position);
}

half4 frag() : SV_TARGET
{
    return 0;
}
#endif