Shader "Basics/Loading Shader"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Texture Color", Color) = (1, 1, 1, 1)
        _LoadingColor ("Color Before Loading", Color) = (0.1, 0.1, 0.1, 1)

        _BuildProgress ("Build Progress", Range(0, 1)) = 0
        _BottomHeight ("Model Bottom Height", Float) = 0
        _TopHeight ("Model Top Height", Float) = 1

        _Speed ("Movement Speed", Float) = 0.2
        _Direction ("Movement Direction", Vector) = (1, 0, 0, 0)

        _EdgeSoftness ("Loading Edge Softness", Range(0.001, 0.2)) = 0.01
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;

            float4 _Color;
            float4 _LoadingColor;

            float _BuildProgress;
            float _BottomHeight;
            float _TopHeight;

            float _Speed;
            float4 _Direction;

            float _EdgeSoftness;

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float localHeight : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionCS = UnityObjectToClipPos(IN.vertex);
                OUT.uv = IN.uv;
                OUT.localHeight = IN.vertex.y;

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float progress = saturate(_BuildProgress);

                float heightRange = max(
                    _TopHeight - _BottomHeight,
                    0.0001
                );

                float normalizedHeight = saturate(
                    (IN.localHeight - _BottomHeight) /
                    heightRange
                );

                float loadingMask = 1.0 - smoothstep(
                    progress,
                    progress + _EdgeSoftness,
                    normalizedHeight
                );

                float2 movingUV = IN.uv;

                float directionLength =
                    length(_Direction.xy);

                float2 direction =
                    directionLength > 0.0001
                    ? _Direction.xy / directionLength
                    : float2(0.0, 0.0);

                movingUV +=
                    direction *
                    _Time.y *
                    _Speed;

                float4 textureColor =
                    tex2D(_MainTex, movingUV) *
                    _Color;

                return lerp(
                    _LoadingColor,
                    textureColor,
                    loadingMask
                );
            }

            ENDHLSL
        }
    }
}