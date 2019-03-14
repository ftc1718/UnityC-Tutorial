#ifndef MYRP_LIT_INCLUDED
#define MYRP_LIT_INCLUDED

#define MAX_VISIBLE_LIGHTS 16

#include "CoreRP/ShaderLibrary/Common.hlsl"
#include "CoreRP/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4 unity_LightIndicesOffsetAndCount;
    float4 unity_4LightIndices0, unity_4LightIndices1;
CBUFFER_END

CBUFFER_START(UnityPerCamera)
		float3 _WorldSpaceCameraPos;
CBUFFER_END

CBUFFER_START(_LightBuffer)
    float4 _VisibleLightColors[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightDirectionsOrPositions[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightAttenuations[MAX_VISIBLE_LIGHTS];
    float4 _VisibleLightSpotDirections[MAX_VISIBLE_LIGHTS];
CBUFFER_END

CBUFFER_START(_ShadowBuffer)
	float4x4 _WorldToShadowMatrices[MAX_VISIBLE_LIGHTS];
    float4x4 _WorldToShadowCascadeMatrices[5];
    float4 _CascadeCullingSpheres[4];
	float4 _ShadowData[MAX_VISIBLE_LIGHTS];
	float4 _ShadowMapSize;
    float4 _CascadeShadowMapSize;
	float4 _GlobalShadowData;
    float4 _CascadeShadowStrength;
CBUFFER_END

CBUFFER_START(UnityPerFrame)
    float4x4 unity_MatrixVP;
CBUFFER_END

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float _Cutoff;
CBUFFER_END

#define UNITY_MATRIX_M unity_ObjectToWorld
#include "CoreRP/ShaderLibrary/UnityInstancing.hlsl"

UNITY_INSTANCING_BUFFER_START(PerInstance)
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(PerInstance)

TEXTURE2D_SHADOW(_ShadowMap);
SAMPLER_CMP(sampler_ShadowMap);
TEXTURE2D_SHADOW(_CascadeShadowMap);
SAMPLER_CMP(sampler_CascadeShadowMap);

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

float DistanceToCameraSqr(float3 worldPos)
{
	float3 cameraToFragment = worldPos - _WorldSpaceCameraPos;
	return dot(cameraToFragment, cameraToFragment);
}

float InsideCascadeCullingSphere(int index, float3 worldPos)
{
    float4 s = _CascadeCullingSpheres[index];
    return dot(worldPos - s.xyz, worldPos - s.xyz) < s.w;
}

float3 DiffuseLight(int index, float3 normal, float3 worldPos, float shadowAttenuation)
{
    float3 lightColor = _VisibleLightColors[index].rgb;
    float4 lightDirectionOrPosition = _VisibleLightDirectionsOrPositions[index];
    float4 lightAttenuation = _VisibleLightAttenuations[index];
    float3 spotDirection = _VisibleLightSpotDirections[index].xyz;

    float3 lightVector = lightDirectionOrPosition.xyz - worldPos * lightDirectionOrPosition.w;
    float3 lightDirection = normalize(lightVector);

    float diffuse = saturate(dot(lightDirection, normal));

    float rangeFade = dot(lightVector, lightVector) * lightAttenuation.x;
    rangeFade = saturate(1 - rangeFade * rangeFade);
    rangeFade *= rangeFade;

    float spotFade = dot(spotDirection, lightDirection);
	spotFade = saturate(spotFade * lightAttenuation.z + lightAttenuation.w);
	spotFade *= spotFade;

    float distanceSqr = max(dot(lightVector, lightVector), 0.00001);
    diffuse *= shadowAttenuation * spotFade * rangeFade / distanceSqr;
    return diffuse * lightColor;
}

float HardShadowAttenuation(float4 shadowPos, bool cascade = false)
{
    if(cascade)
    {
        return SAMPLE_TEXTURE2D_SHADOW(_CascadeShadowMap, sampler_CascadeShadowMap, shadowPos.xyz);
    }
    else
    {
	    return SAMPLE_TEXTURE2D_SHADOW(_ShadowMap, sampler_ShadowMap, shadowPos.xyz);
    }
}

float SoftShadowAttenuation(float4 shadowPos, bool cascade = false)
{
	real tentWeights[9];
	real2 tentUVs[9];
    float4 size = cascade ? _CascadeShadowMapSize : _ShadowMapSize;
	SampleShadow_ComputeSamples_Tent_5x5(
		size, shadowPos.xy, tentWeights, tentUVs
	);
	float attenuation = 0;
	for (int i = 0; i < 9; i++)
	{
		//attenuation += tentWeights[i] * SAMPLE_TEXTURE2D_SHADOW(
		//	_ShadowMap, sampler_ShadowMap, float3(tentUVs[i].xy, shadowPos.z)
		//);
        attenuation += tentWeights[i] * HardShadowAttenuation(float4(tentUVs[i].xy, shadowPos.z, 0), cascade);
    }
	return attenuation;
}

float ShadowAttenuation(int index, float3 worldPos)
{
	#if !defined(_SHADOWS_HARD) && !defined(_SHADOWS_SOFT)
		return 1.0;
	#endif
	if (_ShadowData[index].x <= 0 || DistanceToCameraSqr(worldPos) > _GlobalShadowData.y)
	{
		return 1.0;
	}
	float4 shadowPos = mul(_WorldToShadowMatrices[index], float4(worldPos, 1.0));
	shadowPos.xyz /= shadowPos.w;
	shadowPos.xy = saturate(shadowPos.xy);
	shadowPos.xy = shadowPos.xy * _GlobalShadowData.x + _ShadowData[index].zw;
	float attenuation;

	#if defined(_SHADOWS_HARD)
		#if defined(_SHADOWS_SOFT)
			if (_ShadowData[index].y == 0)
			{
				attenuation = HardShadowAttenuation(shadowPos);
			}
			else
			{
				attenuation = SoftShadowAttenuation(shadowPos);
			}
		#else
			attenuation = HardShadowAttenuation(shadowPos);
		#endif
	#else
		attenuation = SoftShadowAttenuation(shadowPos);
	#endif

	return lerp(1, attenuation, _ShadowData[index].x);
}

float CascadeShadowAttenuation(float3 worldPos)
{
    #if !defined(_CASCADE_SHADOWS_HARD) && !defined(_CASCADE_SHADOWS_SOFT)
        return 1.0;
    #endif

    if (DistanceToCameraSqr(worldPos) > _GlobalShadowData.y)
    {
        return 1.0;
    }

    float4 cascadeFlags = float4(
		InsideCascadeCullingSphere(0, worldPos),
		InsideCascadeCullingSphere(1, worldPos),
		InsideCascadeCullingSphere(2, worldPos),
		InsideCascadeCullingSphere(3, worldPos)
	);

    //return dot(cascadeFlags, 0.25);

    cascadeFlags.yzw = saturate(cascadeFlags.yzw - cascadeFlags.xyz);
    float cascadeIndex = 4 - dot(cascadeFlags, float4(4, 3, 2, 1));
    float4 shadowPos = mul(
		_WorldToShadowCascadeMatrices[cascadeIndex], float4(worldPos, 1.0)
	);
    float attenuation;
    #if defined(_CASCADE_SHADOWS_HARD)
		attenuation = HardShadowAttenuation(shadowPos, true);
    #else
        attenuation = SoftShadowAttenuation(shadowPos, true);
    #endif	
        return lerp(1, attenuation, _CascadeShadowStrength);
}

float3 MainLight(float3 normal, float3 worldPos)
{
    float shadowAttenuation = CascadeShadowAttenuation(worldPos);
    float3 lightColor = _VisibleLightColors[0].rgb;
    float3 lightDirection = _VisibleLightDirectionsOrPositions[0].xyz;
    float diffuse = saturate(dot(normal, lightDirection));
    diffuse *= shadowAttenuation;
    return diffuse * lightColor;
}


struct VertexInput
{
    float4 pos : POSITION;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    float4 clipPos : SV_POSITION;
    float3 normal : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 vertexLighting : TEXCOORD2;
    float2 uv : TEXCOORD3;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

VertexOutput LitPassVertex(VertexInput input)
{
    VertexOutput output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float4 worldPos = mul(UNITY_MATRIX_M, float4(input.pos.xyz, 1.0));
    output.clipPos = mul(unity_MatrixVP, worldPos);
    output.normal = mul((float3x3)UNITY_MATRIX_M, input.normal);
    output.worldPos = worldPos.xyz;

    output.vertexLighting = 0;
    for (int i = 4; i < min(unity_LightIndicesOffsetAndCount.y, 8); i++)
    {
		int lightIndex = unity_4LightIndices1[i - 4];
		output.vertexLighting += DiffuseLight(lightIndex, output.normal, output.worldPos, 1);
	}

    output.uv = TRANSFORM_TEX(input.uv, _MainTex);

    return output;
}

float4 LitPassFragment(VertexOutput input, FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    input.normal = normalize(input.normal);
    input.normal = IS_FRONT_VFACE(isFrontFace, input.normal, -input.normal);

    float4 albedoAlpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    albedoAlpha *= UNITY_ACCESS_INSTANCED_PROP(PerInstance, _Color);
    #if defined(_CLIPPING)
    clip(albedoAlpha.a - _Cutoff);
    #endif

    // float diffuseLight = saturate(dot(input.normal, float3(0, 1, 0)));
    float3 diffuseLight = input.vertexLighting;

    #if defined(_CASCADE_SHADOWS_HARD) || defined(_CASCADE_SHADOWS_SOFT)
		diffuseLight += MainLight(input.normal, input.worldPos);
	#endif

    for(int i = 0; i < min(unity_LightIndicesOffsetAndCount.y, 4); i++)
    {
        int lightIndex = unity_4LightIndices0[i];
		float shadowAttenuation = ShadowAttenuation(i, input.worldPos);
        diffuseLight += DiffuseLight(lightIndex, input.normal, input.worldPos, shadowAttenuation);
    }

    // diffuseLight = saturate(dot(input.normal, float3(0, 1,0)));
    float3 color = diffuseLight * albedoAlpha.rgb;
    return float4(color, albedoAlpha.a);
}

#endif //MYRP_LIT_INCLUDED