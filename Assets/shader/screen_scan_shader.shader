Shader "lsc/screen_scan_shader"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _scan_brush("Texture", 2D) = "white" {}
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

            //sampler2D _CameraDepthTexture;
            float4x4 _mtx_view_inv;
            float4x4 _mtx_proj_inv;
            //float4x4 _mtx_clip_to_world;
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);


            //ɨ�����
            float4 _scan_color;
            float4 _scan_box_min;
            float4 _scan_box_max;
            float4x4 _scan_box_world_mtx;

            TEXTURE2D_X_FLOAT(_scan_brush);
            SAMPLER(sampler_LinearClamp);

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screen_space : TEXCOORD1;
            };

            float4 cal_world_pos_by_dep(float ndc_dep, float2 screen_space, out float4 view_pos)
            {
                // ȡ������������������
                float linearDepthZ = LinearEyeDepth(ndc_dep, _ZBufferParams);
                // ��Ļתndc
                float4 ndc_pos;
                ndc_pos.xy = screen_space * 2.0 - 1.0;
                ndc_pos.zw = float2(ndc_dep, 1);
                // ����������
                ndc_pos = ndc_pos * linearDepthZ;
                // ת�ɹ۲�����������
                view_pos = mul(_mtx_proj_inv, ndc_pos);
                float4 world_pos = mul(_mtx_view_inv, float4(view_pos.xyz, 1));

                return world_pos;
            }

            int is_in_box(float3 pos)
            {
                //todo : need option
                if (pos.x <= _scan_box_max.x &&
                    pos.y <= _scan_box_max.y &&
                    pos.z <= _scan_box_max.z &&
                    pos.x >= _scan_box_min.x &&
                    pos.y >= _scan_box_min.y &&
                    pos.z >= _scan_box_min.z
                    )
                    return 1;

                return 0;
            }

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;

                // ������Ļ�ռ�����(���������)
                o.screen_space = ComputeScreenPos(o.vertex);

                return o;
            }



            sampler2D _MainTex;

            float4 frag (v2f i) : SV_Target
            {
                float4 col = tex2D(_MainTex, i.uv);

                // ��ֵ�����Ļ����ȥ���������
                float2 screen_space = i.screen_space.xy / i.screen_space.w;
                // ȡ�����������
                float org_depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screen_space).x;
                // ������������
                float4 view_pos;
                float4 world_pos = cal_world_pos_by_dep(org_depth, screen_space, view_pos);

                //ת������Χ�е���תƽ�ƿռ�
                float4 box_space_pos = mul(_scan_box_world_mtx, float4(world_pos.xyz, 1));
                int in_box = is_in_box(box_space_pos.xyz);

                float2 brush_uv = float2(
                    abs(box_space_pos.x - _scan_box_min.x) / (_scan_box_max.x - _scan_box_min.x),
                    abs(box_space_pos.z - _scan_box_min.z) / (_scan_box_max.z - _scan_box_min.z)
                    );

                // �������в�������Ч��,����Ҳ������xz����������ɼ򵥵Ľ���Ч��
                float4 scan_brush = SAMPLE_TEXTURE2D_X(_scan_brush, sampler_LinearClamp, brush_uv).x;
                float scan_scale = scan_brush.r * brush_uv.x * brush_uv.y;

                col.xyz = _scan_color.xyz * in_box * scan_scale + col.xyz;


                //float tmp = world_pos.y;
                //col.xyz = float3(tmp, tmp, tmp);


                return col;
            }

            ENDHLSL
        }
    }
}
