﻿Shader "My Pipeline/Lit"
{
	Properties
	{
		_Color ("Color", Color) = (1, 1, 1, 1)
		_MainTex("Albedo & Alpha", 2D) = "white" {}
		[KeywordEnum(Off, On, Shadows)] _Clipping("Alpha Clipping", Float) = 0
		_Cutoff("Alpha Cutoff", Range(0, 1)) = 0.5
		_Smoothness("Smoothness", Range(0, 1)) = 0.5
		[Enum(UnityEngine.Rendering.CullMode)]_Cull("Cull", Float) = 2
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite("Z Write", Float) = 1
		[Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows("Receive Shadows", Float) = 1
	}
	SubShader
	{
		Pass
		{
			Blend[_SrcBlend] [_DstBlend]
			Cull[_Cull]
			ZWrite[_ZWrite]

			HLSLPROGRAM
			#pragma target 3.5
			
			#pragma multi_compile_instancing
			#pragma instancing_options assumeuniformscaling

			#pragma shader_feature _CLIPPING_ON
			#pragma shader_feature _RECEIVE_SHADOWS

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
			Cull[_Cull]
			Tags { "LightMode" = "ShadowCaster" }
			HLSLPROGRAM
			#pragma target 3.5

			#pragma multi_compile_instancing
			#pragma instancing_options assumeuniformscaling

			#pragma shader_feature _CLIPPING_OFF
			
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment

			#include "MyRP/ShaderLibrary/ShadowCaster.hlsl"
			ENDHLSL
		}
	}
	CustomEditor "LitShaderGUI"
}
