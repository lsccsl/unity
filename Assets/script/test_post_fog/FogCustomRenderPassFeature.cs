using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


public class FogCustomRenderPassFeature : ScriptableRendererFeature
{
    class FogCustomRenderPass : ScriptableRenderPass
    {
        public RenderTargetIdentifier render_target_color;
        public RenderTargetHandle temp_render_target;
        public Material custom_full_screen_material = null;
        public Texture tex_cloud = null;

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

            if (!custom_full_screen_material)
                return;

            {
                Camera cam = renderingData.cameraData.camera;
                var mtx_view_inv = cam.worldToCameraMatrix.inverse;
                var mtx_proj_inv = cam.projectionMatrix.inverse;

                custom_full_screen_material.SetMatrix("_mtx_view_inv", mtx_view_inv);
                custom_full_screen_material.SetMatrix("_mtx_proj_inv", mtx_proj_inv);
                custom_full_screen_material.SetTexture("_CloudTex", tex_cloud);

                Vector4 cloud_offset_scale = new Vector4(350, 350, 100, 1);
                custom_full_screen_material.SetVector("_cloud_offset_scale", cloud_offset_scale);
                Matrix4x4 cloud_rotate = Matrix4x4.identity;
                //cloud_rotate = Matrix4x4.Rotate(Quaternion.AxisAngle(new Vector3(0, 1, 0),9 * Time.time));
                cloud_rotate = Matrix4x4.Rotate(Quaternion.Euler(0, 30 * Time.time, 0));
                custom_full_screen_material.SetMatrix("_mtx_cloud_uv_rotate", cloud_rotate);

                var dir = Vector3.forward;
                var mtx_rotate = Matrix4x4.Rotate(Quaternion.Euler(0.0f, 30.0f, 0.0f));
                custom_full_screen_material.SetVector("_NoiseOffset0", dir);
                custom_full_screen_material.SetVector("_NoiseOffset1", mtx_rotate.MultiplyVector(dir));

                //Debug.Log("screen height:" + cam.scaledPixelHeight + " screen width:" + cam.scaledPixelWidth);

                //Debug.Log("pass Execute view_inv:" + mtx_view_inv + " proj_inv:" + mtx_proj_inv);
            }


            const string CommandBufferTag = "FogCustomRenderPassFeature Pass";
            var cmd = CommandBufferPool.Get(CommandBufferTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;
            cmd.GetTemporaryRT(temp_render_target.id, opaqueDesc);

            // 通过材质，将计算结果存入临时缓冲区
            cmd.Blit(render_target_color, temp_render_target.Identifier(), custom_full_screen_material);
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

    FogCustomRenderPass m_ScriptablePass;

    public Material custom_full_screen_material = null;
    public Texture tex_cloud = null;

    /// <inheritdoc/>
    public override void Create()
    {
        //Debug.Log("Create fog pass");

        m_ScriptablePass = new FogCustomRenderPass();

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        //m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.render_target_color = renderer.cameraColorTarget;
        m_ScriptablePass.custom_full_screen_material = custom_full_screen_material;
        m_ScriptablePass.tex_cloud = tex_cloud;

        renderer.EnqueuePass(m_ScriptablePass);
    }
}


