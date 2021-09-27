using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class mouse_raycast_hit_ctrl : MonoBehaviour
{
    public Camera cam_main;

    public GameObject gobj_decal_pref;

    public GameObject gobj_last_decal;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        do_screen_decal();
        do_load_scene_additive();
    }

    void do_load_scene_additive()
    {
        if (Input.GetKeyUp(KeyCode.X))
        {
            SceneManager.LoadSceneAsync("test_scene", LoadSceneMode.Additive);
        }
    }

    void do_screen_decal()
    {
        if (Input.GetKeyUp(KeyCode.Z))
        {
            if (gobj_last_decal != null)
                Destroy(gobj_last_decal);

            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;

            int lm = LayerMask.GetMask("Default");
            if (Physics.Raycast(ray, out hit, 10000, lm))
            {

                //Vector3 nml = hit.normal.normalized;
                //Quaternion q = Quaternion.AngleAxis(1, nml);
                //Quaternion q1 = Quaternion.identity;


                Vector3 vr = new Vector3(0, 1, 0);
                Vector3 vforwardp = hit.normal.normalized;
                Quaternion q = Quaternion.FromToRotation(vr, vforwardp);
                //Quaternion q = Quaternion.identity;// Quaternion.LookRotation(hit.normal.normalized);
                gobj_last_decal = GameObject.Instantiate(gobj_decal_pref, hit.point, q);
                //tmp_decal.transform.LookAt(hit.point + hit.normal);


                //// hit.textureCoord是碰撞点的uv值，uv值是从0到1的，所以要乘以宽高才能得到具体坐标点
                //var x = (int)(hit.textureCoord.x * rt.width);
                //// 注意，uv坐标系和Graphics坐标系的y轴方向相反
                //var y = (int)(rt.height - hit.textureCoord.y * rt.height);
                //Draw(x, y);
            }
        }
    }
}
