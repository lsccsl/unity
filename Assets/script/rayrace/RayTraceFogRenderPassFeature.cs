using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System;

public class RayTraceFogRenderPassFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material raytrace_material_;
        public RenderTargetIdentifier render_target_color_;
        public RenderTargetHandle temp_render_target_;
        public RenderTargetHandle temp_render_target_blur_;
        public int raytrace_count_ = 5;
        public float scale_ = 1.0f;


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
            if (!raytrace_material_)
                return;

            raytrace_material_.SetInt("_raytrace_step_count", raytrace_count_);
            raytrace_material_.SetFloat("_scale", scale_);

            {
                Camera cam = renderingData.cameraData.camera;
                var mtx_view_inv = cam.worldToCameraMatrix.inverse;
                var mtx_proj_inv = cam.projectionMatrix.inverse;

                raytrace_material_.SetMatrix("_mtx_view_inv", mtx_view_inv);
                raytrace_material_.SetMatrix("_mtx_proj_inv", mtx_proj_inv);

                raytrace_material_.SetVector("_pix_offset", new Vector4(1.0f/cam.pixelWidth, 1.0f / cam.pixelHeight, 0 ,0));
            }

            const string CommandBufferTag = "raytrace fog Pass";
            var cmd = CommandBufferPool.Get(CommandBufferTag);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(temp_render_target_.id, opaqueDesc);
            cmd.GetTemporaryRT(temp_render_target_blur_.id, opaqueDesc);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(render_target_color_, temp_render_target_.Identifier(), raytrace_material_, raytrace_material_.FindPass("depth_raytrace"));

            //{
            //    // blur raytrace result

            //    float max_offset_scale = 4;
            //    for (int i = 0; i < 8; i++)
            //    {
            //        //水平过滤
            //        float tmp_offset_scale = i;
            //        if (tmp_offset_scale > max_offset_scale)
            //            tmp_offset_scale = max_offset_scale;
            //        raytrace_material_.SetFloat("_offset_scale", 1);
            //        //raytrace_material_.SetVector("_blur_dir", new Vector4(1, 0, 0, 0));
            //        cmd.Blit(temp_render_target_.Identifier(), temp_render_target_blur_.Identifier(),
            //            raytrace_material_,
            //            raytrace_material_.FindPass("blur"));


            //        //垂直过滤
            //        raytrace_material_.SetFloat("_offset_scale", tmp_offset_scale);
            //        //raytrace_material_.SetVector("_blur_dir", new Vector4(0, 1, 0, 0));
            //        cmd.Blit(temp_render_target_blur_.Identifier(), temp_render_target_.Identifier(),
            //            raytrace_material_,
            //            raytrace_material_.FindPass("blur"));
            //    }
            //}

            //raytrace_material_.SetFloat("_offset_scale", 1);
            //cmd.Blit(temp_render_target_.Identifier(), temp_render_target_blur_.Identifier(),
            //    raytrace_material_,
            //    raytrace_material_.FindPass("blur"));

            cmd.Blit(render_target_color_, temp_render_target_blur_.Identifier(), raytrace_material_, raytrace_material_.FindPass("mix"));

            // 再从临时缓冲区存入主纹理
            cmd.Blit(temp_render_target_blur_.Identifier(), render_target_color_);
            // 执行命令缓冲区
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            // 释放命令缓存
            CommandBufferPool.Release(cmd);

            // 释放临时RT
            cmd.ReleaseTemporaryRT(temp_render_target_.id);
            cmd.ReleaseTemporaryRT(temp_render_target_blur_.id);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;
    public Material raytrace_material_;
    public int raytrace_count_ = 5;
    public float scale_ = 1.0f;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();


        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.render_target_color_ = renderer.cameraColorTarget;
        m_ScriptablePass.raytrace_material_ = raytrace_material_;
        m_ScriptablePass.raytrace_count_ = raytrace_count_;
        m_ScriptablePass.scale_ = scale_;

        m_ScriptablePass.temp_render_target_.Init("_raytrace_tex");
        m_ScriptablePass.temp_render_target_blur_.Init("_raytrace_tex_blur");


        renderer.EnqueuePass(m_ScriptablePass);
    }
}


