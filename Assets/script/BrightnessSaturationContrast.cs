using System;

// ͨ����Ⱦ���߳���
namespace UnityEngine.Rendering.Universal
{
    // ʵ������     ��ӵ�Volume����˵���
    [Serializable, VolumeComponentMenu("Addition-Post-processing/BrightnessSaturationContrast")]
    // �̳�VolumeComponent�����IPostProcessComponent�ӿڣ����Լ̳�Volume���
    public class BrightnessSaturationContrast : VolumeComponent, IPostProcessComponent
    {
        // �ڿ���µ�������Unity�������Բ�һ�������� Int �� ClampedIntParameter ȡ����
        public ClampedFloatParameter brightness = new ClampedFloatParameter(0f, 0, 3);
        public ClampedFloatParameter saturation = new ClampedFloatParameter(0f, 0, 3);
        public ClampedFloatParameter contrast = new ClampedFloatParameter(0f, 0, 3);
        // ʵ�ֽӿ�
        public bool IsActive()
        {
            return active;
        }

        public bool IsTileCompatible()
        {
            return false;
        }
    }
}