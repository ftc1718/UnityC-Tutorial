#ifndef MY_SHADOWS_INCLUDED
#define MY_SHADOWS_INCLUDED

#include "UnityCG.cginc"

struct VertexData
{
    float4 position : POSITION;
    float3 normal : NORMAL;
};

#if defined(SHADOWS_CUBE)
    struct Interpolators
    {
        float4 position : SV_POSITION;
        float3 lightVec : TEXCOORD0;
    };

    Interpolators vert(VertexData v)
    {
        Interpolators i;
        i.position = UnityObjectToClipPos(v.position);
        i.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
        return i;
    }

    float4 frag(Interpolators i) : SV_TARGET
    {
        float depth = length(i.lightVec) + unity_LightShadowBias.x;
        depth *= _LightPositionRange.w;
        return UnityEncodeCubeShadowDepth(depth);
    }

#else
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

#endif