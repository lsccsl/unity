using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenScanRenderPassFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material screen_scan_material = null;
        public RenderTargetIdentifier render_target_color;
        public RenderTargetHandle temp_render_target;

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
            //Debug.Log("Execute fog pass");

            if (!screen_scan_material)
                return;

            {
                Camera cam = renderingData.cameraData.camera;
                var mtx_view_inv = cam.worldToCameraMatrix.inverse;
                var mtx_proj_inv = cam.projectionMatrix.inverse;

                screen_scan_material.SetMatrix("_mtx_view_inv", mtx_view_inv);
                screen_scan_material.SetMatrix("_mtx_proj_inv", mtx_proj_inv);
            }

            // scan box
            {
                Vector4 box_min = new Vector4(-15, -1000, -50, 0);
                Vector4 box_max = new Vector4(15, 1000, 50, 0);
                screen_scan_material.SetVector("_scan_box_min", box_min);
                screen_scan_material.SetVector("_scan_box_max", box_max);
                screen_scan_material.SetVector("_scan_color", new Vector4(179.0f/255.0f, 224.0f / 255.0f, 230.0f / 255.0f, 1.0f));

                Matrix4x4 box_mtx = Matrix4x4.identity;
                //box_mtx = Matrix4x4.Rotate(Quaternion.Euler(0, 45 + 30 * Time.time, 0)) * Matrix4x4.Translate(new Vector3(-400, 0, -380));
                box_mtx = Matrix4x4.Rotate(Quaternion.Euler(0, 45 - 30 * Time.time, 0)) * Matrix4x4.Translate(new Vector3(-400, 0, -380));

                screen_scan_material.SetMatrix("_scan_box_world_mtx", box_mtx);
            }

            const string CommandBufferTag = "screen scan Pass";
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(temp_render_target.id, opaqueDesc);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(render_target_color, temp_render_target.Identifier(), screen_scan_material);
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
    public Material screen_scan_material = null;

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
        m_ScriptablePass.render_target_color = renderer.cameraColorTarget;
        m_ScriptablePass.screen_scan_material = screen_scan_material;

        renderer.EnqueuePass(m_ScriptablePass);
    }
}


