Shader "lsc/test_post_fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _CloudTex("Texture", 2D) = "white" {}
    }

    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D _MainTex;

            //sampler2D _CameraDepthTexture;
            float4x4 _mtx_view_inv;
            float4x4 _mtx_proj_inv;
            //float4x4 _mtx_clip_to_world;
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            //cloud
            TEXTURE2D_X_FLOAT(_CloudTex);
            SAMPLER(sampler_LinearClamp);//work
            float4x4 _mtx_cloud_uv_rotate;
            float4 _cloud_offset_scale;
            //SAMPLER(sampler_CloudTex)
            //{
            //    Filter = MIN_MAG_MIP_LINEAR;
            //    AddressU = Clamp;//no work
            //    AddressV = Clamp;//no work
            //};

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;

                float4 screen_pos : TEXCOORD1;
                float2 ndc_pos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;

                o.uv = v.uv;

                o.screen_pos = ComputeScreenPos(o.vertex);
                o.ndc_pos = (v.uv) * 2.0 - 1.0;

                return o;
            }


            float4 frag(v2f i) : SV_Target
            {
                float4 view_pos;
                float3 world_pos;

                float depth01 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r;

                //lsc 取出线性深度,即摄影机空间的z坐标
                float linearDepthZ = LinearEyeDepth(depth01, _ZBufferParams);

                //lsc 纹理映射转换到标准空间
                float4 screen_pos = float4(i.ndc_pos.x, i.ndc_pos.y, depth01, 1);
                //lsc 转成齐次坐标
                screen_pos = screen_pos * linearDepthZ;
                //lsc 还原摄影机空间坐标
                view_pos = mul(_mtx_proj_inv, screen_pos);
                //lsc 世界
                world_pos = mul(_mtx_view_inv, float4(view_pos.xyz, 1));

                //高度雾衰减
                float h_percent = saturate(((world_pos.y - 0.0f) / 20.0f));
                float fac_h = exp(-h_percent * h_percent);

                //距离雾衰减
                float dis = length(world_pos.xyz - _WorldSpaceCameraPos.xyz);
                float d_percent = 1 - ((dis - 50.0) / 100.0f);
                d_percent = saturate(d_percent);
                float fac_d = exp(-d_percent * d_percent);

                float4 final_col;
                final_col.w = 1.0;

                float4 col = tex2D(_MainTex, i.uv);

                //cloud  处理云阴影,纹理平移旋转
                float2 cloud_uv = (world_pos.xz - _cloud_offset_scale.xy) / _cloud_offset_scale.z;
                cloud_uv = cloud_uv * 2 - 1;
                cloud_uv = mul(_mtx_cloud_uv_rotate, float4(cloud_uv.x, 0, cloud_uv.y, 0)).xz;
                cloud_uv = cloud_uv * 0.5 + 0.5;
                float4 cloud = SAMPLE_TEXTURE2D_X(_CloudTex, sampler_LinearClamp, cloud_uv);// _CloudTex.Sample(sampler_LinearClamp, cloud_uv);
                float cloud_dis = length(world_pos.xz - (_cloud_offset_scale.xy + _cloud_offset_scale.z/2));
                cloud.r = cloud.r * pow(clamp(1 - cloud_dis / (_cloud_offset_scale.z * 0.6), 0, 1), 1);
                col.xyz = lerp(col.xyz, float3(0, 0, 0), cloud.r); //return col;

                //最终雾效
                final_col.rgb = lerp(col.rgb, float3(0.2, 0.5, 0.8), fac_d * fac_h * 1);

                return final_col;
            }
            ENDHLSL
        }
    }
}
