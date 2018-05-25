using UnityEngine;
using UnityEditor;

public class MyLightingShaderGUI : ShaderGUI
{
    Material target;
    MaterialEditor editor;
    MaterialProperty[] properties;

    static GUIContent staticLabel = new GUIContent();
    static ColorPickerHDRConfig emissionConfig =
        new ColorPickerHDRConfig(0f, 99f, 1f / 99f, 3f);

    enum SmoothnessSource
    {
        Uniform, Albedo, Metallic
    }

    public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties)
	{
        this.target = editor.target as Material;
        this.editor = editor;
        this.properties = properties;
        DoMain();
        DoSecondary();
    }

	void SetKeyword(string keyword, bool state)
	{
		if(state)
		{
            target.EnableKeyword(keyword);
        }
		else
		{
            target.DisableKeyword(keyword);
        }
	}

	bool IsKeywordEnabled(string keyword)
	{
        return target.IsKeywordEnabled(keyword);
    }

	MaterialProperty FindProperty(string name)
	{
        return FindProperty(name, properties);
    }

	static GUIContent MakeLabel(string text, string tooltip = null)
	{
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

	static GUIContent MakeLabel(MaterialProperty properties, string tooltip = null)
	{
        staticLabel.text = properties.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

	//Suppot for undo
	void RecordAction(string label)
	{
        editor.RegisterPropertyChangeUndo(label);
    }

	void DoMain()
	{
        GUILayout.Label("Main Maps", EditorStyles.boldLabel);

        MaterialProperty mainTex = FindProperty("_MainTex");
        // GUIContent albedoLabel = new GUIContent("Albedo");
        // GUIContent albedoLabel = new GUIContent(mainTex.displayName, "Albedo (RGB)");
        editor.TexturePropertySingleLine(
			MakeLabel(mainTex, "Albedo (RGB)"), mainTex, FindProperty("_Tint")
		);

        DoMetallic();
        DoSmoothness();
        DoNormals();
        DoOcclusion();
        DoEmission();
        DoDetailMask();
        editor.TextureScaleOffsetProperty(mainTex);
    }

	void DoNormals()
	{
        MaterialProperty normalMap = FindProperty("_NormalMap");
        editor.TexturePropertySingleLine(
			MakeLabel(normalMap), normalMap,
			normalMap.textureValue ? FindProperty("_BumpScale") : null
		);
    }

	void DoMetallic()
	{
        // MaterialProperty metallic = FindProperty("_Metallic");
        // EditorGUI.indentLevel += 2;
        // editor.ShaderProperty(metallic, MakeLabel(metallic));
        // EditorGUI.indentLevel -= 2;		
        MaterialProperty metallicMap = FindProperty("_MetallicMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(metallicMap, "Metallic (R)"), metallicMap, 
			metallicMap.textureValue ? null : FindProperty("_Metallic")
		);
		if(EditorGUI.EndChangeCheck())
		{
        	SetKeyword("_METALLIC_MAP", metallicMap.textureValue);
		}
    }

    void DoEmission()
	{
        MaterialProperty emissionMap = FindProperty("_EmissionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertyWithHDRColor(
            MakeLabel(emissionMap, "Emission (RGB)"), emissionMap, 
			FindProperty("_Emission"), emissionConfig, false
		);
		if(EditorGUI.EndChangeCheck())
		{
        	SetKeyword("_EMISSION_MAP", emissionMap.textureValue);
		}
    }

    void DoDetailMask()
    {
        MaterialProperty detailMask = FindProperty("_DetailMask");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(detailMask, "Detail Mask (A)"), detailMask
		);
		if(EditorGUI.EndChangeCheck())
		{
        	SetKeyword("_DETAIL_MASK", detailMask.textureValue);
		}
    }

    void DoOcclusion()
    {
        MaterialProperty occlusionMap = FindProperty("_OcclusionMap");
        EditorGUI.BeginChangeCheck();
        editor.TexturePropertySingleLine(
            MakeLabel(occlusionMap, "Occlusion (G)"), occlusionMap, 
			occlusionMap.textureValue ? FindProperty("_OcclusionStrength") : null
		);
		if(EditorGUI.EndChangeCheck())
		{
        	SetKeyword("_OCCLUSION_MAP", occlusionMap.textureValue);
		}
    }
    

	void DoSmoothness()
	{
        SmoothnessSource source = SmoothnessSource.Uniform;
		if(IsKeywordEnabled("_SMOOTHNESS_ALBEDO"))
		{
            source = SmoothnessSource.Albedo;
        }
		else if(IsKeywordEnabled("_SMOOTHNESS_METALLIC"))
		{
            source = SmoothnessSource.Metallic;
        }

        MaterialProperty Smoothness = FindProperty("_Smoothness");
        EditorGUI.indentLevel += 2;		
        editor.ShaderProperty(Smoothness, MakeLabel(Smoothness));
        EditorGUI.indentLevel += 1;

        EditorGUI.BeginChangeCheck();
        source = (SmoothnessSource)EditorGUILayout.EnumPopup(MakeLabel("Source"), source);
		if(EditorGUI.EndChangeCheck())
		{
            RecordAction("Smoothness Source");
            SetKeyword("_SMOOTHNESS_ALBEDO", source == SmoothnessSource.Albedo);
            SetKeyword("_SMOOTHNESS_METALLIC", source == SmoothnessSource.Metallic);
        }
        EditorGUI.indentLevel -= 3;
    }

	void DoSecondary()
	{
		GUILayout.Label("Secondary Maps", EditorStyles.boldLabel);

        MaterialProperty detailTex = FindProperty("_DetailTex");
        editor.TexturePropertySingleLine(
			MakeLabel(detailTex, "Albedo (RGB) multiplied by 2"), detailTex
		);

        DoSecondaryNormals();
        editor.TextureScaleOffsetProperty(detailTex);
	}

	void DoSecondaryNormals()
	{
		MaterialProperty normalMap = FindProperty("_DetailNormalMap");
        editor.TexturePropertySingleLine(
			MakeLabel(normalMap), normalMap, 
			normalMap.textureValue ? FindProperty("_DetailBumpScale") : null
		);
	}

}
