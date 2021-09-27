Shader "lsc/csm_shader"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
    }
    
    SubShader
    {
        LOD 100
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel" = "2.0"}

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT


            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD2;
                float3 world_pos : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert(appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;

                o.world_pos = vertexInput.positionWS;

                return o;
            }

            //����ļ���csm����ӳ�亯��
            //unity�����еļ�����Ӱˢ��һ���������
            //ͨ���л�shadow coord�ķ�ʽȡ��ͬ�����ȵĹ�Դ�������
            //ÿ���������������ò�����ķ�ʽ
            float4 anhei_TransformWorldToShadowCoord(float3 positionWS)
            {
                half cascadeIndex = ComputeCascadeIndex(positionWS);

                float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

                return float4(shadowCoord.xyz, cascadeIndex);
            }

            //�Զ���ֱ��ָ��ȡĳ������μ�����Ӱ
            float4 anhei_TransformWorldToShadowCoord2(int idx, float3 positionWS)
            {
                half cascadeIndex = idx;

                float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

                return float4(shadowCoord.xyz, cascadeIndex);
            }

            //������㵱ǰ���ص�(��������)�����ĸ�������
            half anhei_ComputeCascadeIndex(float3 positionWS)
            {
                float3 fromCenter0 = positionWS - _CascadeShadowSplitSpheres0.xyz;
                float3 fromCenter1 = positionWS - _CascadeShadowSplitSpheres1.xyz;
                float3 fromCenter2 = positionWS - _CascadeShadowSplitSpheres2.xyz;
                float3 fromCenter3 = positionWS - _CascadeShadowSplitSpheres3.xyz;
                float4 distances2 = float4(dot(fromCenter0, fromCenter0), dot(fromCenter1, fromCenter1), dot(fromCenter2, fromCenter2), dot(fromCenter3, fromCenter3));

                half4 weights = half4(distances2 < _CascadeShadowSplitSphereRadii);
                weights.yzw = saturate(weights.yzw - weights.xyz);

                return 4 - dot(weights, half4(4, 3, 2, 1));
            }


        float4 frag(v2f i) : SV_Target
        {
            // sample the texture
            float4 col = tex2D(_MainTex, i.uv);
            float3 nml = normalize(i.normal.xyz);

            int cas_idx_1 = anhei_ComputeCascadeIndex(i.world_pos);

            Light light_1;
            Light light_0;
            half shadow_mix = 1.0f;
            float mix_fact = 0;
            if (cas_idx_1 == 0)//ֻ�����һ��������,�����������̫Զ��,�ڻ����Ͽ��ܿ�����
            {
                float4 shadow_coord0 = anhei_TransformWorldToShadowCoord2(0, i.world_pos);
                light_0 = GetMainLight(shadow_coord0);

                float4 shadow_coord1 = anhei_TransformWorldToShadowCoord2(1, i.world_pos);
                light_1 = GetMainLight(shadow_coord1);

                //���һ���������ľ���
                float3 fromCenter0 = i.world_pos - _CascadeShadowSplitSpheres0.xyz;
                float3 first_sphere_dis = length(fromCenter0);
                //��һ��������İ뾶
                float first_sphere_rad = sqrt(_CascadeShadowSplitSphereRadii.x);

                //��һ���򵥵Ĳ�ֵ todo:�����ò�ֵ�����Ż�
                mix_fact = clamp((first_sphere_dis) / (first_sphere_rad / 1.0f), 0.0f, 1.0f);
                shadow_mix = light_0.shadowAttenuation* (1 - mix_fact) + light_1.shadowAttenuation * mix_fact;

                //shadow_mix = light_0.shadowAttenuation;
            }
            else
            {
                float4 shadow_coord1 = anhei_TransformWorldToShadowCoord2(1, i.world_pos);
                light_1 = GetMainLight(shadow_coord1);
                shadow_mix = light_1.shadowAttenuation;
            }
            col.rgb = shadow_mix * col.rgb;

            return col;
        }
        ENDHLSL
    }

        // ShadowCaster ������д���Դ���������
        // ʹ���Զ����shadow caster, urp��ӹ�Դ�����㳡Ӱ
        pass
        {
            Tags{ "LightMode" = "ShadowCaster" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float3 _LightDirection;

            v2f vert(appdata v)
            {
                v2f o;
                float3 world_pos = TransformObjectToWorld(v.vertex);
                float3 world_nml = TransformObjectToWorldNormal(v.normal);
                o.pos = TransformWorldToHClip(ApplyShadowBias(world_pos, world_nml, _LightDirection));
                return o;
            }
            float4 frag(v2f i) : SV_Target
            {
                float4 color;
                color.xyz = float3(0.0, 0.0, 0.0);
                return color;
            }
            ENDHLSL
        }


        // DepthOnly ֱ��ʹ������hlsl����
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

    }
}
