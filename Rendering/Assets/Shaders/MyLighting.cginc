#ifndef MY_LIGHTING_INCLUDE
#define MY_LIGHTING_INCLUDE

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _DetailTex;
float4 _DetailTex_ST;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;

sampler2D _EmissionMap;
float3 _Emission;

sampler2D _OcclusionMap;
float _OcclusionStrength;

sampler2D _DetailMask;

float _AlphaCutoff;

struct VertexData
{
	// float4 position : POSITION;
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
};

struct Interpolators
{
	// float4 position : SV_POSITION;
	float4 pos: SV_POSITION;
	float4 uv : TEXCOORD0;		
	float3 normal : TEXCOORD1;

	#if defined(BINORMAL_PER_FRAGMENT)
		float4 tangent: TEXCOORD2;
	#else
		float3 tangent : TEXCOORD2;
		float3 binormal : TEXCOORD3;
	#endif

	float3 worldPos : TEXCOORD4;

	// #if defined(SHADOWS_SCREEN)
	// 	float4 shadowCoordinates : TEXCOORD5;
	// #endif	
	SHADOW_COORDS(5)

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD6;
	#endif
};

struct FragmentOutput
{
	#if defined(DEFERRED_PASS)
		float4 gBuffer0 : SV_TARGET0;
		float4 gBuffer1 : SV_TARGET1;
		float4 gBuffer2 : SV_TARGET2;
		float4 gBuffer3 : SV_TARGET3;
	#else
		float4 color : SV_TARGET;
	#endif
};

float GetAlpha(Interpolators i)
{
	float alpha = _Tint.a;
	#if !defined(_SMOOTHNESS_ALBEDO)
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	
	return alpha;
}

float GetDetailMask(Interpolators i)
{
	#if defined(_DETAIL_MASK)
		return tex2D(_DetailMask, i.uv.xy).a;
	#else
		return 1;
	#endif
}

float3 GetAlbedo(Interpolators i)
{
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	#if defined(_DETAIL_ALBEDO_MAP)
		float detail = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
		albedo = lerp(albedo, albedo * detail, GetDetailMask(i));
	#endif
	return albedo;
}

float3 GetEmission(Interpolators i)
{
	#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
		#if defined(_EMISSION_MAP)
			return tex2D(_EmissionMap, i.uv.xy) * _Emission;
		#else
			return _Emission;
		#endif
	#else
		return 0;
	#endif
}

float GetMetallic(Interpolators i)
{
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).r;
	#else
		return _Metallic;
	#endif
}

float GetSmoothness(Interpolators i)
{
	float smoothness = 1;
	#if defined(_SMOOTHNESS_ALBEDO)
		smoothness = tex2D(_MainTex, i.uv.xy).a;
	#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
		smoothness = tex2D(_MetallicMap, i.uv.xy).a;
	#endif
		return smoothness * _Smoothness;
}

float GetOcclusion(Interpolators i)
{
	#if defined(_OCCLUSION_MAP)
		return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
	#else
		return 1;
	#endif
}

float3 GetTangentSpaceNormal(Interpolators i)
{
	float3 normal = float3(0, 0, 1);
	#if defined(_NORMAL_MAP)
		normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	#endif
	#if defined(_DETAIL_NORMAL_MAP)
		float3 detailNormal = 
			UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
		detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
		normal = BlendNormals(normal, detailNormal);
	#endif

	return normal;
}

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

	#if defined(DEfERRED_PASS)
		light.dir = float3(0, 1, 0);
		light.color = 0;
	#else
		#if defined(POINT) || defined(SPOT)
			light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
		#else
			light.dir = _WorldSpaceLightPos0.xyz;
		#endif

	// #if defined(SHADOWS_SCREEN)
	// 	// float attenuation = tex2D(_ShadowMapTexture, i.shadowCoordinates.xy / i.shadowCoordinates.w);
	// 	float attenuation = SHADOW_ATTENUATION(i);
	// #else
		UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);
	// #endif
	// attenuation *= GetOcclusion(i);

		light.color = _LightColor0.rgb * attenuation;
	#endif
	// light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

