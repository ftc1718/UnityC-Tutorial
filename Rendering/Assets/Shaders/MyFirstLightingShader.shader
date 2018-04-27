// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/MyFirstLightingShader"
{
	Properties
	{
		_Tint ("Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}
		// _SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5, 0.5)
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
	}
	SubShader
	{
		Pass
		{
			Tags
			{
				"LightMode" = "ForwardBase"
			}
			CGPROGRAM

			#pragma target 3.0

			#pragma vertex vert
			#pragma fragment frag

			// #include "UnityCG.cginc"
			// #include "UnityStandardBRDF.cginc"
			// #include "UnityStandardUtils.cginc"
			#include "UnityPBSLighting.cginc"

			float4 _Tint;
			sampler2D _MainTex;
			float4 _MainTex_ST;

			float _Smoothness;
			// float4 _SpecularTint;
			float _Metallic;

			struct vertexData
			{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct Interpolators
			{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;		
				float3 normal : TEXCOORD1;	
				float3 worldPos : TEXCOORD2;	
			};

			Interpolators vert(vertexData v)
			{
				Interpolators i;
				i.position = UnityObjectToClipPos(v.position);
				i.worldPos = mul(unity_ObjectToWorld, v.position);
				i.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
				i.normal = UnityObjectToWorldNormal(v.normal);
				// TRANSFORM_TEX(v.uv, _MainTex);
				return i;
			}

			float4 frag(Interpolators i) : SV_TARGET
			{
				i.normal = normalize(i.normal);
				float3 lightDir = _WorldSpaceLightPos0.xyz;
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
				float3 halfVector = normalize(lightDir + viewDir);
				float3 lightColor = _LightColor0.rgb;

				float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;

				/*caculate the diffuse(albedo) and the reflect(spcular) simplest metallic workflow*/
				// float3 specularTint = albedo * _Metallic;
				// albedo *= 1 - _Metallic;
				float3 specularTint;
				float oneMinusReflectivity;
				albedo = DiffuseAndSpecularFromMetallic(
					albedo, _Metallic, specularTint, oneMinusReflectivity
				);
				float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
				float3 specular = specularTint * lightColor * pow(DotClamped(halfVector, i.normal), _Smoothness * 100);
				
				UnityLight light;
				light.color = lightColor;
				light.dir = lightDir;
				light.ndotl = DotClamped(i.normal, lightDir);

				UnityIndirect indirectLight;
				indirectLight.diffuse = 0;
				indirectLight.specular = 0;

				return UNITY_BRDF_PBS(
					albedo, specularTint, 
					oneMinusReflectivity, _Smoothness,
					i.normal, viewDir,
					light, indirectLight
				);
				// return float4(diffuse + specular, 1);
			}
			ENDCG
		}
	}
}