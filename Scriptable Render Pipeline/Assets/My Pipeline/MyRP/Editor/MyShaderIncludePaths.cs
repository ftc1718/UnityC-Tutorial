using System.IO;
using UnityEditor;
using UnityEngine;

static class MyShaderIncludePaths
{
	[ShaderIncludePath]
    static string[] GetPaths()
	{
        return new string[]
        {
            Path.GetFullPath("Assets/My Pipeline")
        };
    }
}