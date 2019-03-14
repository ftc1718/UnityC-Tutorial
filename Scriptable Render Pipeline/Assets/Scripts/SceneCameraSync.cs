using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class SceneCameraSync : MonoBehaviour
{

    void Start()
    {

    }

    // Update is called once per frame
    void Update()
    {

    }
    void OnRenderObject()
    {
        if (Camera.current != null)
        {
            if (Camera.current.name.Equals("SceneCamera"))
            {
                transform.position = Camera.current.transform.position;
                transform.rotation = Camera.current.transform.rotation;
            }
        }
    }
}
