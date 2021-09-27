Shader "lsc/scene_normal_show_shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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
            
            float4x4 _mtx_view_inv;
            float4x4 _mtx_proj_inv;

            // 法线
            TEXTURE2D_X_FLOAT(_CameraNormalTexture); SAMPLER(sampler_CameraNormalTexture);
            // 深度
            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                //float2 ndc_pos : TEXCOORD2;
                float4 screen_space : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;

                // 计算屏幕空间坐标(含齐次因子)
                o.screen_space = ComputeScreenPos(o.vertex);

                return o;
            }

            sampler2D _MainTex;
            float4 _offset_pixel; //像素偏移

            float2 sobel_edge_detect(float2 screen_space, float4 view_pos);
            float4 cal_world_pos_by_dep(float ndc_dep, float2 screen_space, out float4 view_pos);

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                float3 normal = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, i.uv).xyz;
                normal = normal * 2.0 - 1.0;


                // 插值后的屏幕坐标去除齐次因子
                float2 screen_space = i.screen_space.xy / i.screen_space.w;
                // 取出非线性深度
                float org_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screen_space).x;
                // 计算世界坐标
                float4 view_pos;
                float4 world_pos = cal_world_pos_by_dep(org_depth, screen_space, view_pos);


                float tmp = sobel_edge_detect(screen_space, view_pos).x;// view_pos.y / 5;//(500 - world_pos.z)/500;
                col.xyz = float3(tmp, tmp, tmp);

                return col;
            }

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
                view_pos = mul(_mtx_proj_inv, ndc_pos);
                float4 world_pos = mul(_mtx_view_inv, float4(view_pos.xyz, 1));

                return world_pos;
            }

            float2 sobel_edge_detect(float2 screen_space, float4 view_pos)
            {
                float2 texCoord = screen_space;

                float c0 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord).x;
                //float depliner01 = Linear01Depth(c0, _ZBufferParams);
                float depEye = LinearEyeDepth(c0, _ZBufferParams);
                float3 view_dir = -normalize(view_pos.xyz);

                //float view_scale = 1.0;// clamp(exp(-c0), 0.01f, 2.0f);
                //return float2(view_scale, view_scale);


                //float isEdge = 0;
                float offsetX = _offset_pixel.x * 0.6f;
                float offsetY = _offset_pixel.y * 0.6f;


                //float c1 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(offsetX, 0)).x;
                //float c2 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(0, -offsetY)).x;
                //float c3 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-offsetX, 0)).x;
                //float c4 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(0, offsetY)).x;
                float c5 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(offsetX, offsetY)).x;
                float c6 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(offsetX, -offsetY)).x;
                float c7 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-offsetX, -offsetY)).x;
                float c8 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-offsetX, offsetY)).x;

                //float c9  = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-2.0 * offsetX, -2.0 * offsetY)).x;
                //float c10 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-1.0 * offsetX, -2.0 * offsetY)).x;
                //float c11 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(0.0 * offsetX, -2.0 * offsetY)).x;
                //float c12 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(1.0 * offsetX, -2.0 * offsetY)).x;
                //float c13 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(2.0 * offsetX, -2.0 * offsetY)).x;
                //float c14 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-2.0 * offsetX, 2.0 * offsetY)).x;
                //float c15 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-1.0 * offsetX, 2.0 * offsetY)).x;
                //float c16 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(0.0 * offsetX, 2.0 * offsetY)).x;
                //float c17 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(1.0 * offsetX, 2.0 * offsetY)).x;
                //float c18 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(2.0 * offsetX, 2.0 * offsetY)).x;
                //float c19 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-2.0 * offsetX, -1.0 * offsetY)).x;
                //float c20 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(2.0 * offsetX, -1.0 * offsetY)).x;
                //float c21 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-2.0 * offsetX, 0.0 * offsetY)).x;
                //float c22 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(2.0 * offsetX, 0.0 * offsetY)).x;
                //float c23 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(-2.0 * offsetX, 1.0 * offsetY)).x;
                //float c24 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, texCoord + float2(2.0 * offsetX, 1.0 * offsetY)).x;


                //c1 = LinearEyeDepth(c1, _ZBufferParams);
                //c2 = LinearEyeDepth(c2, _ZBufferParams);
                //c3 = LinearEyeDepth(c3, _ZBufferParams);
                //c4 = LinearEyeDepth(c4, _ZBufferParams);
                c5 = LinearEyeDepth(c5, _ZBufferParams);
                c6 = LinearEyeDepth(c6, _ZBufferParams);
                c7 = LinearEyeDepth(c7, _ZBufferParams);
                c8 = LinearEyeDepth(c8, _ZBufferParams);

                //c9 = LinearEyeDepth(c9, _ZBufferParams);
                //c10 = LinearEyeDepth(c10, _ZBufferParams);
                //c11 = LinearEyeDepth(c11, _ZBufferParams);
                //c12 = LinearEyeDepth(c12, _ZBufferParams);
                //c13 = LinearEyeDepth(c13, _ZBufferParams);
                //c14 = LinearEyeDepth(c14, _ZBufferParams);
                //c15 = LinearEyeDepth(c15, _ZBufferParams);
                //c16 = LinearEyeDepth(c16, _ZBufferParams);
                //c17 = LinearEyeDepth(c17, _ZBufferParams);
                //c18 = LinearEyeDepth(c18, _ZBufferParams);
                //c19 = LinearEyeDepth(c19, _ZBufferParams);
                //c20 = LinearEyeDepth(c20, _ZBufferParams);
                //c21 = LinearEyeDepth(c21, _ZBufferParams);
                //c22 = LinearEyeDepth(c22, _ZBufferParams);
                //c23 = LinearEyeDepth(c23, _ZBufferParams);
                //c24 = LinearEyeDepth(c24, _ZBufferParams);

                //// Apply Sobel 5x5 edge detection filter
                //float Gx = 1.0 * (-c9 - c14 + c13 + c18) + 2.0 * (-c19 - c23 - c10 - c15 + c12 + c17 + c20 + c24) + 3.0 * (-c21 - c7 - c8 + c6 + c5 + c22) + 5.0 * (-c3 + c1);
                //float Gy = 1.0 * (-c14 - c18 + c9 + c13) + 2.0 * (-c15 - c17 - c23 - c24 + c19 + c20 + c10 + c12) + 3.0 * (-c16 - c8 - c5 + c6 + c7 + c11) + 5.0 * (-c4 + c2);
                //float scale = 0.1; // Blur scale, can be depth dependent
                //return float2(Gx * scale, Gy * scale);

                float3 normal0 = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, texCoord).xyz;
                float3 normal1 = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, texCoord + float2(offsetX, offsetY)).xyz;
                float3 normal2 = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, texCoord + float2(offsetX, -offsetY)).xyz;
                float3 normal3 = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, texCoord + float2(-offsetX, -offsetY)).xyz;
                float3 normal4 = SAMPLE_TEXTURE2D_X(_CameraNormalTexture, sampler_CameraNormalTexture, texCoord + float2(-offsetX, offsetY)).xyz;
                normal0 = normalize(normal0 * 2.0 - 1.0);
                normal1 = normalize(normal1 * 2.0 - 1.0);
                normal2 = normalize(normal2 * 2.0 - 1.0);
                normal3 = normalize(normal3 * 2.0 - 1.0);
                normal4 = normalize(normal4 * 2.0 - 1.0);

                float n1 = saturate(dot(normal1, normal3));
                float n2 = saturate(dot(normal2, normal4));
                n1 = exp(-pow(n1, 20.0f));
                n2 = exp(-pow(n2, 20.0f));
                float nor_scale = 1.0;
                float nor = (n1 * n2) * nor_scale;
                //============================================================

                float dep_diff_1 = abs(c5 - c7);
                float dep_diff_2 = abs(c6 - c8);
                float total_dep_diff = dep_diff_1 + dep_diff_2;
                float dep_dot_view = dot(view_dir, normal0);
                float dep_view_scale = pow(dep_dot_view, 2) + ((clamp(total_dep_diff - 50, 0, total_dep_diff) / 50));
                float dep_dis_scale = exp(-(clamp(depEye - 5, 0, depEye) / 100));// exp(-clamp(depEye - 10, 0, 100));
                //dep_view_scale = (dep_diff_2 + dep_diff_1) > 50 ? 1 : dep_view_scale;
                //dep_view_scale = (depEye) < 50 ? dep_view_scale : dep_view_scale;
                float dep = (1 - exp(-pow(total_dep_diff, 2.0f))) * (dep_view_scale * dep_dis_scale);// *dep_scale* dep_dis_scale;

                float thrdhold = 0.1;
                float final = dep * nor;// > thrdhold ? 1 : 0;

                //return float2(dep_dis_scale, dep_dis_scale);
                return float2(nor + dep, nor + dep);
                //return float2(dep, dep);
            }

            ENDHLSL
        }
    }
}
