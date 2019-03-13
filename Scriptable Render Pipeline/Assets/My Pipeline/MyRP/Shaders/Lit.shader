Shader "My Pipeline/Lit"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
	}
	SubShader
	{
		Pass
		{
			HLSLPROGRAM
			#pragma target 3.5
			
			#pragma multi_compile_instancing
			#pragma instancing_options assumeuniformscaling

			#pragma multi_compile _ _CASCADE_SHADOWS_SOFT _CASCADE_SHADOWS_HARD
			#pragma multi_compile _ _SHADOWS_SOFT
			#pragma multi_compile _ _SHADOWS_HARD

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment

			#include "MyRP/ShaderLibrary/Lit.hlsl"
			ENDHLSL
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			HLSLPROGRAM
			#pragma target 3.5

			#pragma multi_compile_instancing
			#pragma instancing_options assumeuniformscaling

			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment

			#include "MyRP/ShaderLibrary/ShadowCaster.hlsl"
			ENDHLSL
		}
	}
}
