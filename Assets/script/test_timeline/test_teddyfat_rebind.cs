using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class test_teddyfat_rebind : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public void teddyfat_receive_signal()
    {
        Debug.Log("~~~~~~test_teddyfat_rebind:teddyfat_receive_signal");


        var data = AssetDatabase.LoadAssetAtPath<test_assert>("Assets/Resources/test_assert.asset");
        //var data = Resources.Load<test_assert>("test_assert");
        data.Save("teddyfat", (int)Random.Range(1, 100));
        EditorUtility.SetDirty(data);
        AssetDatabase.SaveAssets();
    }
}
