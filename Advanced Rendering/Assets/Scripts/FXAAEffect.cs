using System;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class FXAAEffect : MonoBehaviour
{
    [HideInInspector]
    public Shader dofShader;

    [NonSerialized]
    Material dofMaterial;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(dofMaterial == null)
		{
            dofMaterial = new Material(dofShader);
            dofMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        Graphics.Blit(src, dest, dofMaterial);
    }
}
