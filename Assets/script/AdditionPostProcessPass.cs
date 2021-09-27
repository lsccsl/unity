namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// ���ӵĺ���Pass
    /// </summary>
    public class AdditionPostProcessPass : ScriptableRenderPass
    {
        //��ǩ����������֡����������ʾ����������
        const string CommandBufferTag = "AdditionalPostProcessing Pass";

        // ���ں���Ĳ���
        public Material m_Material;

        // ���Բ������
        BrightnessSaturationContrast m_BrightnessSaturationContrast;

        // ��ɫ��Ⱦ��ʶ��
        RenderTargetIdentifier m_ColorAttachment;
        // ��ʱ����ȾĿ��
        RenderTargetHandle m_TemporaryColorTexture01;

        public AdditionPostProcessPass()
        {
            m_TemporaryColorTexture01.Init("_TemporaryColorTexture1");
        }

        // ������Ⱦ����
        public void Setup(RenderTargetIdentifier _ColorAttachment, Material Material)
        {
            this.m_ColorAttachment = _ColorAttachment;

            m_Material = Material;
        }

        /// <summary>
        /// URP���Զ����ø�ִ�з���
        /// </summary>
        /// <param name="context"></param>
        /// <param name="renderingData"></param>
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // ��Volume����л�ȡ���ж�ջ
            var stack = VolumeManager.instance.stack;
            // �Ӷ�ջ�в��Ҷ�Ӧ�����Բ������
            m_BrightnessSaturationContrast = stack.GetComponent<BrightnessSaturationContrast>();

            // ������������л�ȡһ������ǩ����Ⱦ����ñ�ǩ�������ں���֡�������м���
            var cmd = CommandBufferPool.Get(CommandBufferTag);

#if FUNC_RENDER
???
            // ������Ⱦ����
            Render(cmd, ref renderingData);
#else
            // VolumeComponent�Ƿ������ҷ�Scene��ͼ�����
            if (m_BrightnessSaturationContrast.IsActive() && !renderingData.cameraData.isSceneViewCamera)
            {
                // д�����
                m_Material.SetFloat("_Brightness", m_BrightnessSaturationContrast.brightness.value);
                m_Material.SetFloat("_Saturation", m_BrightnessSaturationContrast.saturation.value);
                m_Material.SetFloat("_Contrast", m_BrightnessSaturationContrast.contrast.value);

                // ��ȡĿ�������������Ϣ
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
                // ������Ȼ�����
                opaqueDesc.depthBufferBits = 0;
                // ͨ��Ŀ���������Ⱦ��Ϣ������ʱ������
                cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, opaqueDesc);

                // ͨ�����ʣ���������������ʱ������
                cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier(), m_Material);
                // �ٴ���ʱ����������������
                cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_ColorAttachment);
            }

#endif
            
            // ִ���������
            context.ExecuteCommandBuffer(cmd);
            // �ͷ������
            CommandBufferPool.Release(cmd);
            // �ͷ���ʱRT
            cmd.ReleaseTemporaryRT(m_TemporaryColorTexture01.id);
        }

#if FUNC_RENDER
        // ��Ⱦ
        void Render(CommandBuffer cmd, ref RenderingData renderingData)
        {
???
            // VolumeComponent�Ƿ������ҷ�Scene��ͼ�����
            if (m_BrightnessSaturationContrast.IsActive() && !renderingData.cameraData.isSceneViewCamera)
            {
                // д�����
                m_Material.SetFloat("_Brightness", m_BrightnessSaturationContrast.brightness.value);
                m_Material.SetFloat("_Saturation", m_BrightnessSaturationContrast.saturation.value);
                m_Material.SetFloat("_Contrast", m_BrightnessSaturationContrast.contrast.value);

                // ��ȡĿ�������������Ϣ
                RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
                // ������Ȼ�����
                opaqueDesc.depthBufferBits = 0;
                // ͨ��Ŀ���������Ⱦ��Ϣ������ʱ������
                cmd.GetTemporaryRT(m_TemporaryColorTexture01.id, opaqueDesc);

                // ͨ�����ʣ���������������ʱ������
                cmd.Blit(m_ColorAttachment, m_TemporaryColorTexture01.Identifier(), m_Material);
                // �ٴ���ʱ����������������
                cmd.Blit(m_TemporaryColorTexture01.Identifier(), m_ColorAttachment);
            }
    }
#endif
    }
}