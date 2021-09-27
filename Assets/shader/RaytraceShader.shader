Shader "lsc/RaytraceShader"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _noise_tex("_noise_tex", 2D) = "white" {}
        _blue_noise_tex("_blue_noise_tex", 2D) = "white" {}        
        _raytrace_step_count("rayrace step count", Int) = 5
        _scale("scale", float) = 1.0

        _blur_offset("blur offset pix", Vector) = (0,1,2,3)
        _blur_weight("blur offset weight", Vector) = (0, 0.213, 0.17, 0.036)
        _blur_depth_falloff("depth falloff", Float) = 125
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "depth_raytrace"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
            };

            float4x4 _mtx_view_inv;
            float4x4 _mtx_proj_inv;
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            const float _z_near = 0.3f;

            v2f vert (appdata v)
            {
                v2f o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;
                o.screen_pos = ComputeScreenPos(o.vertex);

                o.uv = v.uv;

                return o;
            }

            sampler2D _MainTex;
            sampler2D _noise_tex;
            sampler2D _blue_noise_tex;
            int _raytrace_step_count;
            float _scale;

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


            //自定义直接指定取某个区间段级联阴影
            float4 anhei_TransformWorldToShadowCoord2(int idx, float3 positionWS)
            {
                half cascadeIndex = idx;

                float4 shadowCoord = mul(_MainLightWorldToShadow[cascadeIndex], float4(positionWS, 1.0));

                return float4(shadowCoord.xyz, cascadeIndex);
            }
            //常规计算当前像素点(世界坐标)处于哪个裁切球
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

            void get_next_disolution(int csm_idx, float3 wpos, out float shadow, out float mix_fact)
            {
                mix_fact = 0.0f;
                shadow = 0.0f;
                if (0 == csm_idx)
                {
                    //取第二个解析度
                    float4 shadow_coord = anhei_TransformWorldToShadowCoord2(1, wpos);
                    Light light_1 = GetMainLight(shadow_coord);
                    shadow = light_1.shadowAttenuation;

                    //离第一个裁切球心距离
                    float3 fromCenter0 = wpos - _CascadeShadowSplitSpheres0.xyz;
                    float3 sphere_dis = length(fromCenter0);
                    //第一个裁切球的半径
                    float sphere_rad = sqrt(_CascadeShadowSplitSphereRadii.x);

                    mix_fact = clamp((sphere_dis) / (sphere_rad / 1.0f), 0.0f, 1.0f);
                }
                if (1 == csm_idx)
                {
                    //取第三个解析度
                    float4 shadow_coord = anhei_TransformWorldToShadowCoord2(2, wpos);
                    Light light_1 = GetMainLight(shadow_coord);
                    shadow = light_1.shadowAttenuation;

                    //离第二个裁切球心距离
                    float3 fromCenter0 = wpos - _CascadeShadowSplitSpheres1.xyz;
                    float3 sphere_dis = length(fromCenter0);
                    //第二个裁切球的半径
                    float sphere_rad = sqrt(_CascadeShadowSplitSphereRadii.y);

                    mix_fact = clamp((sphere_dis) / (sphere_rad / 1.0f), 0.0f, 1.0f);
                }
                if (2 == csm_idx)
                {
                    //取第四个解析度
                    float4 shadow_coord = anhei_TransformWorldToShadowCoord2(3, wpos);
                    Light light_1 = GetMainLight(shadow_coord);
                    shadow = light_1.shadowAttenuation;

                    //离第三个裁切球心距离
                    float3 fromCenter0 = wpos - _CascadeShadowSplitSpheres2.xyz;
                    float3 sphere_dis = length(fromCenter0);
                    //第三个裁切球的半径
                    float sphere_rad = sqrt(_CascadeShadowSplitSphereRadii.z);

                    mix_fact = clamp((sphere_dis) / (sphere_rad / 1.0f), 0.0f, 1.0f);
                }
            }


            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);

                // 插值后的屏幕坐标去除齐次因子
                float2 screen_space = i.screen_pos.xy / i.screen_pos.w;
                // 取出非线性深度
                float org_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screen_space).x;
                // 计算世界坐标
                float4 view_pos;
                float4 world_pos = cal_world_pos_by_dep(org_depth, screen_space, view_pos);

                float3 cam_wpos = GetCameraPositionWS();
                float3 v_max = (world_pos - cam_wpos) ;
                float3 v_step = v_max / _raytrace_step_count;
                float3 v_dir = normalize(v_step);
                float max_dis = length(v_max);
                float step_size = max_dis / _raytrace_step_count;

                float2 interleavedPosition = (fmod(floor(i.vertex.xz), 8.0));
                float blue_noise = tex2D(_blue_noise_tex, interleavedPosition / 8.0 + float2(0.5 / 8.0, 0.5 / 8.0)).x;

                //float blue_noise = tex2D(_blue_noise_tex, world_pos.xz).x;

                int csm_idx = anhei_ComputeCascadeIndex(world_pos.xyz);

                float3 rt_start = cam_wpos + (blue_noise * v_step);
                float shadow_atten = 0;
                UNITY_LOOP
                for (int loop = 0; loop < _raytrace_step_count; loop++)
                {
                    float scale_noise = tex2D(_noise_tex, world_pos.xz).x;

                    csm_idx = anhei_ComputeCascadeIndex(rt_start);
                    float4 shadow_coord  = anhei_TransformWorldToShadowCoord2(csm_idx, rt_start);
                    //float4 shadow_coord = TransformWorldToShadowCoord(rt_start);
                    rt_start += v_step;

                    Light mainLight = GetMainLight(shadow_coord);//这样产生了级联阴影采样
                    float show_atte = mainLight.shadowAttenuation;//mainLight.shadowAttenuation; //
                    //shadow_atten += mainLight.shadowAttenuation;

                    float shadow;
                    float mix_fact;
                    get_next_disolution(csm_idx, rt_start, shadow, mix_fact);

                    show_atte = mainLight.shadowAttenuation * (1 - mix_fact) + shadow * mix_fact;

                    shadow_atten += 0.15 * step_size * show_atte * scale_noise;//pow(1-(1-mainLight.shadowAttenuation) * scale_noise, 1);
                }

                shadow_atten = clamp((shadow_atten / _raytrace_step_count) * _scale, 0.0f, _scale);

                col.rgb = col.rgb * shadow_atten;

