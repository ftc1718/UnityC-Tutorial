#if !defined(TESSELLATION_INCLUDED)
#define TESSELLATION_INCLUDED

float _TessellationUniform;
float _TessellationEdgeLength;

struct TessellationFactors
{
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};

struct TessellationControlPoint
{
	float4 vertex : INTERNALTESSPOS;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
};

TessellationControlPoint MyTessellationVertexProgram(VertexData v)
{
    TessellationControlPoint p;
    p.vertex = v.vertex;
    p.normal = v.normal;
    p.tangent = v.tangent;
    p.uv = v.uv;
    p.uv1 = v.uv1;
    p.uv2 = v.uv2;
    return p;
}

float TessellationEdgeFactor(TessellationControlPoint cp0, TessellationControlPoint cp1)
{
    #if defined(_TESSELLATION_EDGE)
        // world space position
        // float3 p0 = mul(unity_ObjectToWorld, float4(cp0.vertex.xyz, 1)).xyz;
        // float3 p1 = mul(unity_ObjectToWorld, float4(cp1.vertex.xyz, 1)).xyz;
        // float edgeLength = distance(p0, p1);
        // return edgeLength / _TessellationEdgeLength;

        // screen space pixel
        float4 p0 = UnityObjectToClipPos(cp0.vertex);
        float4 p1 = UnityObjectToClipPos(cp1.vertex);
        float edgeLength = distance(p0.xy / p0.w, p1.xy / p1.w);
        return edgeLength * _ScreenParams.y / _TessellationEdgeLength;
    #else
        return _TessellationUniform;
    #endif
}

TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
    TessellationFactors f;
    f.edge[0] = TessellationEdgeFactor(patch[1], patch[2]);
    f.edge[1] = TessellationEdgeFactor(patch[2], patch[0]);
    f.edge[2] = TessellationEdgeFactor(patch[0], patch[1]);
    f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) * (1 / 3.0);
    return f;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
[UNITY_patchconstantfunc("MyPatchConstantFunction")]
TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch,
    uint id : SV_OutputControlPointID)
{
    return patch[id];
}

[UNITY_domain("tri")]
InterpolatorsVertex MyDomainProgram(TessellationFactors factors,
    OutputPatch<TessellationControlPoint, 3> patch,
    float3 barycentricCoordinates : SV_DomainLocation)
{
    VertexData data;

    #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * barycentricCoordinates.x + \
		patch[1].fieldName * barycentricCoordinates.y + \
		patch[2].fieldName * barycentricCoordinates.z;

	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
    MY_DOMAIN_PROGRAM_INTERPOLATE(normal)
    MY_DOMAIN_PROGRAM_INTERPOLATE(tangent)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv1)
    MY_DOMAIN_PROGRAM_INTERPOLATE(uv2)

    return MyVertexProgram(data);
}
#endif