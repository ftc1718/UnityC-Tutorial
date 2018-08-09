#if !defined(MY_TRIPLANAR_MAPPING_INCLUDED)
#define MY_TRIPLANAR_MAPPING_INCLUDED

#define NO_DEFAULT_UV

#include "MyLightingInput.cginc"

sampler2D _MOSMap;

float3 BlendTriplanarNormal (float3 mappedNormal, float3 surfaceNormal)
{
	float3 n;
	n.xy = mappedNormal.xy + surfaceNormal.xy;
	n.z = mappedNormal.z * surfaceNormal.z;
	return n;
}

void MyTriPlanarSurfaceFunction (
	inout SurfaceData surface, SurfaceParameters parameters
)
{
	TriplanarUV triUV = GetTriplanarUV(parameters);

	float3 albedoX = tex2D(_MainTex, triUV.x).rgb;
	float3 albedoY = tex2D(_MainTex, triUV.y).rgb;
	float3 albedoZ = tex2D(_MainTex, triUV.z).rgb;

	float4 mosX = tex2D(_MOSMap, triUV.x);
	float4 mosY = tex2D(_MOSMap, triUV.y);
	float4 mosZ = tex2D(_MOSMap, triUV.z);

	float3 tangentNormalX = UnpackNormal(tex2D(_NormalMap, triUV.x));
	float3 tangentNormalY = UnpackNormal(tex2D(_NormalMap, triUV.y));
	float3 tangentNormalZ = UnpackNormal(tex2D(_NormalMap, triUV.z));

	if (parameters.normal.x < 0)
	{
		tangentNormalX.x = -tangentNormalX.x;
	}
	if (parameters.normal.y < 0)
	{
		tangentNormalY.x = -tangentNormalY.x;
	}
	if (parameters.normal.z >= 0)
	{
		tangentNormalZ.x = -tangentNormalZ.x;
	}

	float3 worldNormalX = BlendTriplanarNormal(tangentNormalX, parameters.normal.zyx).zyx;
	float3 worldNormalY = BlendTriplanarNormal(tangentNormalY, parameters.normal.xzy).xzy;
	float3 worldNormalZ = BlendTriplanarNormal(tangentNormalZ, parameters.normal);

	float3 triW = GetTriplanarWeight(parameters);

	surface.normal = normalize(
		worldNormalX * triW.x + worldNormalY * triW.y + worldNormalZ * triW.z
	);
	surface.albedo = albedoX * triW.x + albedoY * triW.y + albedoZ * triW.z;
	float4 mos = mosX * triW.x + mosY * triW.y + mosZ * triW.z;
	surface.metallic = mos.x;
	surface.occlusion = mos.y;
	surface.smoothness = mos.a;
}

#define SURFACE_FUNCTION MyTriPlanarSurfaceFunction

#endif