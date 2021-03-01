Shader "K2/Urp/Unlit_World_Ocean" 
{
    Properties
    {
        _NormTex("Normal Tex", 2D) = "white"{}
        _WorldUVTilling("World UV Tilling", Range(0, 0.1)) = 0.01
        _WaveSpeed("Wave Speed", Vector) = (0.01, 0.01, -0.01, -0.01)
        _NormalStrength("Normal Strength", Range(0.00001, 1)) = 0.526
        _ShallowColor("Shallow Color", Color) = (0, 0.1568, 0.396, 1)
        _DeepColor("Deep Color", Color) = (0, 0.1568, 0.396, 1)
        _DepthEdge("Depth Edge", Range(0, 2)) = 1

        [Header(Reflect)]
        _Reflection("Reflection Tex", 2D) = "white"{}
        _ReflectPower("Reflect Power", Range(0, 1)) = 0.265
        _Shininess("Shininess", Range(0, 0.03)) = 0.0012

        [Header(Foam Control)]
        _FoamMask("Foam Mask", 2D) = "white"{}
        _FoamColor("Foam Color", Color) = (1, 1, 1, 1)
        _FoamRange("Foam Range", Range(0, 1)) = 0.86
        _FoamWidth("Foam Width", Range(0, 0.2)) = 0.03
        _BigFoamSpeed("Big Foam Speed", Range(0, 1)) = 0.8
        _BigFoamAmplitude("Big Foam Amplitude", Range(0, 1)) = 0.15
        _BigFoamPosition("Big Foam Position", Range(0, 1)) = 0.15
        _Foam1Speed("Foam1 Speed", Range(0, 0.5)) = 0.1
        _Foam2Speed("Foam2 Speed", Range(0, 0.5)) = 0.165

        // [Header(Specular Control)]
        // _SpecularRangeMin("Specular Range Min", Range(0, 1)) = 0.937
        // _SpecularRangeMax("Specular Range Max", Range(0, 1)) = 1
        // _SpecularNoiseCutoff("Specular Noise Cutoff", Range(0, 1)) = 0.777
        // _SpecularDistortion("Specular Distortion", 2D) = "white" {}
        // _SpecularNoise("Specular Noise", 2D) = "white" {}
        // _SpecularSpeed("Specular Speed", Vector) = (-0.02, 0.02, 1, 1)
        // _DistortionStrength("Distortion Strength", Range(0, 1)) = 0.031
    }

    SubShader
    {
        Tags { "RenderType"="Transparent""Queue"="Transparent" "RenderPipeline"="UniversalRenderPipeline"}
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma exclude_renderers d3d11_9x
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #define UNITY_PI            3.14159265359f
			#define SMOOTHSTEP_AA       0.01

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float2 worldUV      : TEXCOORD0;
                float4 positionHCS  : SV_POSITION;
                float3 positionWS   : TEXCOORD1;
                float3 viewWS       : TEXCOORD2;
                float3 normalWS     : TEXCOORD3;
                float4 normalUV     : TEXCOORD4;
                float3 tangentWS    : TEXCOORD5;
                float3 bitangentWS  : TEXCOORD6;
                float4 screenPosition : TEXCOORD7;
            };

			CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_NormTex);
                SAMPLER(sampler_NormTex);
                TEXTURE2D(_Reflection);
                SAMPLER(sampler_Reflection);
                TEXTURE2D(_FoamMask);
                SAMPLER(sampler_FoamMask);

                float _WorldUVTilling;
                float4 _WaveSpeed;
                float _NormalStrength;
                float4 _ShallowColor;
                float4 _DeepColor;
                float _DepthEdge;

                float _ReflectPower;
                float _Shininess;

                float4 _FoamColor;
                float _FoamRange;
                float _FoamWidth;
                float _Foam1Speed;
                float _Foam2Speed;
                float _BigFoamSpeed;
                float _BigFoamAmplitude;
                float _BigFoamPosition;
                
                // TEXTURE2D(_SpecularDistortion);
                // SAMPLER(sampler_SpecularDistortion);
                // TEXTURE2D(_SpecularNoise);
                // SAMPLER(sampler_SpecularNoise);
                // float4 _SpecularSpeed;
                // float _SpecularRangeMin;
                // float _SpecularRangeMax;
                // float _SpecularNoiseCutoff;
                // float _DistortionStrength;
			CBUFFER_END

            float4 GenerateFoam(float maskValue, float depthValue, float visibleValue, float foamPosition)
            {
                half foamLine = smoothstep(depthValue - SMOOTHSTEP_AA, depthValue + SMOOTHSTEP_AA, foamPosition) * 
                                smoothstep(foamPosition - _FoamWidth - SMOOTHSTEP_AA,  foamPosition - _FoamWidth + SMOOTHSTEP_AA, depthValue);
                half4 foamColor = maskValue * _FoamColor * foamLine * visibleValue; //浪花遮罩 * 浪花颜色 * 浪花宽度线 * 浪花的可见性（大浪花会吞噬小浪花;浪花柔和出现）
                return foamColor;
            }

            float BRDF_SPECULAR(float NdotH, float i_roughness) 
            {
                //DGGX =  a^2 / π((a^2 – 1) (n · h)^2 + 1)^2
                float a2 = i_roughness * i_roughness;
                float val = ((a2 - 1) * (NdotH * NdotH) + 1);
                return a2 / (UNITY_PI * (val * val));
            }

            Varyings vert(Attributes i)
            {
                Varyings o;

                o.positionHCS = TransformObjectToHClip(i.positionOS.xyz);
                o.screenPosition = ComputeScreenPos(o.positionHCS);

                o.normalWS = normalize(mul(unity_ObjectToWorld, i.normalOS));
                o.tangentWS = normalize(mul(unity_ObjectToWorld, i.tangentOS.xyz));;
                o.bitangentWS = normalize(cross(o.normalWS, o.tangentWS) * i.tangentOS.w);

                o.positionWS = mul(unity_ObjectToWorld, i.positionOS);
                o.worldUV = float2(o.positionWS.x, o.positionWS.z) * _WorldUVTilling;
                o.normalUV.xy = o.worldUV + half2(_Time.y * _WaveSpeed.x, _Time.y * _WaveSpeed.y);
                o.normalUV.zw = o.worldUV + half2(_Time.y * _WaveSpeed.z, _Time.y * _WaveSpeed.w);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                //法线转换
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormTex, sampler_NormTex, i.normalUV.xy) * 2 + SAMPLE_TEXTURE2D(_NormTex, sampler_NormTex, i.normalUV.zw) * 2 - 2);
                normalTS.xy = normalTS.xy * _NormalStrength;
                float3x3 TBN = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3 normalWS = normalize(mul(normalTS, TBN));

                //深度
                float depth = SampleSceneDepth(i.screenPosition.xy / i.screenPosition.w);
                float linearDepth = LinearEyeDepth(depth, _ZBufferParams);
                float depthDifference = linearDepth - i.screenPosition.w;
                depthDifference = saturate(depthDifference / _DepthEdge);

                //深浅混合
                float4 waterColor = lerp(_ShallowColor, _DeepColor, depthDifference);
                
                //大浪花
                float4 foamMask = SAMPLE_TEXTURE2D(_FoamMask, sampler_FoamMask, i.worldUV);
                half bigFoamPosition = _BigFoamPosition + sin(_Time.y * _BigFoamSpeed) * _BigFoamAmplitude;
                waterColor += GenerateFoam(foamMask.r, depthDifference, 1, bigFoamPosition);

                //设置小浪花的可见性
                float foamVisible = smoothstep(bigFoamPosition- SMOOTHSTEP_AA,  bigFoamPosition + SMOOTHSTEP_AA, depthDifference);  //大浪花吞噬小浪花
                foamVisible *= (1 - depthDifference);   //小浪花柔和出现。

                //小浪花_1
                half foamPosition = _FoamRange - _FoamRange * fmod(_Time.y * _Foam1Speed, 1);
                waterColor += GenerateFoam(foamMask.r, depthDifference, foamVisible, foamPosition);

                //小浪花_2
                foamPosition = _FoamRange - _FoamRange * fmod(_Time.y * _Foam2Speed, 1);
                waterColor += GenerateFoam(foamMask.g, depthDifference, foamVisible, foamPosition);

                //反射
                float3 viewWS = normalize(_WorldSpaceCameraPos - i.positionWS);
                float4 ViewDirection = normalize(float4(viewWS.x, viewWS.y, viewWS.z, 0));
                float2 ReflectUV = float2((ViewDirection.x + 1) * 0.5, (ViewDirection.y + 1) * 0.5) * _WorldUVTilling;
                float4 reflectColor = SAMPLE_TEXTURE2D(_Reflection, sampler_Reflection, ReflectUV.xy + normalWS);

                //菲涅尔
                float fresnel = (1 - dot(viewWS, i.normalWS));
                fresnel = smoothstep(_ReflectPower, 1, fresnel);
                waterColor += reflectColor * fresnel;

                //高光区域
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                float3 halfDirection = normalize(viewWS + normalize(mainLight.direction));
                float specularArea = saturate(dot(normalWS, halfDirection));
                
                //柔和高光
                waterColor += BRDF_SPECULAR(specularArea, _Shininess);

                //卡通高光
                // specularArea = smoothstep(_SpecularRangeMin, _SpecularRangeMax, specularArea);
                // float2 distortSample = (SAMPLE_TEXTURE2D(_SpecularDistortion, sampler_SpecularDistortion, i.worldUV).xy * 2 - 1) * _DistortionStrength;
                // float2 noiseUV = float2((i.worldUV.x + _Time.y * _SpecularSpeed.x) + distortSample.x, (i.worldUV.y + _Time.y * _SpecularSpeed.y) + distortSample.y);
                // float specularNoiseSample = SAMPLE_TEXTURE2D(_SpecularNoise, sampler_SpecularNoise, noiseUV).r;
                // float specularNoise = smoothstep(_SpecularNoiseCutoff - SMOOTHSTEP_AA, _SpecularNoiseCutoff + SMOOTHSTEP_AA, specularNoiseSample);
                // float4 specularNoiseColor = _FoamColor * specularNoise;
                // waterColor += specularNoiseColor * specularArea * depthDifference;

                return float4(waterColor.rgb, depthDifference);
            }
            ENDHLSL
        }
    }
}