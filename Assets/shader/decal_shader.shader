Shader "lsc/screen_decal_shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" 
            "Queue" = "Transparent-1"
        }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //float4x4 _mtx_view_inv;
            //float4x4 _mtx_proj_inv;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screen_pos:TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 cal_world_pos_by_dep(float ndc_dep, float2 screen_space, out float4 view_pos)
            {
                // 取出非线性深度与视深度
                float linearDepthZ = LinearEyeDepth(ndc_dep, _ZBufferParams);
                // 屏幕转ndc
                float4 ndc_pos;
                ndc_pos.xy = screen_space * 2.0 - 1.0;
                ndc_pos.zw = float2(ndc_dep, 1);
                // 添加齐次因子
                ndc_pos = ndc_pos * linearDepthZ;
                // 转成观察与世界坐标
                view_pos = mul(unity_CameraInvProjection/*_mtx_proj_inv*/, ndc_pos);
                float4 world_pos = mul(UNITY_MATRIX_I_V/*_mtx_view_inv*/, float4(view_pos.xyz, 1));

                return world_pos;
            }

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                o.screen_pos = ComputeScreenPos(o.vertex);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // 插值后的屏幕坐标去除齐次因子
                float2 screen_space = i.screen_pos.xy / i.screen_pos.w;
                // 取出非线性深度
                float org_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screen_space).x;
                // 计算世界坐标
                float4 view_pos;
                float4 world_pos = cal_world_pos_by_dep(org_depth, screen_space, view_pos);
                float3 localPos = mul(unity_WorldToObject, world_pos).xyz;
                clip(0.5 - abs(localPos));
                float2 uv = localPos.xz + 0.5;

                float4 col = tex2D(_MainTex, uv);

                //col.a = clamp((20 - length(view_pos.xyz)) / 20.0f, 0.0f, 1.0f);

                return col;
            }
            ENDHLSL
        }
    }
}
