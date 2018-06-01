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

			#include "UnityCG.cginc"

			sampler2D _MainTex, _CameraDepthTexture;
			float4 _MainTex_ST;

			struct VertexData
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Interpolators
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

			Interpolators vert(VertexData v)
			{
				Interpolators i;
				i.pos = UnityObjectToClipPos(v.vertex);
				i.uv = v.uv;
				// i.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return i;
			}

			float4 frag(Interpolators i) : SV_TARGET
			{
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth = Linear01Depth(depth);
				float viewDistance = depth * _ProjectionParams.z;
				UNITY_CALC_FOG_FACTOR_RAW(viewDistance);

				float3 color = tex2D(_MainTex, i.uv).rgb;
				float3 fogColor = lerp(unity_FogColor.rgb, color, saturate(unityFogFactor));
				return float4(fogColor, 1);
			}
			ENDCG
		}
	}
}
