#if !defined(MY_SURFACE_INCLUDED)
#define MY_SURFACE_INCLUDED

struct SurfaceData
{
    float3 albedo, emission, normal;
    float alpha, metallic, occlusion, smoothness;
};

struct SurfaceParameters
{
	float3 normal, position;
	float4 uv;
};

struct TriplanarUV
{
    float2 x, y, z;
};

TriplanarUV GetTriplanarUV(SurfaceParameters parameters)
{
    TriplanarUV triUV;
    float3 p = parameters.position;
    triUV.x = p.zy;
    triUV.y = p.xz;
    triUV.z = p.xy;
    if(parameters.normal.x < 0)
    {
        triUV.x.x = -triUV.x.x;
    }
    if(parameters.normal.y < 0)
    {
        triUV.y.x = -triUV.y.x;
    }
    if(parameters.normal.z > 0)
    {
        triUV.z.x = -triUV.z.x;
    }
    return triUV;
}

float3 GetTriplanarWeight(SurfaceParameters parameters)
{
    float3 triW = abs(parameters.normal);
    return triW / (triW.x + triW.y + triW.z);
}

#endif