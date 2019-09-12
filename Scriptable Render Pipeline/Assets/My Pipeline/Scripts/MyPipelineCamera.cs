using UnityEngine;

[ImageEffectAllowedInSceneView, RequireComponent(typeof(Camera))]
public class MyPipelineCamera : MonoBehaviour
{
    [SerializeField]
    MyPostprocessingStack postprocessingStack = null;

    public MyPostprocessingStack PostProcessingStack
    {
        get { return postprocessingStack; }
    }
}