float tmp =  shadow_atten;
col.rgb = float3(tmp, tmp, tmp);
                return col;
            }
            ENDHLSL
        }

        Pass
        {
            Name "blur"

            HLSLPROGRAM

            #pragma vertex blue_vert
            #pragma fragment blue_frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
            };

            sampler2D _MainTex;
            sampler2D _raytrace_tex;
            sampler2D _raytrace_tex_blur;
            float4 _blur_offset;
            float4 _pix_offset;
            float4 _blur_weight;
            float4 _blur_dir;
            float _offset_scale;

            v2f blue_vert(appdata v)
            {
                v2f o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;
                o.screen_pos = ComputeScreenPos(o.vertex);

                o.uv = v.uv;

                return o;
            }


            float4 blue_frag(v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv); //return col;

                float4 col_tmp;
                float2 tmp_uv;
                //UNITY_UNROLL
                //for (int loop = 1; loop < 4; loop++)
                {
                    tmp_uv = i.uv + float2(_pix_offset.x, 0) * _offset_scale; //i.uv + _blur_dir * _pix_offset.xy * _blur_offset[loop];                    
                    col += tex2D(_MainTex, tmp_uv);

                    tmp_uv = i.uv - float2(_pix_offset.x, 0) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);

                    tmp_uv = i.uv + float2(0,  _pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);

                    tmp_uv = i.uv - float2(0, _pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);

                    tmp_uv = i.uv + float2(_pix_offset.x,  _pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);
                    tmp_uv = i.uv + float2(_pix_offset.x, -_pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);

                    tmp_uv = i.uv + float2(-_pix_offset.x, _pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);
                    tmp_uv = i.uv + float2(-_pix_offset.x, -_pix_offset.y) * _offset_scale;
                    col += tex2D(_MainTex, tmp_uv);
                }

                return col / 9.0f;
            }

            ENDHLSL
        }

        Pass
        {
            Name "mix"
            HLSLPROGRAM

            #pragma vertex mix_vert
            #pragma fragment mix_frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            sampler2D _MainTex;
            sampler2D _raytrace_tex_blur;
            sampler2D _raytrace_tex;


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
            };

            v2f mix_vert(appdata v)
            {
                v2f o;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;
                o.screen_pos = ComputeScreenPos(o.vertex);

                o.uv = v.uv;

                return o;
            }

            float4 mix_frag(v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);
                float4 col_vol = tex2D(_raytrace_tex, i.uv); return col_vol;

                return col * col_vol;
            }

            ENDHLSL
        }

    }
}
