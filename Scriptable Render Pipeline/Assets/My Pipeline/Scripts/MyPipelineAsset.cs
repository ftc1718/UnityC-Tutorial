using UnityEngine;
using UnityEngine.Experimental.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Pipeline")]
public class MyPipelineAsset : RenderPipelineAsset
{
    public enum ShadowMapSize
    {
        _256 = 256,
        _512 = 512,
        _1024 = 1024,
        _2048 = 2048,
        _4096 = 4096
    }

    public enum ShadowCascades
    {
        Zero = 0,
        Two = 2,
        Four = 4
    }

    public enum MSAAMode
    {
        Off = 1,
        _2x = 2,
        _4x = 4,
        _8x = 8
    }

    [SerializeField]
    ShadowMapSize shadowMapSize = ShadowMapSize._1024;

    [SerializeField]
    ShadowCascades shadowCascades = ShadowCascades.Four;
    [SerializeField, HideInInspector]
    float twoCascadesSplit = 0.25f;
    [SerializeField, HideInInspector]
    Vector3 fourCascadesSplit = new Vector3(0.067f, 0.2f, 0.467f);

    [SerializeField]
    float shadowDistance = 100f;
    [SerializeField]
    float shadowFadeRange = 1f;
    [SerializeField]
    bool dynamicBatching;
    [SerializeField]
    bool instancing;
    [SerializeField, Range(0.25f, 2f)]
    float renderScale = 1f;
    [SerializeField]
    MSAAMode MSAA = MSAAMode.Off;
    [SerializeField]
    MyPostprocessingStack defaultStack;
    [SerializeField]
    Texture2D ditherTexture = null;
    [SerializeField, Range(0f, 120f)]
    float ditherAnimationSpeed = 30f;
    [SerializeField]
    bool supportLODCrossFading = true;

    public bool HasShadowCascades
    {
        get
        {
            return shadowCascades != ShadowCascades.Zero;
        }
    }

    public bool HasLODCrossFading
    {
        get
        {
            return supportLODCrossFading;
        }
    }

    protected override IRenderPipeline InternalCreatePipeline()
	{
        Vector3 shadowCascadesSplit = shadowCascades == ShadowCascades.Four ? fourCascadesSplit : new Vector3(twoCascadesSplit, 0f);
        return new MyPipeline(dynamicBatching, instancing, defaultStack, ditherTexture, ditherAnimationSpeed, (int)shadowMapSize, shadowDistance, shadowFadeRange, (int)shadowCascades, shadowCascadesSplit, renderScale, (int)MSAA);
    }

}
