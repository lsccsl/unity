using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System;


//// 通用渲染管线程序集
//namespace UnityEngine.Rendering.Universal
//{
//    [Serializable]
//    public sealed class MaterialParameter : VolumeParameter<Material>
//    {
//        public MaterialParameter(Material value, bool overrideState = false)
//            : base(value, overrideState) { }
//    }
//    [Serializable]
//    public sealed class TransFormParameter : VolumeParameter<Transform>
//    {
//        public TransFormParameter(Transform value, bool overrideState = false)
//            : base(value, overrideState) { }
//    }

//    // 实例化类     添加到Volume组件菜单中
//    [Serializable, VolumeComponentMenu("vol-fog-processing/volfog")]
//    // 继承VolumeComponent组件和IPostProcessComponent接口，用以继承Volume框架
//    public class VolfogContrast : VolumeComponent, IPostProcessComponent
//    {
//        public MaterialParameter vol_fog_material_;//会报错
//        public TransFormParameter vol_fog_pos_;//会报错

//        // 实现接口
//        public bool IsActive()
//        {
//            return active;
//        }

//        public bool IsTileCompatible()
//        {
//            return false;
//        }
//    }
//}

public class VolFogCustomRenderPassFeature : ScriptableRendererFeature
{
    public Material vol_fog_material_ = null;
    public Texture3D tex3d_noise_;
    public Texture3D tex3d_noise_detail_;
    public Texture2D tex_step_noise_;
    public Texture2D tex_weather_;
    public Texture2D tex_mask_;
    public Color clr_a_;
    public Color clr_b_;
    public Vector4 phase_params_;
    public float light_absorption_toward_sun_ = 0.16f;
    public float light_absorption_through_cloud_ = 0.3f;
    public float color_offset1_ = 0.86f;
    public float color_offset2_ = 0.82f;
    public float darkness_threshold_ = 0;
    public float noise_tile_ = 0.002f;
    public float noise_detail_tile_ = 0.022f;
    public float step_noise_offset_ = 2;



    class CustomRenderPass : ScriptableRenderPass
    {
        public RenderTargetIdentifier render_target_color;
        public Material vol_fog_material_;

        public RenderTargetHandle temp_render_target;
        public Texture3D tex3d_noise_;
        public Texture3D tex3d_noise_detail_;
        public Texture2D tex_step_noise_;
        public Texture2D tex_weather_;
        public Texture2D tex_mask_;
        public Color clr_a_;
        public Color clr_b_;
        public Vector4 phase_params_;
        public float light_absorption_toward_sun_ = 0.16f;
        public float light_absorption_through_cloud_ = 0.3f;
        public float color_offset1_ = 0.86f;
        public float color_offset2_ = 0.82f;
        public float darkness_threshold_ = 0;
        public float noise_tile_ = 0.002f;
        public float noise_detail_tile_ = 0.022f;
        public float step_noise_offset_ = 2;

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var gobj_global_volume = GameObject.Find("Global Volume");
            if (!gobj_global_volume)
            {
                Debug.Log("no global volume");
                return;
            }

            var gv_com = gobj_global_volume.GetComponent<global_volume>();
            if (!gv_com)
                return;
            if (!gv_com.vol_fog_pos_)
                return;

            if (!vol_fog_material_)
                return;

            // fog bbox
            {
                var v_min = gv_com.vol_fog_pos_.position - gv_com.vol_fog_pos_.localScale / 2;
                var v_max = gv_com.vol_fog_pos_.position + gv_com.vol_fog_pos_.localScale / 2;
                vol_fog_material_.SetVector("_bbox_min", v_min);
                vol_fog_material_.SetVector("_bbox_max", v_max);
            }

            // camera
            {
                Camera cam = renderingData.cameraData.camera;
                var mtx_view_inv = cam.worldToCameraMatrix.inverse;
                var mtx_proj_inv = cam.projectionMatrix.inverse;

                vol_fog_material_.SetMatrix("_mtx_view_inv", mtx_view_inv);
                vol_fog_material_.SetMatrix("_mtx_proj_inv", mtx_proj_inv);
                vol_fog_material_.SetVector("_cam_pos", cam.transform.position);
            }

            // noise
            {
                vol_fog_material_.SetTexture("_tex3d_noise", tex3d_noise_);
                vol_fog_material_.SetTexture("_tex3d_noise_detail", tex3d_noise_detail_);
                vol_fog_material_.SetTexture("_tex_step_noise", tex_step_noise_);
                vol_fog_material_.SetTexture("_tex_weather", tex_weather_);
                vol_fog_material_.SetTexture("_tex_mask", tex_mask_);

                vol_fog_material_.SetFloat("_noise_tile", noise_tile_);
                vol_fog_material_.SetFloat("_noise_detail_tile", noise_detail_tile_);
            }

            // other
            {
                vol_fog_material_.SetColor("_clr_a", clr_a_);
                vol_fog_material_.SetColor("_clr_b", clr_b_);
                vol_fog_material_.SetVector("_phase_params", phase_params_);
                vol_fog_material_.SetFloat("_light_absorption_toward_sun", light_absorption_toward_sun_);
                vol_fog_material_.SetFloat("_light_absorption_through_cloud", light_absorption_through_cloud_);
                vol_fog_material_.SetFloat("_color_offset1", color_offset1_);
                vol_fog_material_.SetFloat("_color_offset2", color_offset2_);
                vol_fog_material_.SetFloat("_darkness_threshold", darkness_threshold_);
                vol_fog_material_.SetFloat("_step_noise_offset", step_noise_offset_);
            }

            const string CommandBufferTag = "FogCustomRenderPassFeature Pass";
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(temp_render_target.id, opaqueDesc);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(render_target_color, temp_render_target.Identifier(), vol_fog_material_);
            // 再从临时缓冲区存入主纹理
            cmd.Blit(temp_render_target.Identifier(), render_target_color);

            // 执行命令缓冲区
            context.ExecuteCommandBuffer(cmd);
            // 释放命令缓存
            CommandBufferPool.Release(cmd);
            // 释放临时RT
            cmd.ReleaseTemporaryRT(temp_render_target.id);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.render_target_color = renderer.cameraColorTarget;
        m_ScriptablePass.vol_fog_material_ = vol_fog_material_;
        m_ScriptablePass.tex3d_noise_ = tex3d_noise_;
        m_ScriptablePass.tex3d_noise_detail_ = tex3d_noise_detail_;
        m_ScriptablePass.tex_step_noise_ = tex_step_noise_;
        m_ScriptablePass.tex_mask_ = tex_mask_;
        m_ScriptablePass.clr_a_ = clr_a_;
        m_ScriptablePass.clr_b_ = clr_b_;
        m_ScriptablePass.phase_params_ = phase_params_;
        m_ScriptablePass.light_absorption_toward_sun_ = light_absorption_toward_sun_;
        m_ScriptablePass.color_offset1_ = color_offset1_;
        m_ScriptablePass.color_offset2_ = color_offset2_;
        m_ScriptablePass.darkness_threshold_ = darkness_threshold_;
        m_ScriptablePass.light_absorption_through_cloud_ = light_absorption_through_cloud_;
        m_ScriptablePass.tex_weather_ = tex_weather_;
        m_ScriptablePass.noise_tile_ = noise_tile_;
        m_ScriptablePass.noise_detail_tile_ = noise_detail_tile_;
        m_ScriptablePass.step_noise_offset_ = step_noise_offset_;
        
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


