using UnityEngine;
using System;

[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader deferredFog;

    [NonSerialized]
    Material fogMaterial;

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(fogMaterial == null)
		{
            fogMaterial = new Material(deferredFog);
        }
        Graphics.Blit(src, dest, fogMaterial);
    }
}
