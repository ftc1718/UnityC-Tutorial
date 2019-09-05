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
    [SerializeField]
    Texture2D ditherTexture = null;

    protected override IRenderPipeline InternalCreatePipeline()
	{
        Vector3 shadowCascadesSplit = shadowCascades == ShadowCascades.Four ? fourCascadesSplit : new Vector3(twoCascadesSplit, 0f);
        return new MyPipeline(dynamicBatching, ditherTexture, instancing, (int)shadowMapSize, shadowDistance, shadowFadeRange, (int)shadowCascades, shadowCascadesSplit);
    }
}
