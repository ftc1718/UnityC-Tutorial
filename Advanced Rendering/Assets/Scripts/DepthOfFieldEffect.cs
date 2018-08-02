using System;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class DepthOfFieldEffect : MonoBehaviour
{
    [HideInInspector]
    public Shader dofShader;

    [NonSerialized]
    Material dofMaterial;

    const int circleOfConfusionPass = 0;
    const int preFilterPass = 1;
    const int bokehPass = 2;
    const int postFilterPass = 3;

    [Range(0.1f, 100f)]
    public float focusDistance = 10f;
    [Range(0.1f, 10f)]
    public float focusRange = 3f;
    [Range(1f, 10f)]
    public float bokehRadius = 4f;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(dofMaterial == null)
		{
            dofMaterial = new Material(dofShader);
            dofMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        RenderTexture coc = RenderTexture.GetTemporary(
            src.width, src.height, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear
        );

        dofMaterial.SetFloat("_FocusDistance", focusDistance);
        dofMaterial.SetFloat("_FocusRange", focusRange);
        dofMaterial.SetFloat("_BokehRadius", bokehRadius);
        dofMaterial.SetTexture("_CoCTex", coc);

        int width = src.width / 2;
        int height = src.height / 2;
        RenderTextureFormat format = src.format;
		RenderTexture dof0 =
			RenderTexture.GetTemporary(width, height, 0, format);
		RenderTexture dof1 =
			RenderTexture.GetTemporary(width, height, 0, format);

        Graphics.Blit(src, coc, dofMaterial, circleOfConfusionPass);
        Graphics.Blit(src, dof0);
        Graphics.Blit(dof0, dof1, dofMaterial, bokehPass);
        Graphics.Blit(dof1, dof0, dofMaterial, postFilterPass);
        Graphics.Blit(dof0, dest);

        RenderTexture.ReleaseTemporary(coc);
        RenderTexture.ReleaseTemporary(dof0);
        RenderTexture.ReleaseTemporary(dof1);
    }
}
