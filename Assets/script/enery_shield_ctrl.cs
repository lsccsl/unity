using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class enery_shield_ctrl : MonoBehaviour
{
    public Material mtrl = null;
    public float scan_y = 0;
    // Start is called before the first frame update
    void Start()
    {
        mtrl = this.GetComponent<Renderer>().material;
        //mtrl = this.GetComponent<Material>();
    }

    // Update is called once per frame
    void Update()
    {
        scan_y += 10 * Time.deltaTime;

        if (scan_y > 2 * transform.transform.localScale.y)
            scan_y = 0;

        //scan_y = 15;

        float real_scan_y = (transform.position.y - transform.transform.localScale.y) + scan_y;
        if (mtrl)
            mtrl.SetFloat("_scan_y", real_scan_y);
    }
}
