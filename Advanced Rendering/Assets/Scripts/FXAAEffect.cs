using System;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class FXAAEffect : MonoBehaviour
{
    public bool lowQuality;
    
    [Range(0.0312f, 0.0833f)]
	public float contrastThreshold = 0.0312f;
    [Range(0.063f, 0.333f)]
	public float relativeThreshold = 0.063f;
    [Range(0f, 1f)]
	public float subpixelBlending = 1f;

    const int luminancePass = 0;
    const int fxaaPass = 1;

    // [HideInInspector]
    public Shader fxaaShader;

    [NonSerialized]
    Material fxaaMaterial;

    public enum LuminanceMode { alpha, Green, Calculate }
    public LuminanceMode LuminanceSource;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(fxaaMaterial == null)
		{
            fxaaMaterial = new Material(fxaaShader);
            fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        fxaaMaterial.SetFloat("_ContrastThreshld", contrastThreshold);
        fxaaMaterial.SetFloat("_RelativeThreshold", relativeThreshold);
        fxaaMaterial.SetFloat("_SubpixelBlending", subpixelBlending);

        if (lowQuality)
        {
			fxaaMaterial.EnableKeyword("LOW_QUALITY");
		}
		else
        {
			fxaaMaterial.DisableKeyword("LOW_QUALITY");
		}

        if(LuminanceSource == LuminanceMode.Calculate)
        {
            fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
            RenderTexture luminanceTex = RenderTexture.GetTemporary(
                src.width, src.height, 0, src.format
            );
            Graphics.Blit(src, luminanceTex, fxaaMaterial, luminancePass);
            Graphics.Blit(luminanceTex, dest, fxaaMaterial, fxaaPass);
            RenderTexture.ReleaseTemporary(luminanceTex);
        }
        else
        {
            if(LuminanceSource == LuminanceMode.Green)
            {
                fxaaMaterial.EnableKeyword("LUMINANCE_GREEN");
            }
            else
            {
                fxaaMaterial.DisableKeyword("LUMINANCE_GREEN");
            }
        }

        Graphics.Blit(src, dest, fxaaMaterial, fxaaPass);
    }
}
