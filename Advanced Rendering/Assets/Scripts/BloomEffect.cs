using UnityEngine;
using System;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BloomEffect : MonoBehaviour
{
    [Range(0, 10)]
    public float intensity = 1;
	[Range(1, 16)]
    public int iterations = 4;
    [Range(1, 10)]
    public int threshold = 1;
    [Range(1, 10)]
    public float softThreshold = 0.5f;

    public Shader bloomShader;
    public bool debug;

    [NonSerialized]
    Material bloom;

    const int BoxDownPrefilterPass = 0;
    const int BoxDownPass = 1;
    const int BoxUpPass = 2;
    const int ApplyBloomPass = 3;
    const int DebugBloomPass = 4;

    RenderTexture[] textures = new RenderTexture[16];

    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(bloom == null)
		{
            bloom = new Material(bloomShader);
            bloom.hideFlags = HideFlags.HideAndDontSave;
        }

        // bloom.SetFloat("_Threshold", threshold);
        // bloom.SetFloat("_SoftThreshold", softThreshold);

        // caculate threshold in script
        float knee = threshold * softThreshold;
		Vector4 filter;
		filter.x = threshold;
		filter.y = filter.x - knee;
		filter.z = 2f * knee;
		filter.w = 0.25f / (knee + 0.00001f);
		bloom.SetVector("_Filter", filter);
        
        bloom.SetFloat("_Intensity", Mathf.GammaToLinearSpace(intensity));

        int width = src.width / 2;
        int height = src.height / 2;
        RenderTextureFormat format = src.format;
        RenderTexture currentDestination = textures[0] =
			RenderTexture.GetTemporary(width, height, 0, format);
        Graphics.Blit(src, currentDestination, bloom, BoxDownPrefilterPass);
        RenderTexture currentSource = currentDestination;

        int i = 1;
        for (; i < iterations; i++)
		{
            width /= 2;
            height /= 2;
            if (height < 2)
            {
                break;
            }
            currentDestination = textures[i] =
                RenderTexture.GetTemporary(width, height, 0, format);
            Graphics.Blit(currentSource, currentDestination, bloom, BoxDownPass);
            currentSource = currentDestination;
        }

        for (i -= 2; i >= 0; i--)
		{
            currentDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(currentSource, currentDestination, bloom, BoxUpPass);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }

        if(debug)
        {
            Graphics.Blit(currentSource, dest, bloom, DebugBloomPass);
        }
        else
        {
            bloom.SetTexture("_SourceTex", src);
            Graphics.Blit(currentSource, dest, bloom, ApplyBloomPass);
        }
        RenderTexture.ReleaseTemporary(currentSource);
    }
}
