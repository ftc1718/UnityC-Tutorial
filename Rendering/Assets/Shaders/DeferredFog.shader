Shader "Custom/DeferredFog"
{
	Properties
	{
		_MainTex ("Source", 2D) = "white" {}
	}
	SubShader
	{
		Cull off
		ZTest Always
		ZWrite off

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#pragma multi_compile_fog

			#define FOG_DISTANCE
			// #define FOG_SKYBOX

			#include "UnityCG.cginc"

			sampler2D _MainTex, _CameraDepthTexture;
			float4 _MainTex_ST;

			float3 _FrustumCorners[4];

			struct VertexData
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Interpolators
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;

				#if defined(FOG_DISTANCE)
					float3 ray : TEXCOORD1;
				#endif
			};

			Interpolators vert(VertexData v)
			{
				Interpolators i;
				i.pos = UnityObjectToClipPos(v.vertex);
				i.uv = v.uv;

				#if defined(FOG_DISTANCE)
					i.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
				#endif
				// i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return i;
			}

			float4 frag(Interpolators i) : SV_TARGET
			{
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth = Linear01Depth(depth);
				float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
				#if defined(FOG_DISTANCE)
					viewDistance = length(i.ray * depth);
				#endif
				UNITY_CALC_FOG_FACTOR_RAW(viewDistance);

				unityFogFactor = saturate(unityFogFactor);
				#if defined(FOG_SKYBOX)
					if(depth > 0.999)
					{
						unityFogFactor = 1;
					}
				#endif
				#if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)  //no fog
					unityFogFactor = 1;
				#endif

				float3 color = tex2D(_MainTex, i.uv).rgb;
				float3 fogColor = lerp(unity_FogColor.rgb, color, saturate(unityFogFactor));
				return float4(fogColor, 1);
			}
			ENDCG
		}
	}
}
