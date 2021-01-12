Shader "Custom/Cloud Parallax" 
{
	Properties 
	{
		_Color("Color",Color) = (1,1,1,1)
		_BlendTex("MainTex", 2D) = "white" {}
		_Alpha("Alpha", Range(0,1)) = 0.655
		_Height("Displacement Amount",range(0,1)) = 0.08
		_HeightAmount("Turbulence Amount",range(0,2)) = 0.95
		_HeightTileSpeed("Turbulence Tile&Speed",Vector) = (1.2,1.0,0.05,0.0)
		_LightIntensity ("Ambient Intensity", Range(0,3)) = 1.0
		[Toggle] _UseFixedLight("Use Fixed Light", Int) = 1
		_FixedLightDir("Fixed Light Direction", Vector) = (0.16, 0.12, -0.148, 0.0)

		linearStep("linearStep", int) = 5
	}

	SubShader 
	{
		LOD 300		
        Tags 
		{
            "IgnoreProjector"="True"
            "Queue"="Transparent-50"
            "RenderType"="Transparent"
			"RenderPipeline" = "UniversalPipeline"
        }

		Pass
		{
		    Name "FORWARD"
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
				TEXTURE2D(_BlendTex);
				SAMPLER(sampler_BlendTex);
				float4 _BlendTex_ST;

				half _Height;
				float4 _HeightTileSpeed;
				half _HeightAmount;
				half4 _Color;
				half _Alpha;
				half _LightIntensity;

				half4 _LightingColor;
				half4 _FixedLightDir;
				half _UseFixedLight;
				float linearStep;
			CBUFFER_END

			struct a2v
			{
                float4 vertex	: POSITION;
                float4 uv			: TEXCOORD0;
				float3 normal		: NORMAL;
				float4 tangent	: TANGENT;
			};

			struct v2f 
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normalDir : TEXCOORD1;
				float3 viewDir : TEXCOORD2;
				float4 posWorld : TEXCOORD3;
				float2 uv2 : TEXCOORD4;
			};

			v2f vert (a2v v) 
			{
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv,_BlendTex) + frac(_Time.y*_HeightTileSpeed.zw);
				o.uv2 = v.uv * _HeightTileSpeed.xy;
				o.posWorld = mul(unity_ObjectToWorld, v.vertex);
				o.normalDir = normalize(mul(unity_ObjectToWorld, float4(v.normal, 0)));

				float3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
				float3x3 TBN = float3x3(v.tangent.xyz, binormal, v.normal);
				half3 viewDirWS = SafeNormalize(_WorldSpaceCameraPos - o.posWorld.xyz);
				half3 viewDirOS = mul(unity_WorldToObject, viewDirWS);

				o.viewDir = mul(TBN, viewDirOS);

				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
				float3 viewRay=normalize(i.viewDir*-1);
				viewRay.z=abs(viewRay.z);
				viewRay.xy *= _Height;
				float3 lioffset = viewRay / (viewRay.z * linearStep);

				float3 shadeP = float3(i.uv,0);

				float4 secondLayerColor = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, i.uv2);
				float secondLayerAlpha = secondLayerColor.a * _HeightAmount;

				float d = 1.0 - SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, shadeP.xy).a * secondLayerAlpha;
				float3 prev_d = d;
				float3 prev_shadeP = shadeP;
				
				[unroll(5)]
				while(d > shadeP.z)
				{
					prev_shadeP = shadeP;
					shadeP += lioffset;
					prev_d = d;
					d = 1.0 - SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, shadeP.xy).a * secondLayerAlpha;
				}
				float d1 = d - shadeP.z;
				float d2 = prev_d - prev_shadeP.z;
				float w = d1 / (d1 - d2);
				shadeP = lerp(shadeP, prev_shadeP, w);

				half4 c = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, shadeP.xy) * secondLayerColor * _Color;
				half Alpha = lerp(c.a, 1.0, _Alpha);

				float3 normal = normalize(i.normalDir);
				half3 lightDir1 = normalize(_FixedLightDir.xyz);
				half3 lightDir2 = _MainLightPosition.xyz - i.posWorld;
				half3 lightDir = lerp(lightDir2, lightDir1, _UseFixedLight);
				float NdotL = max(0,dot(normal,lightDir));
				half3 lightColor = _MainLightColor.rgb;
                half3 finalColor = c.rgb*(NdotL*lightColor + 1.0);
                return half4(finalColor.rgb,Alpha);


				// float4 secondLayerColor = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, i.uv2);

				// float3 fogTextureUV = float3(i.uv, 0);
				// float previousDepth = currentDepth;
				// float3 previousFogUV = fogTextureUV;

				// float3 viewDirection = normalize(-i.viewDir);
				// viewDirection.z = abs(viewDirection.z);
				// viewDirection.xy *= _Height;
				// float3 viewOffset = viewDirection / (viewDirection.z * _LayerCount);

				// [unroll(5)]
				// while(currentDepth > fogTextureUV.z)
				// {
				// 	previousDepth = currentDepth;
				// 	previousFogUV = fogTextureUV;
				// 	fogTextureUV += viewOffset;
				// 	currentDepth = 1.0 - SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, fogTextureUV.xy).a * secondLayerColor.a;
				// }

				// float leftDepth = currentDepth - fogTextureUV.z;
				// float rightDepth = previousDepth - previousFogUV.z;
				// float percentage = leftDepth / (leftDepth - rightDepth);
				// fogTextureUV = lerp(fogTextureUV, previousFogUV, percentage);

				// half4 mainColor = SAMPLE_TEXTURE2D(_BlendTex, sampler_BlendTex, fogTextureUV.xy) * secondLayerColor;
                // half3 finalColor = mainColor.rgb * (_MainLightColor.rgb);

                // return half4(finalColor.rgb, lerp(mainColor.a, 1.0, _Alpha));
			}
			ENDHLSL
		}
	}
}
