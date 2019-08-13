﻿using UnityEngine;

public class InstancedMaterialProperties : MonoBehaviour
{
    static MaterialPropertyBlock propertyBlock;

    static int colorID = Shader.PropertyToID("_Color");
    static int metallicID = Shader.PropertyToID("_Metallic");
    static int smoothnessID = Shader.PropertyToID("_Smoothness");

    [SerializeField]
    Color color = Color.white;

    [SerializeField, Range(0f, 1f)]
    float metallic;

    [SerializeField, Range(0f, 1f)]
    float smoothness = 0.5f;

    void Awake()
    {
        OnValidate();
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
        GetComponent<MeshRenderer>().SetPropertyBlock(propertyBlock);
    }
}