using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class NormalShowRenderPassFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material normal_show_material;

        public RenderTargetHandle temp_render_target;
        public RenderTargetIdentifier render_target_color;

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
            if (!normal_show_material)
                return;

            // ×ª»»¾ØÕó°ó¶¨
            {
                Camera cam = renderingData.cameraData.camera;
                var mtx_view_inv = cam.worldToCameraMatrix.inverse;
                var mtx_proj_inv = cam.projectionMatrix.inverse;

                normal_show_material.SetMatrix("_mtx_view_inv", mtx_view_inv);
                normal_show_material.SetMatrix("_mtx_proj_inv", mtx_proj_inv);

                //Debug.Log("screen height:" + cam.scaledPixelHeight + " screen width:" + cam.scaledPixelWidth);

                //Debug.Log("pass Execute view_inv:" + mtx_view_inv + " proj_inv:" + mtx_proj_inv);
            }

            // ÎÆÀíÆ«ÒÆ°ó¶¨
            Vector4 offset_pixel = new Vector4(1.0f / (float)renderingData.cameraData.cameraTargetDescriptor.width,
                1.0f / (float)renderingData.cameraData.cameraTargetDescriptor.height, 0, 0);
            normal_show_material.SetVector("_offset_pixel", offset_pixel);

            const string CommandBufferTag = "scene normal show Pass";
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(temp_render_target.id, opaqueDesc);

            cmd.Blit(render_target_color, temp_render_target.Identifier(), normal_show_material);
            cmd.Blit(temp_render_target.Identifier(), render_target_color);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
            cmd.ReleaseTemporaryRT(temp_render_target.id);
        }

        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    CustomRenderPass m_ScriptablePass;
    public Material normal_show_material;

    /// <inheritdoc/>
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.normal_show_material = normal_show_material;

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.render_target_color = renderer.cameraColorTarget;
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


