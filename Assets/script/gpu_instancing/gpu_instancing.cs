using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Mathematics;
using System.IO;

//此脚本挂在任意物体(空物体也可)
public class gpu_instancing : MonoBehaviour
{
    public int gobj_line_count_ = 20;
    public int gobj_count_perline_ = 20;

    public GameObject gobj_avatar_;
    public AnimationClip ani_clip_;
    public GameObject gobj_with_skinmeshrender_;

    //网格数据
    public Mesh instance_mesh_;
    //gpu instancing shader
    public Material mtrl_;

    ComputeBuffer cb_color_;
    List<float4> lst_color_;

    void Start()
    {
        cb_color_ = new ComputeBuffer(gobj_line_count_ * gobj_count_perline_, sizeof(float) * 4);
        lst_color_ = new List<float4>();
    }

    void Update()
    {
        //绘制gpu instancing 100个胶囊
        lst_color_.Clear();
        Vector3 pos = this.transform.position;
        var matrices = new Matrix4x4[gobj_line_count_ * gobj_count_perline_];
        for (int i = 0; i < gobj_line_count_; i++)
        {
            for (int j = 0; j < gobj_count_perline_; j++)
            {
                Vector3 tmppos = pos;
                tmppos.z = pos.z + i;
                tmppos.x = pos.x + j;

                var scale = new Vector3(0.5f, 0.5f, 0.5f);
                var matrix = Matrix4x4.TRS(tmppos, Quaternion.identity, scale);

                matrices[i * gobj_count_perline_ + j] = matrix;

                //每个实例颜色赋值
                lst_color_.Add(new float4((float)i / gobj_line_count_, (float)j / gobj_count_perline_, 0.0f, 1.0f));
            }
        }

        cb_color_.SetData(lst_color_);
        //每个实例的颜色数组
        mtrl_.SetBuffer(Shader.PropertyToID("_instancing_color"), cb_color_);
        if (mtrl_)
            Graphics.DrawMeshInstanced(instance_mesh_, 0, mtrl_, matrices, gobj_line_count_ * gobj_count_perline_);//materices是变换矩阵
    }

    [ContextMenu("export animation to texture")]
    void write_ske_animation_to_texture()
    {
        if (!ani_clip_ || !gobj_avatar_)
            return;

        SkinnedMeshRenderer skin_render = null;

        if (gobj_with_skinmeshrender_)
        {
            skin_render = gobj_with_skinmeshrender_.GetComponent<SkinnedMeshRenderer>();
        }
        else
        {
            for (int i = 0; i < gobj_avatar_.transform.childCount; i++)
            {
                var child_with_skinmeshrender = gobj_avatar_.transform.GetChild(i);
                gobj_with_skinmeshrender_ = child_with_skinmeshrender.gameObject;
                skin_render = gobj_with_skinmeshrender_.GetComponent<SkinnedMeshRenderer>();
                if (skin_render)
                    break;
            }
        }
        if (!skin_render)
            return;

        var bindposes = skin_render.sharedMesh.bindposes;
        var bones = skin_render.bones;

        int frame_count = (int)(ani_clip_.frameRate * ani_clip_.length);
        int max_bones = frame_count * bones.Length;
        int pixel_count = max_bones * 4;
        int tex_width = (int)Mathf.Ceil(Mathf.Sqrt(pixel_count)), tex_height = 1;
        while (tex_height < tex_width)
        {
            tex_height = tex_height << 1;
        }
        tex_width = tex_height;

        var tex = new Texture2D(tex_width, tex_height, TextureFormat.RGBAFloat, false);
        var tex_data = tex.GetRawTextureData<float>();

        int texel_index = 0;

        for (int j = 0; j < frame_count; j++)
        {
            ani_clip_.SampleAnimation(gobj_avatar_, (j / (float)frame_count) * ani_clip_.length);
            for (int bone_idx = 0; bone_idx < bones.Length; ++bone_idx)
            {
                var matrix = bones[bone_idx].localToWorldMatrix * bindposes[bone_idx];
                for (int row_idx = 0; row_idx < 4; ++row_idx)
                {
                    var row = matrix.GetRow(row_idx);

                    tex_data[texel_index++] = row.x;
                    tex_data[texel_index++] = row.y;
                    tex_data[texel_index++] = row.z;
                    tex_data[texel_index++] = row.w;
                }
            }
        }

        var file_name = Application.dataPath + "/ani.exr";
        File.WriteAllBytes(file_name, tex.EncodeToEXR(Texture2D.EXRFlags.CompressZIP));
    }
}
