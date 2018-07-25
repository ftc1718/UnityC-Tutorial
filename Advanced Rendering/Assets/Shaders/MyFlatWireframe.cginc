#if !defined(FLAT_WIREFRAME_INCLUDED)
#define FLAT_WIREFRAME_INCLUDED

#include "MyLighting.cginc"

[maxvertexcount(3)]
void geom(triangle InterpolatorsVertex i[3],
    inout TriangleStream<InterpolatorsVertex> stream)
{
    float3 p0 = i[0].worldPos.xyz;
    float3 p1 = i[1].worldPos.xyz;
    float3 p2 = i[2].worldPos.xyz;
    float3 triangleNormal = cross((p1 - p0), (p2 - p0));

    i[0].normal.xyz = triangleNormal;
    i[1].normal.xyz = triangleNormal;
    i[2].normal.xyz = triangleNormal;

    stream.Append(i[0]);
    stream.Append(i[1]);
    stream.Append(i[2]);
}

#endif