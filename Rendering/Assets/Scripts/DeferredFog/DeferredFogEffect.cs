using UnityEngine;
using System;


[ExecuteInEditMode]
public class DeferredFogEffect : MonoBehaviour
{
    public Shader deferredFog;

    [NonSerialized]
    Camera deferredCamera;

    [NonSerialized]
    Vector3[] frustumCorners;

    [NonSerialized]
    Vector4[] vectorArray;

    [NonSerialized]
    Material fogMaterial;

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture dest)
	{
		if(fogMaterial == null)
		{
            deferredCamera = GetComponent<Camera>();
            frustumCorners = new Vector3[4];
            vectorArray = new Vector4[4];
            fogMaterial = new Material(deferredFog);
        }
        deferredCamera.CalculateFrustumCorners(
            new Rect(0f, 0f, 1f, 1f),
            deferredCamera.farClipPlane,
            deferredCamera.stereoActiveEye,
            frustumCorners
        );

        /* The CalculateFrustumCorners orders them bottom-left, top-left, top-right, bottom-right.
        However, the quad used to render the image effect has its corner vertices ordered bottom-left, bottom-right, top-left, top-right.
        So let's reorder them to match the quad's vertices. */
        vectorArray[0] = frustumCorners[0];
        vectorArray[1] = frustumCorners[3];
        vectorArray[2] = frustumCorners[1];
        vectorArray[3] = frustumCorners[2];
        fogMaterial.SetVectorArray("_FrustumCorners", vectorArray);

        Graphics.Blit(src, dest, fogMaterial);
    }
}
