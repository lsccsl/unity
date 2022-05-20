using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class teddy_control : MonoBehaviour
{
    Animation ani_;
    // Start is called before the first frame update
    void Start()
    {
        ani_ = this.gameObject.GetComponent<Animation>();
        ani_.Play("Idle");
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
