Shader "K2/Urp/UnlitTexture_Ground"
{
    Properties
    {
        _MainTex("Main Tex", 2D) = "white"{}
        _BaseMap("Depth Tex", 2D) = "white"{}

        [Toggle(OCEANON)]OCEANON("Ocean ON", int) = 0
        _NormTex("Normal Tex", 2D) = "white"{}
        _NormalStrength("Normal Strength", Range(0.00001, 1)) = 0.1
        _WaveSpeed("Wave Speed", Vector) = (0.002, 0.002, 0.002, 0.002)
        _WaveTiling("Wave Tilling", Range(0.05, 0.5)) = 0.25
        _ShallowColor("Shallow Color", Color) = (1, 1, 1, 1)
        _DeepColor("Deep Color", Color) = (1, 1, 1, 1)
        _DeepColor2("Deep Color2", Color) = (1, 1, 1, 1)
        _DeepUVScale("Deep UV Scale", Range(0, 0.01)) = 0.0015

        [Header(Foam Control)]
        _FoamMask("Foam Mask", 2D) = "white"{}
        _FoamColor("Foam Color", Color) = (1, 1, 1, 1)
        _FoamRange("Foam Range", Range(0, 1)) = 0.2
        _FoamWidth("Foam Width", Range(0, 0.2)) = 0.01
        _FoamSpeed("Foam Speed", Range(0, 0.5)) = 0.1
        _FoamSpeed2("Foam Speed2", Range(0, 0.5)) = 0.1
        _FoamOffset("Foam Offset", Range(0, 0.5)) = 0.2
        _BigFoamPosition("Big Foam Position", Range(0, 1)) = 0.2

        [Header(Specular Control)]
        _SpecularRangeMin("Specular Range Min", Range(0, 1)) = 0.8
        _SpecularRangeMax("Specular Range Max", Range(0, 1)) = 0.965
        _SpecularNoiseCutoff("Specular Noise Cutoff", Range(0, 1)) = 0.777
        _SpecularDistortion("Specular Distortion", 2D) = "white" {}
        _SpecularNoise("Specular Noise", 2D) = "white" {}
        _SpecularSpeed("Specular Speed", Vector) = (-0.02, 0.02, 1, 1)
        _DistortionStrength("Distortion Strength", Range(0, 1)) = 0.1

        [Header(Blend Control)]
        [Enum(Off,0,On,1)] _ZWrite ("ZWrite", Float) = 0  
    }

    SubShader
    {
        Tags { "RenderType"="Opaque""Queue"="Geometry-2" "RenderPipeline"="UniversalRenderPipeline"}
        ZWrite [_ZWrite]

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers d3d11_9x
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma multi_compile _ OCEANON

            #define UNITY_PI            3.14159265359f
			#define SMOOTHSTEP_AA       0.01

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            #ifdef OCEANON
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            #endif
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
            #ifdef OCEANON
                float3 positionWS   : TEXCOORD1;
                float3 viewWS       : TEXCOORD2;
                float3 NormalWS     : TEXCOORD3;
                float4 normalUV     : TEXCOORD4;
                float3 tangentWS    : TEXCOORD5;
                float3 bitangentWS  : TEXCOORD6;
            #endif
            };

			CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_MainTex);
                #ifdef OCEANON
                    TEXTURE2D(_NormTex);
                    SAMPLER(sampler_NormTex);
                    TEXTURE2D(_BaseMap);
                    SAMPLER(sampler_BaseMap);
                    TEXTURE2D(_FoamMask);
                    SAMPLER(sampler_FoamMask);
                    TEXTURE2D(_SpecularDistortion);
                    SAMPLER(sampler_SpecularDistortion);
                    TEXTURE2D(_SpecularNoise);
                    SAMPLER(sampler_SpecularNoise);

                    float4 _WaveSpeed;
                    float4 _ShallowColor;
                    float4 _DeepColor;
                    float4 _DeepColor2;
                    float4 _FoamColor;
                    float4 _SpecularSpeed;

                    float _DeepUVScale;
                    float _FoamRange;
                    float _FoamWidth;
                    float _FoamSpeed;
                    float _FoamSpeed2;
                    float _FoamOffset;
                    float _WaveTiling;
                    float _NormalStrength;
                    float _BigFoamPosition;
                    float _SpecularRangeMin;
                    float _SpecularRangeMax;

                    float _SpecularNoiseCutoff;
                    float _DistortionStrength;
                #endif
			CBUFFER_END

            #ifdef OCEANON
                float4 GenerateFoam(float maskValue, float depthValue, float visibleValue, float offset)
                {
                    half foamRange = _FoamRange - _FoamRange * fmod(_Time.y * _FoamSpeed + offset, 1);
                    half foamLine = smoothstep(depthValue - SMOOTHSTEP_AA, depthValue + SMOOTHSTEP_AA, foamRange) * 
                                    smoothstep(foamRange - _FoamWidth - SMOOTHSTEP_AA,  foamRange - _FoamWidth + SMOOTHSTEP_AA, depthValue);
                    half4 foamColor = maskValue * _FoamColor * foamLine * visibleValue;
                    return foamColor;
                }

                float4 GenerateBigFoam(float depthValue, float visibleValue)
                {
                    half foamRange = _BigFoamPosition + sin(_Time.y * _FoamSpeed * 8) * 0.15;
                    half foamLine = smoothstep(depthValue - SMOOTHSTEP_AA, depthValue + SMOOTHSTEP_AA, foamRange) * smoothstep(foamRange - _FoamWidth - SMOOTHSTEP_AA,  foamRange - _FoamWidth + SMOOTHSTEP_AA, depthValue);
                    half4 foamColor = _FoamColor * foamLine * visibleValue;
                    return foamColor;
                }
            #endif

            Varyings vert(Attributes i)
            {
                Varyings o;
                o.uv = i.uv;
                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);

                #ifdef OCEANON
                    o.NormalWS = normalize(mul(unity_ObjectToWorld, i.normalOS));
                    o.tangentWS = normalize(mul(unity_ObjectToWorld, i.tangentOS.xyz));;
                    o.bitangentWS = normalize(cross(o.NormalWS, o.tangentWS) * i.tangentOS.w);

                    o.positionWS = mul(unity_ObjectToWorld, i.positionOS);
                    o.viewWS = normalize(_WorldSpaceCameraPos - o.positionWS);

                    o.normalUV.xy = i.uv + half2(_SinTime.x * _WaveSpeed.x, _SinTime.x * _WaveSpeed.y);
                    o.normalUV.zw = i.uv + half2(_CosTime.y * _WaveSpeed.z, _SinTime.y * _WaveSpeed.w);
                #endif

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float4 groundColor = float4(1, 1, 1, 1);
                #ifdef OCEANON
                    //法线转换
                    float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormTex, sampler_NormTex, i.normalUV.xy) * 2 + SAMPLE_TEXTURE2D(_NormTex, sampler_NormTex, i.normalUV.zw) * 2 - 2);
                    normalTS.xy = normalTS.xy * _NormalStrength;
                    float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.NormalWS);
                    float3 normalWS = normalize(mul(normalTS, TBN));

                    float4 depthMask = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);    //深度值(a:海岸线透明度; b:海岸线浪花透明度)

                    //深水区
                    float2 deepUV = float2(i.positionWS.x * _DeepUVScale, i.positionWS.z * _DeepUVScale);
                    float deepIntensity = SAMPLE_TEXTURE2D(_SpecularNoise, sampler_SpecularNoise, deepUV).r;


                    //深浅区分
                    groundColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);        //地表颜色
                    float4 groundFlowColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv + normalWS);
                    float4 shallowColor = lerp(float4(1, 1, 1, 1), _ShallowColor, depthMask.a);   //浅水颜色
                    float4 deepColor = lerp(_DeepColor, _DeepColor2, deepIntensity);
                    float4 waterColor = lerp(_ShallowColor, deepColor, depthMask.a);              //深浅混合
                    //菲涅尔
                    //float fresnel = saturate(dot(i.NormalWS, i.viewWS));
                    //waterColor.rgb = lerp(_DeepColor2, waterColor.rgb, fresnel);

                    waterColor.rgb = lerp(groundColor.rgb, waterColor.rgb * groundFlowColor.r, depthMask.a);//和地表融合

                    //小浪花_1
                    float4 foamMask = SAMPLE_TEXTURE2D(_FoamMask, sampler_FoamMask, i.uv);    //浪花遮罩(r:小浪花_1的遮罩; g:小浪花_2的遮罩)
                    waterColor += GenerateFoam(foamMask.r, depthMask.a, depthMask.a, 0);
                    //小浪花_2
                    waterColor += GenerateFoam(foamMask.g, depthMask.a, depthMask.a, _FoamOffset);
                    //大浪花_3
                    waterColor += GenerateBigFoam(depthMask.a, depthMask.b);

                    //高光区域
                    Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                    float3 halfDirection = normalize(i.viewWS + normalize(mainLight.direction));
                    float specularArea = saturate(dot(halfDirection, normalWS));
                    specularArea = smoothstep(_SpecularRangeMin, _SpecularRangeMax, specularArea);

                    //高光颜色
                    float2 distortSample = (SAMPLE_TEXTURE2D(_SpecularDistortion, sampler_SpecularDistortion, i.uv).xy * 2 - 1) * _DistortionStrength;
                    float2 noiseUV = float2((i.uv.x + _Time.y * _SpecularSpeed.x) + distortSample.x, (i.uv.y + _Time.y * _SpecularSpeed.y) + distortSample.y);
                    float specularNoiseSample = SAMPLE_TEXTURE2D(_SpecularNoise, sampler_SpecularNoise, noiseUV).r;
                    float specularNoise = smoothstep(_SpecularNoiseCutoff - SMOOTHSTEP_AA, _SpecularNoiseCutoff + SMOOTHSTEP_AA, specularNoiseSample);
                    float4 specularNoiseColor = _FoamColor * specularNoise;
                    waterColor += specularNoiseColor * specularArea * depthMask.a;

                    return waterColor;
                #else
                    groundColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                #endif
                
                return groundColor;
            }
            ENDHLSL
        }
    }

}