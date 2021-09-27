Shader "lsc/softparticle_UnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags {
            "RenderType"="Opaque"

        }
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        //Blend SrcAlpha One

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            //#pragma multi_compile_fog
            //#pragma multi_compile_particles

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
                float4 screen_space : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            //sampler2D _CameraDepthTexture;
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);


            v2f vert (appdata v)
            {
                v2f o;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertex = TransformObjectToHClip(v.vertex);

                // lsc ������Ļ�ռ� xyΪ��Ļ����, zΪ����
                o.screen_space = ComputeScreenPos(o.vertex);
                // lsc ���´������������build-in��COMPUTE_EYEDEPTH�����,ȡ��ǰ����z
                float3 wpos = mul(GetObjectToWorldMatrix(), float4(v.vertex.xyz, 1.0f));
                float3 vpos = mul(GetWorldToViewMatrix(), float4(wpos.xyz, 1.0f));
                o.screen_space.z = -vpos.z;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 col = tex2D(_MainTex, i.uv);

                // lsc ȥ���������(ֻ����ƬԪ��ɫ����ȥ��,��֤���Բ�ֵ)
                float2 screen_pos = i.screen_space.xy / i.screen_space.w;

                // lsc ȡ���������
                float depth01 = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, screen_pos).r;
                // lsc ȡ�����������,����Ӱ���ռ��z����
                float linearDepthZ = LinearEyeDepth(depth01, _ZBufferParams);
                float linear01Depth = Linear01Depth(depth01, _ZBufferParams);

                // lsc ������Ȳ�ֵ,���㸽�ӵ�͸����alpha_scale
                float dep_diff = linearDepthZ - i.screen_space.z;
                float alpha_scale = pow(saturate((dep_diff - 1.0f) / 5.0f), 2);
                //float alpha_scale = 1 - exp(-pow(saturate((dep_diff - 2.0f) / 2.0f), 1));
                float final_alpha = alpha_scale *clamp(col.a - 0.1, 0, 1);

                col.a = final_alpha;
                return col;
            }
            ENDHLSL
        }
    }
}
