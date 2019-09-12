using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Post-Processing Stack")]
public class MyPostprocessingStack : ScriptableObject
{
    [SerializeField, Range(0, 10)]
    int blurStrength;
    [SerializeField]
    bool depthStripes;

    enum Pass { Copy, Blur, DepthStripes };
    static Mesh fullScreenTriangle;
    static Material materail;

    static int mainTexID = Shader.PropertyToID("_MainTex");
    static int tempTexID = Shader.PropertyToID("_MyPostProcessingStackTempTex");
    static int depthTexID = Shader.PropertyToID("_DepthTex");

    static void InitializeStatic()
    {
        if (fullScreenTriangle)
        {
            return;
        }
        fullScreenTriangle = new Mesh
        {
            name = "My Post-Processing Stack Full-Screen Triangle",
            vertices = new Vector3[]
            {
                new Vector3(-1f, -1f, 0f),
                new Vector3(-1f,  3f, 0f),
                new Vector3( 3f, -1f, 0f)
            },
            triangles = new int[] { 0, 1, 2 },
        };
        fullScreenTriangle.UploadMeshData(true);

        materail = new Material(Shader.Find("Hidden/My Pipeline/PostEffectStack"))
        {
            name = "My Post-Processing Stack material",
            hideFlags = HideFlags.HideAndDontSave
        };
    }

    public void RenderAfterOpaque(CommandBuffer cb, int cameraColorTextureID, int cameraDepthTextureID, int width, int height)
    {
        InitializeStatic();
        if (depthStripes)
        {
            DepthStripes(cb, cameraColorTextureID, cameraDepthTextureID, width, height);
        }
    }

    public void RenderAfterTransparent(CommandBuffer cb, int cameraColorTextureID, int cameraDepthTextureID, int width, int height)
    {
        if(blurStrength > 0)
        {
            Blur(cb, cameraColorTextureID, width, height);
        }
        else
        {
            Blit(cb, cameraColorTextureID, BuiltinRenderTextureType.CameraTarget);
        }
    }

    void Blur(CommandBuffer cb, int cameraColorTextureID, int width, int height)
    {
        cb.BeginSample("Blur");
        if (blurStrength == 1)
        {
            Blit(cb, cameraColorTextureID, BuiltinRenderTextureType.CameraTarget, Pass.Blur);
            cb.EndSample("Blur");
            return;
        }

        cb.GetTemporaryRT(tempTexID, width, height, 0, FilterMode.Bilinear);
        int passesLeft;
        for (passesLeft = blurStrength; passesLeft > 2; passesLeft -= 2)
        {
            Blit(cb, cameraColorTextureID, tempTexID, Pass.Blur);
            Blit(cb, tempTexID, cameraColorTextureID, Pass.Blur);
        }
        if (passesLeft > 1)
        {
            // Blurred Twice
            Blit(cb, cameraColorTextureID, tempTexID, Pass.Blur);
            Blit(cb, tempTexID, BuiltinRenderTextureType.CameraTarget, Pass.Blur);
            cb.ReleaseTemporaryRT(tempTexID);
        }
        else
        {
            Blit(cb, cameraColorTextureID, BuiltinRenderTextureType.CameraTarget, Pass.Blur);
        }
        cb.EndSample("Blur");
    }

    void DepthStripes(CommandBuffer cb, int cameraColorTextureID, int cameraDepthTextureID, int width, int height)
    {
        cb.BeginSample("Depth Stripes");
        cb.GetTemporaryRT(tempTexID, width, height);
        cb.SetGlobalTexture(depthTexID, cameraDepthTextureID);
        Blit(cb, cameraColorTextureID, tempTexID, Pass.DepthStripes);
        Blit(cb, tempTexID, cameraColorTextureID);
        cb.ReleaseTemporaryRT(tempTexID);
        //Blit(cb, cameraDepthTextureID, cameraColorTextureID, Pass.DepthStripes);
        cb.EndSample("Depth Stripes");
    }

    void Blit(CommandBuffer cb, RenderTargetIdentifier cameraColorTextureID, RenderTargetIdentifier destinationID, Pass pass = Pass.Copy)
    {
        cb.SetGlobalTexture(mainTexID, cameraColorTextureID);
        cb.SetRenderTarget(destinationID, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        cb.DrawMesh(fullScreenTriangle, Matrix4x4.identity, materail, 0, (int)pass);
    }
}
