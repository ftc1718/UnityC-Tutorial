﻿#ifndef MY_LIGHTING_INCLUDE
#define MY_LIGHTING_INCLUDE

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _DetailTex;
float4 _DetailTex_ST;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

float _Smoothness;
// float4 _SpecularTint;
float _Metallic;

struct VertexData
{
	float4 position : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
};

struct Interpolators
{
	float4 position : SV_POSITION;
	float4 uv : TEXCOORD0;		
	float3 normal : TEXCOORD1;

	#if defined(BINORMAL_PER_FRAGMENT)	
		float4 tangent: TEXCOORD2;
	#else
		float3 tangent : TEXCOORD2;
		float3 binormal : TEXCOORD3;
	#endif

	float3 worldPos : TEXCOORD4;

	#if defined(SHADOWS_SCREEN)
		float4 shadowCoordinates : TEXCOORD5;
	#endif	

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD6;
	#endif
};

void ComputeVertexLightColor(inout Interpolators i)
{
	#if defined(VERTEXLIGHT_ON)
		// float3 lightPos = float3(
		// 	unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x
		// );
		// float3 lightDir = normalize(lightPos - i.worldPos);
		// float ndotl = DotClamped(lightDir, i.normal);
		// float attenuation = 1 / (1 + dot(lightDir, lightDir));

		// i.vertexLightColor = unity_LightColor[0].rgb * ndotl * attenuation;

		i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos, i.normal
		);
	#endif
}

UnityLight CreateLight(Interpolators i)
{
	UnityLight light;

	#if defined(POINT) || defined(SPOT)
		light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
	#else
		light.dir = _WorldSpaceLightPos0.xyz;
	#endif

	#if defined(SHADOWS_SCREEN)
		float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
	#else
		UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
	#endif

	light.color = _LightColor0.rgb * attenuation;
	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

UnityIndirect CreateIndirectLight(Interpolators i)
{
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	#if defined(FORWARD_BASE_PASS)
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
	#endif

	return indirectLight;
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
	return cross(normal, tangent) * (binormalSign, unity_WorldTransformParams.w);
}

void InitializeFragmnetNormal(inout Interpolators i)
{
	// i.normal.xy = tex2D(_NormalMap, i.uv).wy * 2 - 1;
	// i.normal.xy *= _BumpScale;
	// i.normal.z = sqrt(1 - saturate(dot(i.normal.xy, i.normal.xy)));
	float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
	/***
	// i.normal = float3(mainNormal.xy / mainNormal.z + detailNormal.xy / detailNormal.z, 1);
	i.normal = float3(mainNormal.xy + detailNormal.xy, mainNormal.z * detailNormal.z); // whiteout blending
	i.normal = normalize(i.normal.xzy);
	***/
	// use unity buildin function
	float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
	tangentSpaceNormal = tangentSpaceNormal.xzy;

	// initialize binormal
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif

	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent + 
		tangentSpaceNormal.y * i.normal +
		tangentSpaceNormal.z * binormal
	);
}

Interpolators vert(VertexData v)
{
	Interpolators i;
	i.position = UnityObjectToClipPos(v.position);
	i.worldPos = mul(unity_ObjectToWorld, v.position);
	i.normal = UnityObjectToWorldNormal(v.normal);

	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
	#endif

	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);
	// i.uv.xy = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
	// i.uv.zw = v.uv * _DetailTex_ST.xy + _DetailTex_ST.zw;

	#if defined(SHADOWS_SCREEN)
		// i.shadowCoordinates.xy = (i.position.xy + i.position.w) * 0.5;
		i.shadowCoordinates.xy = (float2(i.position.x, -i.position.y) + i.position.w) * 0.5;
		i.shadowCoordinates.zw = i.position.zw;
	#endif

	ComputeVertexLightColor(i);
	return i;
}

float4 frag(Interpolators i) : SV_TARGET
{
	InitializeFragmnetNormal(i);
	
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;

	/* caculate the diffuse(albedo) and the reflect(spcular) simplest metallic workflow */
	// float3 specularTint = albedo * _Metallic;
	// albedo *= 1 - _Metallic;
	float3 specularTint;
	float oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(
		albedo, _Metallic, specularTint, oneMinusReflectivity
	);

	return UNITY_BRDF_PBS(
		albedo, specularTint, 
		oneMinusReflectivity, _Smoothness,
		i.normal, viewDir,
		CreateLight(i), CreateIndirectLight(i)
	);
}

#endif