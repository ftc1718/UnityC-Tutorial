#ifndef MY_LIGHTING_INCLUDE
#define MY_LIGHTING_INCLUDE

#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

float4 _Tint;
sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _HeightMap;
float4 _HeightMap_TexelSize;

float _Smoothness;
// float4 _SpecularTint;
float _Metallic;

struct vertexData
{
	float4 position : POSITION;
	float3 normal : NORMAL;
	float2 uv : TEXCOORD0;
};

struct Interpolators
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD0;		
	float3 normal : TEXCOORD1;	
	float3 worldPos : TEXCOORD2;	

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD3;
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

	UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
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

void InitializeFragmnetNormal(inout Interpolators i)
{
// 	float2 delta = float2(_HeightMap_TexelSize.x, 0);
// 	float h1 = tex2D(_HeightMap, i.uv);
// 	float h2 = tex2D(_HeightMap, i.uv + delta);
// 	// i.normal = float3(1, (h2 - h1) / delta.x, 0); // i.normal = float3(delta.x, h2 - h1, 0); // too steep, replace delta.x to 1
// 	// i.normal = float3(1, h2 - h1, 0);
// 	i.normal = float3(h1 - h2, 1, 0);//rotate the tangent 90 degree around Z axis

	//use two tangents to create normal(height)
	float2 du = float2(_HeightMap_TexelSize.x * 0.5, 0); // another way to caculate f'u
	float u1 = tex2D(_HeightMap, i.uv - du);
	float u2 = tex2D(_HeightMap, i.uv + du);
	// float3 tu = float3(1, u2 - u1, 0);
	// rotate the tangent 90 degree around Z axis to an upward-pointing normal to get right lighting
	// float3 tu = float3(u1 - u2, 1, 0); 

	float2 dv = float2(_HeightMap_TexelSize.y * 0.5, 0); // another way to caculate f'v
	float v1 = tex2D(_HeightMap, i.uv - dv);
	float v2 = tex2D(_HeightMap, i.uv + dv);
	// float3 tv = float3(0, v2 - v1, 1);
	// i.normal = float3(0, 1, v1- v2); // rotate the tangent -90 degree around X axis

	// i.normal = cross(tv, tu);
	i.normal = float3(u1 - u2, 1, v1 - v2);
	i.normal = normalize(i.normal);
}

Interpolators vert(vertexData v)
{
	Interpolators i;
	i.position = UnityObjectToClipPos(v.position);
	i.worldPos = mul(unity_ObjectToWorld, v.position);
	i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
	i.normal = UnityObjectToWorldNormal(v.normal);
	ComputeVertexLightColor(i);
	return i;
}


float4 frag(Interpolators i) : SV_TARGET
{
	InitializeFragmnetNormal(i);
	
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

	float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
	// albedo *= tex2D(_HeightMap, i.uv);

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