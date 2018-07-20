using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GPUInstancingTest : MonoBehaviour {

    public Transform prefab;

    public int instances = 5000;

    public float raius = 50f;

    // Use this for initialization
    void Start () {
        for (int i = 0; i < instances; i++)
        {
            Transform t = Instantiate(prefab);
            t.localPosition = Random.insideUnitSphere * raius;
            t.SetParent(transform);
        }

    }
}
