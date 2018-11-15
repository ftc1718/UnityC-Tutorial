Shader "My Pipeline/Unlit"
{
	Properties
	{
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma target 3.5
			
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment

			#include "MyRP/ShaderLibrary/Unlit.hlsl"
			ENDHLSL
		}
	}
}
