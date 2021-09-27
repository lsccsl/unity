Shader "lsc/shadow_shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            //#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            //#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

        // -------------------------------------
        // Material Keywords
        //#pragma shader_feature_local _NORMALMAP
        //#pragma shader_feature_local_fragment _ALPHATEST_ON
        //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
        //#pragma shader_feature_local_fragment _EMISSION
        //#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
        //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        //#pragma shader_feature_local_fragment _OCCLUSIONMAP
        //#pragma shader_feature_local _PARALLAXMAP
        //#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
        //#pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
        //#pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
        //#pragma shader_feature_local_fragment _SPECULAR_SETUP
        //#pragma shader_feature_local _RECEIVE_SHADOWS_OFF

        // -------------------------------------
        // Universal Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        //#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        //#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
        //#pragma multi_compile _ SHADOWS_SHADOWMASK

        // -------------------------------------
        // Unity defined keywords
        //#pragma multi_compile _ DIRLIGHTMAP_COMBINED
        //#pragma multi_compile _ LIGHTMAP_ON
        //#pragma multi_compile_fog

        //--------------------------------------
        // GPU Instancing
        //#pragma multi_compile_instancing
        //#pragma multi_compile _ DOTS_INSTANCING_ON

        #pragma vertex LitPassVertex
        #pragma fragment LitPassFragment


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                //float2 lightmapUV   : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD2;
                float3 world_pos : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = v.normal;

                o.world_pos = vertexInput.positionWS;// mul(GetObjectToWorldMatrix(), float4(v.vertex.xyz, 1.0f));
                //OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 col = tex2D(_MainTex, i.uv);
                float3 nml = normalize(i.normal.xyz);

                float4 shadow_coord = TransformWorldToShadowCoord(i.world_pos);

                Light mainLight = GetMainLight(shadow_coord);
                half3 light_col = mainLight.color * mainLight.shadowAttenuation;// mainLight.color;
                //half4 shadow_mask = SAMPLE_SHADOWMASK(i.lightmapUV);
                //Light mainLight = GetMainLight(shadow_coord, i.world_pos, shadow_mask);

                half shadow = mainLight.shadowAttenuation;
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light add_light = GetAdditionalLight(lightIndex, i.world_pos, half4(1,1,1,1));
                    light_col += add_light.color * add_light.shadowAttenuation * add_light.distanceAttenuation * clamp(dot(nml, add_light.direction), 0, 1);
                }

                col.rgb = light_col * col.rgb;// *clamp(shadow, 0.3f, 1.0f);
                return col;
            }
            ENDHLSL
        }

        // ShadowCaster 将物体写入光源的深度纹理
        // 使用自定义的shadow caster, urp会从光源处拍摄场影
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


        // DepthOnly 直接使用内置hlsl代码
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
