﻿#ifndef CUSTOM_SHADOW
#define CUSTOM_SHADOW

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
int _CascadeCount;
float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
float _ShadowDistance;
CBUFFER_END

struct DirectionalShadowData
{
	float strength;
	int tileOffset;
};

struct ShadowData 
{
	int cascadeIndex;
	float strength;
};

ShadowData GetShadowData(Surface surfaceWS) 
{
	ShadowData data;
	data.strength = 1.0;
	int i;
	for (i = 0; i < _CascadeCount; i++) 
	{
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) 
		{
			break;
		}
	}

	if (i == _CascadeCount)
	{
		data.strength = surfaceWS.depth < _ShadowDistance ? 1.0 : 0.0;
	}

	data.cascadeIndex = i;
	return data;
}

float SampleDirectionalShadowAtlas(float3 positionSTS) 
{
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS)
{
	if (data.strength <= 0.0)
	{
		return 1.0;
	}
	float3 positionSTS = mul(
		_DirectionalShadowMatrices[data.tileOffset],
		float4(surfaceWS.position, 1.0)
	).xyz;
	float shadow = SampleDirectionalShadowAtlas(positionSTS);
	return lerp(1.0, shadow, data.strength);
}

#endif // CUSTOM_SHADOW