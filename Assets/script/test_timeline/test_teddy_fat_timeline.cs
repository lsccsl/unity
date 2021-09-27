using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class test_teddy_fat_timeline : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        //GameObject m_NormalObject;
        //{
        //    if (transform.childCount > 0)
        //    {
        //        for (var i = 0; i < gameObject.transform.childCount; i++)
        //        {
        //            if (!gameObject.transform.GetChild(i).gameObject.activeSelf) continue;

        //            m_NormalObject = gameObject.transform.GetChild(i).gameObject;
        //            break;
        //        }
        //    }
        //}
    }

    // Update is called once per frame
    void Update()
    {
    }

    public void test_signal()
    {
        Debug.Log(this.gameObject + " receive timeline signal " + gameObject.transform.position);
    }
}
