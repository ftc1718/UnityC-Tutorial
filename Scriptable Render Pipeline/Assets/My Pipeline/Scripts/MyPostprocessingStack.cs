using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/My Post-Processing Stack")]
public class MyPostprocessingStack : ScriptableObject
{
    public void Render(CommandBuffer cb, int cameraColorTextureID, int cameraDepthTextureID)
    {
        cb.Blit(cameraColorTextureID, BuiltinRenderTextureType.CameraTarget);
    }
}
