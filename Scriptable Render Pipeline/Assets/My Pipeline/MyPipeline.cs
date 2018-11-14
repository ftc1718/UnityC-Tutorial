using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

public class MyPipeline : RenderPipeline
{
    CullResults cull;
    CommandBuffer cameraBuffer = new CommandBuffer
    {
        name = "Render Camera"
    };

    public override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
	{
        base.Render(renderContext, cameras);
		foreach(var camera in cameras)
		{
            Render(renderContext, camera);
        }
    }
	void Render(ScriptableRenderContext context, Camera camera)
	{
        ScriptableCullingParameters cullingParameters;
        if(!CullResults.GetCullingParameters(camera, out cullingParameters))
		{
            return;
        }
        CullResults.Cull(ref cullingParameters, context, ref cull);
        context.SetupCameraProperties(camera);

        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.ClearRenderTarget(
			(clearFlags & CameraClearFlags.Depth) != 0,
			(clearFlags & CameraClearFlags.Color) != 0,
			camera.backgroundColor
			);
        cameraBuffer.BeginSample("Render Camera");
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        var drawSetting = new DrawRendererSettings(camera, new ShaderPassName("SRPDefaultUnlit"));
        drawSetting.sorting.flags = SortFlags.CommonOpaque;

        var filterSetting = new FilterRenderersSettings(true)
        {
            renderQueueRange = RenderQueueRange.opaque
		};
        context.DrawRenderers(cull.visibleRenderers, ref drawSetting, filterSetting);

        context.DrawSkybox(camera);

        drawSetting.sorting.flags = SortFlags.CommonTransparent;
        filterSetting.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cull.visibleRenderers, ref drawSetting, filterSetting);

        cameraBuffer.EndSample("Render Camera");
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        context.Submit();
    }
}
