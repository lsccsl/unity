Shader "lsc/vol_fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                float2 ndc_pos : TEXCOORD2;
            };

            sampler3D _tex3d_noise;
            sampler3D _tex3d_noise_detail;
            float _noise_tile;
            float _noise_detail_tile;

            sampler2D _tex_step_noise;
            float _step_noise_offset;

            sampler2D _tex_weather;
            sampler2D _tex_mask;

            float4 _clr_a;
            float4 _clr_b;
            float4 _phase_params;//散射参数
            float _light_absorption_toward_sun;
            float _light_absorption_through_cloud;
            float _color_offset1;
            float _color_offset2;
            float _darkness_threshold;


            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            float4x4 _mtx_view_inv;
            float4x4 _mtx_proj_inv;
            float3 _cam_pos;

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float3 _bbox_min;
            float3 _bbox_max;

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = vertexInput.positionCS;

                o.uv = v.uv;

                o.screen_pos = ComputeScreenPos(o.vertex);
                o.ndc_pos = (v.uv) * 2.0 - 1.0;

                return o;
            }

            // Henyey-Greenstein
            float hg(float a, float g)
            {
                float g2 = g * g;
                return (1 - g2) / (4 * 3.1415 * pow(1 + g2 - 2 * g * (a), 1.5));
            }
            float phase(float a)
            {
                float blend = .5;
                float hgBlend = hg(a, _phase_params.x) * (1 - blend) + hg(a, -_phase_params.y) * blend;
                return _phase_params.z + hgBlend * _phase_params.w;
            }

            //
            // from https://zhuanlan.zhihu.com/p/248406797
            // 分别计算射线到达三个平面的时间t,将所有t最小的组合为进入点,t最大的为出去点
            float2 ray_box_dst(float3 boundsMin, float3 boundsMax,
                float3 rayOrigin, float3 invRaydir)
            {
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z); //进入点
                float dstB = min(tmax.x, min(tmax.y, tmax.z)); //出去点

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float get_density_from_noise(float3 pos)
            {
return 0.1;

                float3 bbox_centre = (_bbox_max + _bbox_min) * 0.5;
                float3 bbox_size = _bbox_max - _bbox_min;

                float2 uv_weather = (bbox_size.xz * 0.5f + (pos.xz - bbox_centre.xz)) / float2(bbox_size.x, bbox_size.z);
                // tex2Dlod 可以提高帧率
                float weather = tex2Dlod(_tex_weather, float4(uv_weather,0,0)).r;
                float4 mask_noise = tex2Dlod(_tex_mask, float4(uv_weather, 0, 0)).r;
                const float container_edge_fade_dst = 300;
                float dst_from_edge_x = min(container_edge_fade_dst, min(pos.x - _bbox_min.x, _bbox_max.x - pos.x));
                float dst_from_edge_z = min(container_edge_fade_dst, min(pos.z - _bbox_min.z, _bbox_max.z - pos.z));
                float edge_weight = min(dst_from_edge_x, dst_from_edge_z) / container_edge_fade_dst;
                weather = edge_weight * weather;

                // _noise_tile/_noise_detail_tile取值太大会影响采样效率,降低帧率
                float4 uv_noise = float4(pos.xyz * _noise_tile, 0);// +mask_noise * 0.1;
                float4 uv_noise_detail = float4(pos.xyz * _noise_detail_tile, 0);

                float4 noise        = tex3Dlod(_tex3d_noise,        uv_noise);
                float4 noise_detail = tex3Dlod(_tex3d_noise_detail, uv_noise_detail);
                float final_density = noise_detail * noise * weather;
                return final_density;
                //return float3(final_density, final_density, final_density);

                //
                //float noise_final = pow(noise.x * noise_detail.x, 5);

                //return float3(noise_detail.x, noise_detail.x * weather, noise_detail.y) ;
                //return float3(noise_detail.x, noise_detail.x, noise_detail.x);
            }

            float3 light_march(float3 pos, float dstTravelled)
            {
                float3 light_dir = _MainLightPosition.xyz;

                float dstInsideBox = ray_box_dst(_bbox_min, _bbox_max, pos, 1 / light_dir).y;
                float stepSize = dstInsideBox / 8;
                float totalDensity = 0;
                
                UNITY_LOOP
                for (int step = 0; step < 8; step++)
                {
return _clr_a;
                    pos += light_dir * stepSize;
                    float noise_density = get_density_from_noise(pos);// 
                    totalDensity += max(0, noise_density);
                }
                float transmittance = exp(-totalDensity * _light_absorption_toward_sun);

                float3 cloudColor = lerp(_clr_a.xyz, _MainLightColor.xyz, saturate(transmittance * _color_offset1));
                cloudColor = lerp(_clr_b.xyz, cloudColor, saturate(pow(transmittance * _color_offset2, 3)));
                return (_darkness_threshold + transmittance * (1 - _darkness_threshold) * cloudColor);
            }

            float4 frag (v2f i) : SV_Target
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

                float3 world_view_dir = world_pos - _cam_pos;
                float world_dis = length(world_view_dir);

                float3 step_dir = normalize(world_view_dir);

                float2 rayToContainerInfo = ray_box_dst(_bbox_min, _bbox_max,
                    _cam_pos, 1 / step_dir);

                float exp_sum = 1;
                float3 lightEnergy = 0;
                float3 phase_val;
                float cos_angle = 0;
                {
                    const float step_count = 512;
                    float3 step_start = _cam_pos + rayToContainerInfo.x * step_dir;
                    float step_max = min(world_dis - rayToContainerInfo.x, rayToContainerInfo.y);
                    float step_len_uint = exp(3.5) * 0.06;// 0.5;// min(max(rayToContainerInfo.y / (step_count * 1), 0.1), 0.5);
                    float step_len = 0;

                    //沿着射线方向步进,判断是否在包围盒内
                    float3 step_pos;

                    float3 light_dir = _MainLightPosition.xyz;
                    cos_angle = dot(normalize(step_dir), normalize(light_dir));
                    phase_val = phase(cos_angle);

                    float step_noise = tex2D(_tex_step_noise, i.uv).r * _step_noise_offset;
                    step_len = step_noise;

                    UNITY_LOOP
                    for (int k = 0; k < step_count; k++)
                    {
                        if (step_len < step_max)
                        {
                            step_pos = step_start + step_len * step_dir;
                            //if (
                            //    (step_pos.x < _bbox_max.x && step_pos.x > _bbox_min.x) &&
                            //    (step_pos.y < _bbox_max.y && step_pos.y > _bbox_min.y) &&
                            //    (step_pos.z < _bbox_max.z && step_pos.z > _bbox_min.z)
                            //    )
							float noise_final = get_density_from_noise(step_pos);
							if (noise_final > 0)
							{
								float3 lightTransmittance = light_march(step_pos, rayToContainerInfo.y);
								lightEnergy += noise_final * step_len_uint * exp_sum * lightTransmittance * phase_val;
								//lightEnergy += density *      stepSize *   sumDensity * lightTransmittance * phaseVal;

								float exp_density = exp(-noise_final * step_len_uint * 0.3/*_light_absorption_through_cloud*/);
								exp_sum *= exp_density;

                                if (exp_sum < 0.01)
									break;
							}
                        }                        

                        step_len += step_len_uint;
                    }
                }
return abs(float4(step_dir, 1));
                // sample the texture
                float4 col = tex2D(_MainTex, i.uv);
                col.rgb = col.rgb * exp_sum + lightEnergy;
                return col;
            }
            ENDHLSL
        }
    }
}
