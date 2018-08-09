#if !defined(MY_TRIPLANAR_MAPPING_INCLUDED)
#define MY_TRIPLANAR_MAPPING_INCLUDED

#define NO_DEFAULT_UV

#include "MyLightingInput.cginc"

void MyTriPlanarSurfaceFunction (
	inout SurfaceData surface, SurfaceParameters parameters
)
{
	TriplanarUV triUV = GetTriplanarUV(parameters);

	float3 albedoX = tex2D(_MainTex, triUV.x).rgb;
	float3 albedoY = tex2D(_MainTex, triUV.y).rgb;
	float3 albedoZ = tex2D(_MainTex, triUV.z).rgb;

	float3 triW = GetTriplanarWeight(parameters);

	surface.albedo = albedoX * triW.x + albedoY * triW.y + albedoZ * triW.z;
}

#define SURFACE_FUNCTION MyTriPlanarSurfaceFunction

#endif