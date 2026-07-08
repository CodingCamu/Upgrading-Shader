Shader "Basics/Loading Shader"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        
        _Color ("Base Color", Color) = (1,1,1,1)

        _Speed ("Speed", Float) = 1
    
        _Direction ("Direction", Vector) = (1, 0, 0, 0)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _Color;

            float _Speed;
            float4 _Direction;

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionCS = UnityObjectToClipPos(IN.vertex);
                OUT.uv = IN.uv;

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;

                
                float2 direction = normalize(_Direction.xy);
                uv += direction * _Time.y * _Speed;

                float4 tex = tex2D(_MainTex, uv);

                return tex * _Color;
            }

            ENDHLSL
        }
    }
}