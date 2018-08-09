using UnityEngine;
using UnityEditor;

public class MyTriplanarShaderGUI : MyBaseShaderGUI
{

	public override void OnGUI(MaterialEditor editor, MaterialProperty[] properties)
	{
		base.OnGUI(editor, properties);
		editor.ShaderProperty(FindProperty("_MapScale"), MakeLabel("Map Scale"));
		DoMaps();
		DoBlending();
		DoOtherSettings();
	}

	void DoMaps ()
	{
		GUILayout.Label("Maps", EditorStyles.boldLabel);

		editor.TexturePropertySingleLine(
			MakeLabel("Albedo"), FindProperty("_MainTex")
		);
		editor.TexturePropertySingleLine(
			MakeLabel(
				"MOHS",
				"Metallic (R) Occlusion (G) Height (B) Smoothness (A)"
			),
			FindProperty("_MOHSMap")
		);
		editor.TexturePropertySingleLine(
			MakeLabel("Normals"), FindProperty("_NormalMap")
		);
	}

	void DoBlending ()
	{
		GUILayout.Label("Blending", EditorStyles.boldLabel);

		editor.ShaderProperty(FindProperty("_BlendOffset"), MakeLabel("Offset"));
		editor.ShaderProperty(
			FindProperty("_BlendExponent"), MakeLabel("Exponent")
		);
		editor.ShaderProperty(
			FindProperty("_BlendHeightStrength"), MakeLabel("Height Strength")
		);
	}

	void DoOtherSettings ()
	{
		GUILayout.Label("Other Settings", EditorStyles.boldLabel);

		editor.RenderQueueField();
		editor.EnableInstancingField();
	}
}