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
            float3 _NoiseOffset0, _NoiseOffset1;

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

            float hash(float3 p)//ֻ��������ĳ���,�������,����������
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float Noise(float3 x)//������������
            {
                float3 p = floor(x);
                float3 f = frac(x);
                f *= f * (3.0 - f - f);

                return lerp(lerp(lerp(hash(p + float3(0, 0, 0)),//�� 3x^2 - 2x^2��ֵ
                    hash(p + float3(1, 0, 0)), f.x),
                    lerp(hash(p + float3(0, 1, 0)),
                        hash(p + float3(1, 1, 0)), f.x), f.y),
                    lerp(lerp(hash(p + float3(0, 0, 1)),
                        hash(p + float3(1, 0, 1)), f.x),
                        lerp(hash(p + float3(0, 1, 1)),
                            hash(p + float3(1, 1, 1)), f.x), f.y), f.z);
            }

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

                //lsc ȡ���������,����Ӱ���ռ��z����
                float linearDepthZ = LinearEyeDepth(depth01, _ZBufferParams);

                //lsc ����ӳ��ת������׼�ռ�
                float4 screen_pos = float4(i.ndc_pos.x, i.ndc_pos.y, depth01, 1);
                //lsc ת���������
                screen_pos = screen_pos * linearDepthZ;
                //lsc ��ԭ��Ӱ���ռ�����
                view_pos = mul(_mtx_proj_inv, screen_pos);
                //lsc ����
                world_pos = mul(_mtx_view_inv, float4(view_pos.xyz, 1));

                float n = saturate(
                    Noise(world_pos.xyz * 0.005 * 60          + _Time.y * 3 * _NoiseOffset0) * 0.8 +
                    Noise(world_pos.xyz * 0.005 * 60 * 3.3333 + _Time.y * 3 * _NoiseOffset1) * 0.8 * 0.375
                );

                //�߶���˥��
                float h_percent = saturate(((world_pos.y - 20.0f) / 100.0f));
                float fac_h = exp(-h_percent * h_percent);

                //������˥��
                float dis = length(world_pos.xyz - _WorldSpaceCameraPos.xyz);
                float d_percent = 1 - ((dis - 50.0) / 100.0f);
                d_percent = saturate(d_percent);
                float fac_d = exp(-d_percent * d_percent);

                float4 final_col;
                final_col.w = 1.0;

                float4 col = tex2D(_MainTex, i.uv);

                //cloud  ��������Ӱ,����ƽ����ת
                float2 cloud_uv = (world_pos.xz - _cloud_offset_scale.xy) / _cloud_offset_scale.z;
                cloud_uv = cloud_uv * 2 - 1;
                cloud_uv = mul(_mtx_cloud_uv_rotate, float4(cloud_uv.x, 0, cloud_uv.y, 0)).xz;
                cloud_uv = cloud_uv * 0.5 + 0.5;
                float4 cloud = SAMPLE_TEXTURE2D_X(_CloudTex, sampler_LinearClamp, cloud_uv);// _CloudTex.Sample(sampler_LinearClamp, cloud_uv);
                float cloud_dis = length(world_pos.xz - (_cloud_offset_scale.xy + _cloud_offset_scale.z/2));
                cloud.r = cloud.r * pow(clamp(1 - cloud_dis / (_cloud_offset_scale.z * 0.6), 0, 1), 1);
                col.xyz = lerp(col.xyz, float3(0, 0, 0), cloud.r); //return col;

                float dmix = smoothstep(50, 100, dis);
                float dmix1 = smoothstep(0.2, 1, 1-exp(-dis/100));
                float fac_d_final = fac_d * (n * (1 - dmix) + dmix) * (dmix1);

                float hmix = smoothstep(100, 0, world_pos.y);
                float hmix1 = smoothstep(0.2, 1, exp(-world_pos.y / 200));
                float fac_h_final = fac_h * (n * (1 - hmix) + hmix) * (hmix1);

                //������Ч
                float fac_final = saturate(fac_d_final * fac_h_final);
                final_col.rgb = lerp(col.rgb, float3(0.2, 0.5, 0.8), fac_final);

//final_col.rgb = lerp(col.rgb, float3(0.7, 0.7, 0.7), saturate(fac_h * (n+1)));
//final_col.rgb = pow(lerp(pow(tex2D(_MainTex, i.uv).rgb, 0.454545), float3(0.2, 0.5, 0.8), saturate(fac_d * fac_h * (n + 1))), 2.2);

                return final_col;
            }
            ENDHLSL
        }
    }
}
