#if !defined(FLAT_WIREFRAME_INCLUDED)
#define FLAT_WIREFRAME_INCLUDED

#define CUSTOM_GEOMETRY_INTERPOLATORS \
    float2 barycentricCoordinates : TEXCOORD9;

#include "MyLightingInput.cginc"

float3 GetAlbedoWithWireframe(Interpolators i)
{
	float3 albedo = GetAlbedo(i);
    float3 barys;
    barys.xy = i.barycentricCoordinates;
    barys.z = 1- barys.x - barys.y;
    albedo = barys;
	return albedo;
}
#define ALBEDO_FUNCTION GetAlbedoWithWireframe

#include "MyLighting.cginc"

struct InterpolatorsGeometry
{
    InterpolatorsVertex data;
    CUSTOM_GEOMETRY_INTERPOLATORS
};

[maxvertexcount(3)]
void geom(triangle InterpolatorsVertex i[3],
    inout TriangleStream<InterpolatorsGeometry> stream)
{
    InterpolatorsGeometry g0, g1, g2;
    g0.data = i[0];
    g1.data = i[1];
    g2.data = i[2];

    g0.barycentricCoordinates = float2(1, 0);
	g1.barycentricCoordinates = float2(0, 1);
	g2.barycentricCoordinates = float2(0, 0);

    // float3 p0 = i[0].worldPos.xyz;
    // float3 p1 = i[1].worldPos.xyz;
    // float3 p2 = i[2].worldPos.xyz;
    // float3 triangleNormal = cross((p1 - p0), (p2 - p0));

    // i[0].normal.xyz = triangleNormal;
    // i[1].normal.xyz = triangleNormal;
    // i[2].normal.xyz = triangleNormal;

    stream.Append(g0);
    stream.Append(g1);
    stream.Append(g2);
}

#endif