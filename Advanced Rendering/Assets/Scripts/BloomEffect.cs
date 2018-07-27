﻿using System.Collections;
using UnityEngine;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class BloomEffect : MonoBehaviour
{
	[Range(1, 16)]
    public int iterations = 1;
    public Shader bloomShader;

    [System.NonSerialized]
    Material bloom;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(bloom == null)
		{
            bloom = new Material(bloomShader);
            bloom.hideFlags = HideFlags.HideAndDontSave;
        }
        RenderTexture[] textures = new RenderTexture[16];
        int width = src.width / 2;
        int height = src.height / 2;
        RenderTextureFormat format = src.format;
        RenderTexture currentDestination = textures[0] =
			RenderTexture.GetTemporary(width, height, 0, format);
        Graphics.Blit(src, currentDestination, bloom);
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
            Graphics.Blit(currentSource, currentDestination, bloom);
            currentSource = currentDestination;
        }

        for (i -= 2; i >= 0; i--)
		{
            currentDestination = textures[i];
            textures[i] = null;
            Graphics.Blit(currentSource, currentDestination, bloom);
            RenderTexture.ReleaseTemporary(currentSource);
            currentSource = currentDestination;
        }

		Graphics.Blit(currentSource, dest, bloom);
        RenderTexture.ReleaseTemporary(currentSource);
    }
}
