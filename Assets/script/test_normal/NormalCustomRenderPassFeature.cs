using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using System.Collections.Generic;

public class NormalCustomRenderPassFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Material normal_material;
        const string CommandBufferTag = "NormalCustomRenderPassFeature Pass";

        /*
         *  在shader里包含这些的将会被选中 shader graph自动生成的shader里会有这样的tag
         *  Name "DepthOnly"
         *  Tags
         *  {
         *    "LightMode" = "DepthOnly"
         *  }
         */
        ShaderTagId m_ShaderTagId = new ShaderTagId("DepthOnly");//

        private RenderTargetHandle depthAttachmentHandle { get; set; }
        internal RenderTextureDescriptor descriptor { get; private set; }
        //所有不透明的物体
        private FilteringSettings m_FilteringSettings = new FilteringSettings(RenderQueueRange.opaque, -1);

        public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle depthAttachmentHandle)
        {
            this.depthAttachmentHandle = depthAttachmentHandle;//声明shader中的变量
            baseDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            baseDescriptor.depthBufferBits = 32;
            descriptor = baseDescriptor;
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in a performant manner.
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }


        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            //取一个临时的render target
            cmd.GetTemporaryRT(depthAttachmentHandle.id, descriptor, FilterMode.Point);
            //设置render target并清除成黑色
            ConfigureTarget(depthAttachmentHandle.Identifier());
            ConfigureClear(ClearFlag.All, Color.black);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            GenNormal(context, ref renderingData);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (depthAttachmentHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(depthAttachmentHandle.id);
                depthAttachmentHandle = RenderTargetHandle.CameraTarget;
            }
        }
        // Cleanup any allocated resources that were created during the execution of this render pass.
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }


        public void GenNormal(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!normal_material)
                return;

            CommandBuffer cmd = CommandBufferPool.Get(CommandBufferTag);
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;

            List<ShaderTagId> shaderTagIdList = new List<ShaderTagId>();
            shaderTagIdList.Add(m_ShaderTagId);
            shaderTagIdList.Add(new ShaderTagId("bbb"));
            var drawSettings = CreateDrawingSettings(shaderTagIdList, ref renderingData, sortFlags);
            drawSettings.perObjectData = PerObjectData.None;

            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;
            if (cameraData.isStereoEnabled)
                context.StartMultiEye(camera);

            drawSettings.overrideMaterial = normal_material;

            context.DrawRenderers(renderingData.cullResults, ref drawSettings,
                ref m_FilteringSettings);

            cmd.SetGlobalTexture("_CameraNormalTexture", depthAttachmentHandle.id);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);


            //normal_material.GetTag();
        }
    }

    CustomRenderPass m_ScriptablePass;
    public Material normal_material;
    RenderTargetHandle depthNormalsTexture;

    /// <inheritdoc/>
    public override void Create()
    {
        depthNormalsTexture.Init("_CameraNormalTexture");

        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.normal_material = normal_material;

        // Configures where the render pass should be injected.
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderingData.cameraData.cameraTargetDescriptor, depthNormalsTexture);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


