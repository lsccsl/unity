using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using System;

[Serializable]
public class test_assert_data
{
    public int age;
    public string name;
}

[CreateAssetMenu(fileName = nameof(test_assert), menuName = nameof(test_assert))]
public class test_assert : ScriptableObject
{
    [SerializeField]
    public List<test_assert_data> lst_assert_data_;

    [SerializeField]
    public int[] id;

    [SerializeField]
    public string age = string.Empty;
    [SerializeField]
    public string name = string.Empty;

    public void Print()
    {
        if (lst_assert_data_ == null)
            lst_assert_data_ = new List<test_assert_data>();

        for (int i = 0, iMax = lst_assert_data_.Count; i < iMax; i++)
        {
            Debug.Log("Name:" + lst_assert_data_[i].name + "Age:" + lst_assert_data_[i].age);
        }
    }

    public void Save(string name, int age)
    {
        if (lst_assert_data_ == null)
            lst_assert_data_ = new List<test_assert_data>();

        lst_assert_data_.Add(new test_assert_data { name = name, age = age });
    }

    //private void OnGUI()
    //{
    //    if (GUILayout.Button("Print"))
    //    {
    //        var data = Resources.Load<test_assert>("test_assert");
    //        data.Print();
    //    }

    //    name = GUILayout.TextField(name);
    //    age = GUILayout.TextField(age);
    //    if (GUILayout.Button("Save"))
    //    {
    //        var data = Resources.Load<test_assert>("test_assert");
    //        data.Save(name, int.Parse(age));
    //    }
    //}
}
