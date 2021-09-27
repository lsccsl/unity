using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class decal_ctr : MonoBehaviour
{
    public Material decal_material;
    public Camera cam_main;

    // Start is called before the first frame update
    void Start()
    {
        decal_material = this.GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        //Camera cam = cam_main;
        //if (cam)
        //{
        //    var mtx_view_inv = cam.worldToCameraMatrix.inverse;
        //    var mtx_proj_inv = cam.projectionMatrix.inverse;

        //    decal_material.SetMatrix("_mtx_view_inv", mtx_view_inv);
        //    decal_material.SetMatrix("_mtx_proj_inv", mtx_proj_inv);
        //}
    }

    private void OnRenderObject()
    {
        //Camera cam = Camera.current;
        //if (cam)
        //{
        //    var mtx_view_inv = cam.worldToCameraMatrix.inverse;
        //    var mtx_proj_inv = cam.projectionMatrix.inverse;

        //    decal_material.SetMatrix("_mtx_view_inv", mtx_view_inv);
        //    decal_material.SetMatrix("_mtx_proj_inv", mtx_proj_inv);
        //}
    }
}
