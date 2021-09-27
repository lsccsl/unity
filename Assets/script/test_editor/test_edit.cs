using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class test_edit : EditorWindow
{
    [MenuItem("lsc/UISource CreatorWindow")]
    static void on_lsc_click()
    {
        test_edit window = EditorWindow.GetWindow<test_edit>();
    }
    public string age = string.Empty;
    public string name = string.Empty;

    GameObject selectGameObject;
    List<GameObject> UIPrefabList;
    void OnGUI()
    {
        GUILayout.Label("选择需要生成界面源文件的对象");
        if (GUILayout.Button("生成界面源文件"))
        {
            if (this.selectGameObject != null)
            {
                //CreatUISourceUtil.CreatUISourceFile(selectGameObject);
            }
        }

        this.selectGameObject = GetSelectedPrefab();
        if (this.selectGameObject != null)
        {
            GUILayout.Label(this.selectGameObject.name);
        }

        if (GUILayout.Button("Print"))
        {
            var data = Resources.Load<test_assert>("test_assert");
            data.Print();
        }

        name = GUILayout.TextField(name);
        age = GUILayout.TextField(age);
        if (GUILayout.Button("Save"))
        {
            var data = Resources.Load<test_assert>("test_assert");
            data.Save(name, 1);
            AssetDatabase.SaveAssets();
        }
    }

    void OnSelectionChange()
    {
        Repaint();		//重绘界面
    }

    GameObject GetSelectedPrefab()
    {
        List<GameObject> gos = new List<GameObject>();

        if (Selection.activeGameObject != null)
        {
            return Selection.activeGameObject;
        }
        return null;
    }


}