//reflection direction; the position sampling from(object position); cubemapPosition; the boundary of cubemapBox;
float3 BoxProjection(float3 direction, float3 position,
	float4 cubemapPositon, float3 boxMin, float3 boxMax)
{
	// boxMin -= position;
	// boxMax -= position;
	// float x = (direction.x > 0 ? boxMax.x : boxMin.x) / direction.x;
	// float y = (direction.y > 0 ? boxMax.y : boxMin.y) / direction.y;
	// float z = (direction.z > 0 ? boxMax.z : boxMin.z) / direction.z;
	// float scalar = min(min(x, y), z);

	if(cubemapPositon.w > 0)
	{
		float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
		float scalar = min(min(factors.x, factors.y), factors.z);
		direction = direction * scalar + (position - cubemapPositon);
	}
	return direction;
}

UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir)
{
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
		float3 reflectionDir = reflect(-viewDir, i.normal);
		// float roughness = 1 - _Smoothness;
		// float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionDir, roughness * UNITY_SPECCUBE_LOD_STEPS);
		// indirectLight.specular = DecodeHDR(envSample, unity_SpecCube0_HDR);

		Unity_GlossyEnvironmentData envData;
		envData.roughness = 1 - GetSmoothness(i);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos,
			unity_SpecCube0_ProbePosition,
			unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
		);
		float3 probe0 = Unity_GlossyEnvironment(
			UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
		);

		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos,
			unity_SpecCube1_ProbePosition,
			unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
		);
		UNITY_BRANCH
		if(unity_SpecCube0_BoxMin.w < 1)
		{
			float3 probe1 = Unity_GlossyEnvironment(
				UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), unity_SpecCube0_HDR, envData
			);

			indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
		}
		else
		{
			indirectLight.specular = probe0;
		}

		float occlusion = GetOcclusion(i);
		indirectLight.diffuse *= occlusion;
		indirectLight.specular *= occlusion;
	#endif

	return indirectLight;
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
	return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
}

void InitializeFragmnetNormal(inout Interpolators i)
{
	float3 tangentSpaceNormal = GetTangentSpaceNormal(i);

	// initialize binormal
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif

	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent + 
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
	);
}

Interpolators vert(VertexData v)
{
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.worldPos = mul(unity_ObjectToWorld, v.vertex);
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

	// #if defined(SHADOWS_SCREEN)
	// 	// // i.shadowCoordinates.xy = (i.position.xy + i.position.w) * 0.5;
	// 	// i.shadowCoordinates.xy = (float2(i.position.x, -i.position.y) + i.position.w) * 0.5;
	// 	// i.shadowCoordinates.zw = i.position.zw;
	// 	i.shadowCoordinates = ComputeScreenPos(i.position);
	// #endif
	TRANSFER_SHADOW(i);

	ComputeVertexLightColor(i);
	return i;
}

FragmentOutput frag(Interpolators i)
{
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif

	InitializeFragmnetNormal(i);
	
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

	/* caculate the diffuse(albedo) and the reflect(spcular) simplest metallic workflow */
	// float3 specularTint = albedo * _Metallic;
	// albedo *= 1 - _Metallic;
	float3 specularTint;
	float oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(
		GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity
	);

	#if defined(_RENDERING_TRANSPARENT)
		albedo *= alpha;
		alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;		
	#endif

	float4 color = UNITY_BRDF_PBS(
		albedo, specularTint, 
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir,
		CreateLight(i), CreateIndirectLight(i, viewDir)
	);
	color.rgb += GetEmission(i);
	#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
		color.a = alpha;
	#endif

	FragmentOutput output;

	#if !defined(UNITY_HDR_ON)
		color.rgb = exp2(-color.rgb);
	#endif

	#if defined(DEFERRED_PASS)
		output.gBuffer0.rgb = albedo;
		output.gBuffer0.a = GetOcclusion(i);
		output.gBuffer1.rgb = specularTint;
		output.gBuffer1.a = GetSmoothness(i);

		//the alpha channal isn't used
		output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);

		//gBuffer3 is used to accumulate the lighting of the scene
		//32bit for LDR(ARGB2 10 10 10); 64bit for HDR(ARGBHalf)
		output.gBuffer3 = color;
	#else
		output.color = color;
	#endif

	return output;
}

#endif