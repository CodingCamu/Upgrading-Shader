Shader "Basics/Sci-Fi Loading Shader"
{
    Properties
    {
        [Header(Base)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Texture Color", Color) = (1, 1, 1, 1)

        [Header(Build Progress)]
        _BuildProgress ("Build Progress", Range(0, 1)) = 0
        _BottomHeight ("Model Bottom Height", Float) = 0
        _TopHeight ("Model Top Height", Float) = 1
        _EdgeSoftness ("Loading Edge Softness", Range(0.001, 0.2)) = 0.01

        [Header(Dissolve Edge)]
        _NoiseTex ("Dissolve Noise", 2D) = "gray" {}
        _NoiseStrength ("Noise Strength", Range(0, 0.5)) = 0.1
        [HDR] _EdgeColor ("Edge Glow Color", Color) = (0, 8, 12, 1)
        _EdgeWidth ("Edge Glow Width", Range(0.001, 0.3)) = 0.05

        [Header(Fresnel Rim)]
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0, 2, 3, 1)
        _FresnelPower ("Fresnel Power", Range(0.5, 10)) = 3
        _FresnelIntensity ("Fresnel Intensity", Range(0, 5)) = 1

        [Header(Scanlines)]
        [HDR] _ScanlineColor ("Scanline Color", Color) = (0, 1, 1.5, 1)
        _ScanlineDensity ("Scanline Density", Float) = 60
        _ScanlineSpeed ("Scanline Speed", Float) = 2
        _ScanlineIntensity ("Scanline Intensity", Range(0, 1)) = 0.25

        [Header(Hologram Flicker)]
        _FlickerSpeed ("Flicker Speed", Float) = 16
        _FlickerIntensity ("Flicker Intensity", Range(0, 1)) = 0.1

        [Header(Texture Movement)]
        _Speed ("Movement Speed", Float) = 0.2
        _Direction ("Movement Direction", Vector) = (1, 0, 0, 0)

        _AlphaCutoff ("Alpha Cutoff", Range(0, 1)) = 0.01
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;

            float4 _Color;

            float _BuildProgress;
            float _BottomHeight;
            float _TopHeight;
            float _EdgeSoftness;

            float _NoiseStrength;
            float4 _EdgeColor;
            float _EdgeWidth;

            float4 _FresnelColor;
            float _FresnelPower;
            float _FresnelIntensity;

            float4 _ScanlineColor;
            float _ScanlineDensity;
            float _ScanlineSpeed;
            float _ScanlineIntensity;

            float _FlickerSpeed;
            float _FlickerIntensity;

            float _Speed;
            float4 _Direction;

            float _AlphaCutoff;

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float localHeight : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldViewDir : TEXCOORD3;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                OUT.positionCS = UnityObjectToClipPos(IN.vertex);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.localHeight = IN.vertex.y;

                float3 worldPos = mul(unity_ObjectToWorld, IN.vertex).xyz;
                OUT.worldNormal = UnityObjectToWorldNormal(IN.normal);
                OUT.worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                return OUT;
            }

            float4 frag(Varyings IN, float facing : VFACE) : SV_Target
            {
                float progress = saturate(_BuildProgress);

                float heightRange = max(_TopHeight - _BottomHeight, 0.0001);

                float normalizedHeight = saturate(
                    (IN.localHeight - _BottomHeight) / heightRange
                );

                float noise = tex2D(
                    _NoiseTex,
                    TRANSFORM_TEX(IN.uv, _NoiseTex)
                ).r;

                float dissolveHeight = normalizedHeight +
                    (noise - 0.5) * _NoiseStrength;

                float edgeLine = lerp(
                    -_NoiseStrength - _EdgeWidth,
                    1.0 + _NoiseStrength + _EdgeWidth,
                    progress
                );

                float loadingMask = 1.0 - smoothstep(
                    edgeLine,
                    edgeLine + _EdgeSoftness,
                    dissolveHeight
                );


                float edgeBand = smoothstep(
                    edgeLine - _EdgeWidth,
                    edgeLine,
                    dissolveHeight
                ) * loadingMask;

                edgeBand *= step(progress, 0.999);

                float2 movingUV = IN.uv;

                float directionLength = length(_Direction.xy);
                float2 direction =
                    directionLength > 0.0001
                    ? _Direction.xy / directionLength
                    : float2(0.0, 0.0);

                movingUV += direction * _Time.y * _Speed;

                float4 sampledTexture = tex2D(_MainTex, movingUV);
                float4 finalColor = sampledTexture * _Color;

                float3 normal = normalize(IN.worldNormal) * sign(facing);
                float3 viewDir = normalize(IN.worldViewDir);

                float fresnel = pow(
                    1.0 - saturate(dot(normal, viewDir)),
                    _FresnelPower
                );

                finalColor.rgb +=
                    _FresnelColor.rgb * fresnel * _FresnelIntensity;

                finalColor.a = saturate(
                    finalColor.a + fresnel * _FresnelIntensity * 0.5
                );

                float scanline = frac(
                    normalizedHeight * _ScanlineDensity -
                    _Time.y * _ScanlineSpeed
                );

                scanline = smoothstep(0.7, 1.0, scanline);

                finalColor.rgb +=
                    _ScanlineColor.rgb * scanline * _ScanlineIntensity;

                float flicker = 1.0 - _FlickerIntensity * (
                    0.5 + 0.5 * sin(_Time.y * _FlickerSpeed) *
                    sin(_Time.y * _FlickerSpeed * 3.7 + 1.3)
                );

                finalColor.a *= flicker;

                finalColor.rgb = lerp(
                    finalColor.rgb,
                    _EdgeColor.rgb,
                    saturate(edgeBand)
                );

                finalColor.a = max(finalColor.a * loadingMask, edgeBand);

                clip(finalColor.a - _AlphaCutoff);

                return finalColor;
            }

            ENDHLSL
        }
    }
}