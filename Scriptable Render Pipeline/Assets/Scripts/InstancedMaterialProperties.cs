using UnityEngine;

public class InstancedMaterialProperties : MonoBehaviour
{
    static MaterialPropertyBlock propertyBlock;

    static int colorID = Shader.PropertyToID("_Color");
    static int metallicID = Shader.PropertyToID("_Metallic");
    static int smoothnessID = Shader.PropertyToID("_Smoothness");
    static int emissionColorID = Shader.PropertyToID("_EmissionColor");

    [SerializeField]
    Color color = Color.white;

    [SerializeField, Range(0f, 1f)]
    float metallic;

    [SerializeField, Range(0f, 1f)]
    float smoothness = 0.5f;

    [SerializeField, ColorUsage(false, true)]
    Color emissionColor = Color.black;

    [SerializeField]
    float pulseEmissionFreqency;

    public float num = 0.1f;

    void Awake()
    {
        OnValidate();
        if (pulseEmissionFreqency <= 0f)
        {
            enabled = false;
        }
    }

    void Update()
    {
        Color originalEmissionColor = emissionColor;
        emissionColor *= 0.5f +
            0.5f * Mathf.Cos(2f * Mathf.PI * pulseEmissionFreqency * Time.time);
        OnValidate();
        //GetComponent<MeshRenderer>().UpdateGIMaterials();// cause a meta pass
        DynamicGI.SetEmissive(GetComponent<MeshRenderer>(), emissionColor);// just set a uniform color (faster)
        emissionColor = originalEmissionColor;
    }

    void OnValidate()
    {
        if (propertyBlock == null)
        {
            propertyBlock = new MaterialPropertyBlock();
        }
        propertyBlock.SetColor(colorID, color);
        propertyBlock.SetFloat(metallicID, metallic);
        propertyBlock.SetFloat(smoothnessID, smoothness);
        propertyBlock.SetColor(emissionColorID, emissionColor);
        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }
}