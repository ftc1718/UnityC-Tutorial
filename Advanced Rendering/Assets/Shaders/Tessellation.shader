// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Tessellation"
{
	Properties
	{
		_Color ("Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}

		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1

		[NoScaleOffset] _MetallicMap ("Metallic", 2D) = "white" {}
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5

		_DetailTex ("Detail Albedo", 2D) = "gray" {}
		[NoScaleOffset] _DetailNormalMap ("Detail Normals", 2D) = "bump" {}
		_DetailBumpScale ("Detail Bump Scale", Float) = 1

		[NoScaleOffset] _EmissionMap ("Emission", 2D) = "black" {}
		_Emission ("Emission", Color) = (0, 0, 0)

		[NoScaleOffset] _OcclusionMap ("Occlusion", 2D) = "white" {}
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = 1

		[NoScaleOffset] _DetailMask ("Detail Mask", 2D) = "white" {}

		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5

		[NoScaleOffset] _ParallaxMap ("Parallax", 2D) = "black" {}
		_ParallaxStrength ("Parallax Strength", Range(0, 0.1)) = 0

		[HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector] _DstBlend ("_DstBlend", Float) = 0
		[HideInInspector] _ZWrite ("_ZWrite", Float) = 1

		_WireframeColor ("Wireframe Color", Color) = (0, 0, 0, 1)
		_WireframeSmoothing ("Wireframe Smoothing", Range(0, 10)) = 1
		_WireframeThickness ("Wireframe Thickness", Range(0, 10)) = 1

		_TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
		// _TessellationEdgeLength ("Tessellation Edge Length", Range(0.1, 1)) = 0.5 // world space
		_TessellationEdgeLength ("Tessellation Edge Length", Range(5, 100)) = 50 // pixel
	}

	CGINCLUDE

	#define BINORMAL_PER_FRAGMENT
	#define FOG_DISTANCE

	#define PARALLAX_BIAS 0
	// #define PARALLAX_OFFSET_LIMITING
	#define PARALLAX_RAYMARCHING_STEPS 10
	#define PARALLAX_RAYMARCHING_INTERPOLATE
	#define PARALLAX_RAYMARCHING_SEARCH_STEPS 3
	#define PARALLAX_FUNCTION ParallaxRaymarching
	#define PARALLAX_SUPPORT_SCALED_DYNAMIC_BATCHING

	ENDCG

	SubShader
	{
		Pass
		{
			Tags
			{
				"LightMode" = "ForwardBase"
			}
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			CGPROGRAM

			#pragma target 4.6

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP
			#pragma shader_feature _PARALLAX_MAP
			#pragma shader_feature _TESSELLATION_EDGE

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			// #pragma multi_compile_instancing
			// #pragma instancing_options lodfade

			#pragma vertex MyTessellationVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma hull MyHullProgram
			#pragma domain MyDomainProgram
			#pragma geometry MyGeometryProgram

			#define FORWARD_BASE_PASS

			#include "MyFlatWireframe.cginc"
			#include "MyTessellation.cginc"

			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode" = "ForwardAdd"
			}

			// Blend One One
			Blend [_SrcBlend] One
			ZWrite Off

			CGPROGRAM

			#pragma target 4.6

			#pragma multi_compile_fwdadd_fullshadows

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP
			#pragma shader_feature _PARALLAX_MAP
			#pragma shader_feature _TESSELLATION_EDGE

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

			#pragma multi_compile_fog

			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma vertex MyTessellationVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma hull MyHullProgram
			#pragma domain MyDomainProgram
			#pragma geometry MyGeometryProgram

			#include "MyFlatWireframe.cginc"
			#include "MyTessellation.cginc"

			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode" = "Deferred"
			}

			CGPROGRAM

			#pragma target 4.6
//			#pragma exlude_renderers nomrt

			#pragma shader_feature _RENDERING_CUTOUT
			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _OCCLUSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _DETAIL_ALBEDO_MAP
			#pragma shader_feature _DETAIL_NORMAL_MAP
			#pragma shader_feature _PARALLAX_MAP
			#pragma shader_feature _TESSELLATION_EDGE

			#pragma multi_compile_prepassfinal

			//Objects with MultiLight can only  instancing in deferred rendering path
			// #pragma multi_compile_instancing
			// #pragma instancing_options lodfade

			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma vertex MyTessellationVertexProgram
			#pragma fragment MyFragmentProgram
			#pragma hull MyHullProgram
			#pragma domain MyDomainProgram
			#pragma geometry MyGeometryProgram

			#define DEFERRED_PASS

			#include "MyFlatWireframe.cginc"
			#include "MyTessellation.cginc"

			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			CGPROGRAM

			#pragma target 3.0

			#pragma multi_compile_shadowcaster

			#pragma shader_feature _ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT
			#pragma shader_feature _SMOOTHNESS_ALBEDO
			#pragma shader_feature _SEMITRANSPARENT_SHADOWS

			#pragma multi_compile _ LOD_FADE_CROSSFADE

			#pragma multi_compile_instancing
			#pragma instancing_options lodfade

			#pragma vertex MyShadowVertexProgram
			#pragma fragment MyShadowFragmentProgram

			#include "MyShadows.cginc"
			ENDCG
		}

		Pass
		{
			Tags
			{
				"LightMode" = "Meta"
			}

			Cull Off

			CGPROGRAM

			#pragma shader_feature _METALLIC_MAP
			#pragma shader_feature _ _SMOOTHNESS_ALBEDO _SMOOTHNESS_METALLIC
			#pragma shader_feature _EMISSION_MAP
			#pragma shader_feature _DETAIL_MASK
			#pragma shader_feature _DETAIL_ALBEDO_MAP

			#pragma vertex MyLightmappingVertexProgram
			#pragma fragment MyLightmappingFragmentProgram

			#include "MyLightMapping.cginc"
			ENDCG
		}
	}

	CustomEditor "MyLightingShaderGUI"

}