namespace UnityEngine.Rendering.Universal
{
    /// <summary>
    /// �ɱ����Ⱦ����
    /// ����Ҫ�̳�ScriptableRendererFeature�����࣬
    /// ����ʵ��AddRenderPasses��Create����
    /// </summary>
    public class AdditionPostProcessRendererFeature : ScriptableRendererFeature
    {
        // ���ں����Shader 
        public Shader shader;
        // ����Pass
        AdditionPostProcessPass postPass;
        // ����Shader���ɵĲ���
        Material _Material = null;

        //���������������Ⱦ����ע��һ��������Ⱦͨ����
        //ÿ�����������һ����Ⱦ��ʱ�������ô˷�����
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // ���Shader�Ƿ����
            if (shader == null)
                return;

            // ��������
            if (_Material == null)
                _Material = CoreUtils.CreateEngineMaterial(shader);

            // ��ȡ��ǰ��Ⱦ�����Ŀ����ɫ��Ҳ����������
            var cameraColorTarget = renderer.cameraColorTarget;

            // ���õ��ú���Pass
            postPass.Setup(cameraColorTarget, _Material);

            // ��Ӹ�Pass����Ⱦ������
            renderer.EnqueuePass(postPass);
        }


        // �����ʼ��ʱ����øú���
        public override void Create()
        {
            postPass = new AdditionPostProcessPass();
            // ��Ⱦʱ�� = ͸��������Ⱦ��
            postPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        }
    }
}