Shader "Custom RP/Unlit"
{
    Properties
    {
		_BaseColor("Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM

			#pragma multi_compile_instancing
            #pragma vertex UnlitPassVertex
            #pragma fragment UnlitPassFragment
			#include "UnlitPass.hlsl"

            ENDHLSL
        }
    }
}
