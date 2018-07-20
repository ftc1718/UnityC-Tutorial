using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUInstancingTest : MonoBehaviour {

    public Transform prefab;

    public int instances = 5000;

    public float raius = 50f;

    // Use this for initialization
    void Start () {
		MaterialPropertyBlock properties = new MaterialPropertyBlock();
        for (int i = 0; i < instances; i++)
        {
            Transform t = Instantiate(prefab);
            t.localPosition = Random.insideUnitSphere * raius;
            t.SetParent(transform);

            // t.GetComponent<MeshRenderer>().material.color =
            //     new Color(Random.value, Random.value, Random.value); // create new material
            properties.SetColor(
                "_Color", new Color(Random.value, Random.value, Random.value)
            );

            //support for both group lod and normal sphere
            MeshRenderer r = t.GetComponent<MeshRenderer>();
			if(r)
			{
                r.SetPropertyBlock(properties);
            }
			else
			{
                for (int ci = 0; ci < t.childCount; ci++)
				{
                    r = t.GetChild(ci).GetComponent<MeshRenderer>();
					if(r)
					{
                        r.SetPropertyBlock(properties);
                    }
                }
            }
        }
    }
}
