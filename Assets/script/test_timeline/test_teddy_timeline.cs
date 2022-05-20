using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Playables;

public class test_teddy_timeline : MonoBehaviour
{
    public PlayableDirector pd_;
    public GameObject gobj_rebind_;
    public GameObject gobj_rebind_source_;

    public Dictionary<string, PlayableBinding> dic_pd_bind_;
    // Start is called before the first frame update
    void Start()
    {
        dic_pd_bind_ = new Dictionary<string, PlayableBinding>();
        pd_ = this.gameObject.GetComponent<PlayableDirector>();

        foreach (var bind in pd_.playableAsset.outputs)
        {
            //Debug.Log(bind.streamName + ":[" + bind + "]");
            if (dic_pd_bind_.ContainsKey(bind.streamName))
                continue;
            dic_pd_bind_[bind.streamName] = bind;
        }

        gobj_rebind_.transform.position = gobj_rebind_source_.transform.position;
        gobj_rebind_.transform.rotation = gobj_rebind_source_.transform.rotation;
        pd_.SetGenericBinding(dic_pd_bind_["rebind_test"].sourceObject, gobj_rebind_);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
