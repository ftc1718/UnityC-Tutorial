﻿using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Experimental.GlobalIllumination;
using LightType = UnityEngine.LightType;
using Conditional = System.Diagnostics.ConditionalAttribute;

public class MyPipeline : RenderPipeline
{
    RenderTexture shadowMap, cascadeShadowMap;
    CullResults cull;
    int shadowMapSize;
    int shadowTileCount;
    float shadowDistance;
    
    int shadowCascades;
    Vector3 shadowCascadesSplit;

    float renderScale;
    int msaaSamples;
    bool allowHDR;

    Texture2D ditherTexture;
    MyPostprocessingStack defaultStack;

    bool mainLightExist;

    CommandBuffer cameraBuffer = new CommandBuffer
    {
        name = "Render Camera"
    };

    CommandBuffer shadowBuffer = new CommandBuffer
    {
        name = "Render Shadows"
    };

    CommandBuffer postProcessingBuffer = new CommandBuffer
    {
        name = "Post-Processing"
    };

    Material errorMaterial;

    DrawRendererFlags drawFlags;

    const int maxVisibleLights = 16;

    const string shadowsSoftKeyword = "_SHADOWS_SOFT";
    const string shadowsHardKeyword = "_SHADOWS_HARD";
    const string cascadeShadowsHardKeyword = "_CASCADED_SHADOWS_HARD";
    const string cascadeShadowsSoftKeyword = "_CASCADED_SHADOWS_SOFT";
    const string shadowmaskKeyword = "_SHADOWMASK";
    const string distanceShadowmaskKeyword = "_DISTANCE_SHADOWMASK";
    const string subtractiveLightingKeyword = "_SUBTRACTIVE_LIGHTING";
    static int subtractiveShadowColorID = Shader.PropertyToID("_SubtractiveShadowColor");

    static int visibleLightColorID = Shader.PropertyToID("_VisibleLightColors");
    static int visibleLightDirectionOrPositionID = Shader.PropertyToID("_VisibleLightDirectionsOrPositions");
    static int visibleLightAttenuationsID = Shader.PropertyToID("_VisibleLightAttenuations");
    static int visibleLightSpotDirectionID = Shader.PropertyToID("_VisibleLightSpotDirections");
    static int lightIndicesOffsetAndCountID = Shader.PropertyToID("unity_LightIndicesOffsetAndCount");

    static int globalShadowDataID = Shader.PropertyToID("_GlobalShadowData");

    static int shadowMapID = Shader.PropertyToID("_ShadowMap");
    static int worldToShadowMatricesID = Shader.PropertyToID("_WorldToShadowMatrices");
    static int shadowBiasID = Shader.PropertyToID("_ShadowBias");
    static int shadowMapSizeID = Shader.PropertyToID("_ShadowMapSize");
    static int shadowDataID = Shader.PropertyToID("_ShadowData");
    static int cascadeShadowMapID = Shader.PropertyToID("_CascadeShadowMap");
    static int worldToShadowCascadeMatricesID = Shader.PropertyToID("_WorldToShadowCascadeMatrices");

    static int cascadeShadowMapSizeID = Shader.PropertyToID("_CascadeShadowMapSize");
    static int cascadeShadowStrengthID = Shader.PropertyToID("_CascadeShadowStrength");
    static int cascadeCullingSpheresID = Shader.PropertyToID("_CascadeCullingSpheres");

    static int visibleLightOcclusionMasksID = Shader.PropertyToID("_VisibleLightOcclusionMasks");

    static int cameraColorTextureID = Shader.PropertyToID("_CameraColorTexture");
    static int cameraDepthTextureID = Shader.PropertyToID("_CameraDepthTexture");

    Vector4[] visibleLightColors = new Vector4[maxVisibleLights];
    Vector4[] visibleLightDirectionsOrPositions = new Vector4[maxVisibleLights];
    Vector4[] visibleLightAttenuations = new Vector4[maxVisibleLights];
    Vector4[] visibleLightSpotDirections = new Vector4[maxVisibleLights];
    Vector4[] shadowData = new Vector4[maxVisibleLights];
    Matrix4x4[] worldToShadowMatrices = new Matrix4x4[maxVisibleLights];
    Matrix4x4[] worldToShadowCascadeMatrices = new Matrix4x4[5];
    Vector4[] cascadeCullingSpheres = new Vector4[4];

    Vector4[] visibleLightOcclusionMasks = new Vector4[maxVisibleLights];

    static Vector4[] occlusionMasks = {
        new Vector4(-1f, 0f, 0f, 0f),
        new Vector4(1f, 0f, 0f, 0f),
        new Vector4(0f, 1f, 0f, 0f),
        new Vector4(0f, 0f, 1f, 0f),
        new Vector4(0f, 0f, 0f, 1f)
    };

    Vector4 globalShadowData;

    static int ditherTextureID = Shader.PropertyToID("_DitherTexture");
    static int ditherTextureSTID = Shader.PropertyToID("_DitherTexture_ST");
    float ditherAnimationFrameDuration;
    Vector4[] ditherSTs;
    float lastDitherTime;
    int ditherSTIndex = -1;

    public MyPipeline(bool dynamicBatching, bool instancing, MyPostprocessingStack defaultStack, Texture2D ditherTexture, float ditherAnimationSpeed,
            int shadowMapSize, float shadowDistance, float shadowFadeRange, int shadowCascades, Vector3 shadowCascadesSplit, float renderScale, int msaaSamples, bool allowHDR)
    {
        GraphicsSettings.lightsUseLinearIntensity = true;
        //Debug.Log("GraphicsSettings.lightsUseLinearIntensity " + GraphicsSettings.lightsUseLinearIntensity);
        if (SystemInfo.usesReversedZBuffer)
        {
            worldToShadowCascadeMatrices[4].m33 = 1f;
        }
        if (dynamicBatching)
        {
            drawFlags = DrawRendererFlags.EnableDynamicBatching;
        }
        if (instancing)
        {
            drawFlags |= DrawRendererFlags.EnableInstancing;
        }
        this.defaultStack = defaultStack;
        this.shadowMapSize = shadowMapSize;
        this.shadowDistance = shadowDistance;
        globalShadowData.y = 1f / shadowFadeRange;
        this.shadowCascades = shadowCascades;
        this.shadowCascadesSplit = shadowCascadesSplit;
        this.ditherTexture = ditherTexture;
        this.renderScale = renderScale;
        QualitySettings.antiAliasing = msaaSamples;
        this.msaaSamples = Mathf.Max(QualitySettings.antiAliasing, 1);
        if (ditherAnimationSpeed > 0f && Application.isPlaying)
        {
            ConfigureDitherAnimation(ditherAnimationSpeed);
        }
        this.allowHDR = allowHDR;

#if UNITY_EDITOR
        Lightmapping.SetDelegate(lightmappingLightsDelegate);
#endif
    }

#if UNITY_EDITOR
    public override void Dispose()
    {
        base.Dispose();
        Lightmapping.ResetDelegate();
    }
#endif

    RenderTexture SetShadowRenderTarget()
    {
        RenderTexture texture = RenderTexture.GetTemporary(shadowMapSize, shadowMapSize, 16, RenderTextureFormat.Shadowmap);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Clamp;

        CoreUtils.SetRenderTarget(shadowBuffer, texture, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store, ClearFlag.Depth);
        return texture;
    }

    Vector2 ConfigureShadowTile(int tileIndex, int split, float tileSize)
    {
        Vector2 tileOffset;
        tileOffset.x = tileIndex % split;
        tileOffset.y = tileIndex / split;
        Rect tileViewport = new Rect(tileOffset.x * tileSize, tileOffset.y * tileSize, tileSize, tileSize);

        shadowBuffer.SetViewport(tileViewport);
        shadowBuffer.EnableScissorRect(new Rect(
            tileViewport.x + 4f, tileViewport.y + 4f,
            tileSize - 8f, tileSize - 8f
        ));

        return tileOffset;
    }

    void CalculateWorldToShadowMatrix(ref Matrix4x4 viewMatrix, ref Matrix4x4 projectionMatrix,
        out Matrix4x4 worldToShadowMatrix)
    {
        if (SystemInfo.usesReversedZBuffer)
        {
            projectionMatrix.m20 = -projectionMatrix.m20;
            projectionMatrix.m21 = -projectionMatrix.m21;
            projectionMatrix.m22 = -projectionMatrix.m22;
            projectionMatrix.m23 = -projectionMatrix.m23;
        }

        var scaleOffset = Matrix4x4.identity;
        scaleOffset.m00 = scaleOffset.m11 = scaleOffset.m22 = 0.5f;
        scaleOffset.m03 = scaleOffset.m13 = scaleOffset.m23 = 0.5f;

        worldToShadowMatrix = scaleOffset * (projectionMatrix * viewMatrix);
    }

    void RenderShadows(ScriptableRenderContext context)
    {
        int split;
        if (shadowTileCount <= 1)
        {
            split = 1;
        }
        else if (shadowTileCount <= 4)
        {
            split = 2;
        }
        else if (shadowTileCount <= 9)
        {
            split = 3;
        }
        else
        {
            split = 4;
        }

        float tileSize = shadowMapSize / split;
        float tileScale = 1f / split;
        globalShadowData.x = tileScale;
        shadowMap = SetShadowRenderTarget();
        shadowBuffer.BeginSample("Render Shadows");
        //shadowBuffer.SetGlobalVector(globalShadowDataID, new Vector4(tileScale, shadowDistance * shadowDistance));
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        int tileIndex = 0;
        bool hardShadows = false;
        bool softShadows = false;
        for (int i = mainLightExist ? 1 : 0; i < cull.visibleLights.Count; i++)
        {
            if (i == maxVisibleLights)
            {
                break;
            }
            if(shadowData[i].x < 0f)
            {
                continue;
            }

            Matrix4x4 viewMatrix, projectionMatrix;
            ShadowSplitData splitData;
            bool validShadow;

            if(shadowData[i].z > 0f)
            {
                validShadow = cull.ComputeDirectionalShadowMatricesAndCullingPrimitives(i, 0, 1, Vector3.right, (int)tileSize, cull.visibleLights[i].light.shadowNearPlane,
                    out viewMatrix, out projectionMatrix, out splitData);
            }
            else
            {
                validShadow = cull.ComputeSpotShadowMatricesAndCullingPrimitives(i, out viewMatrix, out projectionMatrix, out splitData);
            }
            if(!validShadow)
            {
                shadowData[i].x = 0f;
                continue;
            }


            Vector2 tileOffset = ConfigureShadowTile(tileIndex, split, tileSize);
            shadowData[i].z = tileOffset.x * tileScale;
            shadowData[i].w = tileOffset.y * tileScale;

            shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            shadowBuffer.SetGlobalFloat(shadowBiasID, cull.visibleLights[i].light.shadowBias);
            context.ExecuteCommandBuffer(shadowBuffer);
            shadowBuffer.Clear();

            DrawShadowsSettings shadowSettings = new DrawShadowsSettings(cull, i);
            shadowSettings.splitData.cullingSphere = splitData.cullingSphere; // spot light does not use cullingSphere
            context.DrawShadows(ref shadowSettings);

            CalculateWorldToShadowMatrix(ref viewMatrix, ref projectionMatrix, out worldToShadowMatrices[i]);

            tileIndex += 1;
            if(shadowData[i].y <= 0f)
            {
                hardShadows = true;
            }
            else
            {
                softShadows = true;
            }
        }
        //if (split > 1)
        //{
            shadowBuffer.DisableScissorRect();
        //}
        shadowBuffer.SetGlobalTexture(shadowMapID, shadowMap);
        shadowBuffer.SetGlobalMatrixArray(worldToShadowMatricesID, worldToShadowMatrices);

        shadowBuffer.SetGlobalVectorArray(shadowDataID, shadowData);
        float invShadowMapSize = 1f / shadowMapSize;
        shadowBuffer.SetGlobalVector(shadowMapSizeID, new Vector4(
                invShadowMapSize, invShadowMapSize, shadowMapSize, shadowMapSize));
        //if (cull.visibleLights[0].light.shadows == LightShadows.Soft)
        //{
        //    shadowBuffer.EnableShaderKeyword(shadowsSoftKeyword);
        //}
        //else
        //{
        //    shadowBuffer.DisableShaderKeyword(shadowsSoftKeyword);
        //}
        CoreUtils.SetKeyword(shadowBuffer, shadowsSoftKeyword, softShadows);
        CoreUtils.SetKeyword(shadowBuffer, shadowsHardKeyword, hardShadows);
        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();
    }

    void RendercascadeShadows(ScriptableRenderContext context)
    {
        float tileSize = shadowMapSize / 2;
        cascadeShadowMap = SetShadowRenderTarget();
        shadowBuffer.BeginSample("Render Shadows");
        //shadowBuffer.SetGlobalVector(globalShadowDataID, new Vector4(0f, shadowDistance * shadowDistance));
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();

        Light shadowLight = cull.visibleLights[0].light;
        shadowBuffer.SetGlobalFloat(shadowBiasID, shadowLight.shadowBias);

        DrawShadowsSettings shadowSettings = new DrawShadowsSettings(cull, 0);

        Matrix4x4 tileMatrix = Matrix4x4.identity;
        tileMatrix.m00 = tileMatrix.m11 = 0.5f;

        for(int i = 0; i < shadowCascades; i++)
        {
            Matrix4x4 viewMatrix, projectionMatrix;
            ShadowSplitData splitData;
            cull.ComputeDirectionalShadowMatricesAndCullingPrimitives(0, i, shadowCascades, shadowCascadesSplit, (int)tileSize, shadowLight.shadowNearPlane,
                    out viewMatrix, out projectionMatrix, out splitData);

            Vector2 tileOffset = ConfigureShadowTile(i, 2, tileSize);
            shadowBuffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            context.ExecuteCommandBuffer(shadowBuffer);
            shadowBuffer.Clear();

            cascadeCullingSpheres[i] = 
                shadowSettings.splitData.cullingSphere = splitData.cullingSphere;
            cascadeCullingSpheres[i].w *= splitData.cullingSphere.w;
            context.DrawShadows(ref shadowSettings);
            CalculateWorldToShadowMatrix(ref viewMatrix, ref projectionMatrix, out worldToShadowCascadeMatrices[i]);

            tileMatrix.m03 = tileOffset.x * 0.5f;
            tileMatrix.m13 = tileOffset.y * 0.5f;
            worldToShadowCascadeMatrices[i] =
                tileMatrix * worldToShadowCascadeMatrices[i];
        }

        shadowBuffer.DisableScissorRect();
        shadowBuffer.SetGlobalTexture(cascadeShadowMapID, cascadeShadowMap);
        shadowBuffer.SetGlobalVectorArray(cascadeCullingSpheresID, cascadeCullingSpheres);
        shadowBuffer.SetGlobalMatrixArray(worldToShadowCascadeMatricesID, worldToShadowCascadeMatrices);

        float invShadowMapSize = 1f / shadowMapSize;
        shadowBuffer.SetGlobalVector(cascadeShadowMapSizeID, new Vector4(
                invShadowMapSize, invShadowMapSize, shadowMapSize, shadowMapSize));
        shadowBuffer.SetGlobalFloat(cascadeShadowStrengthID, shadowLight.shadowStrength);

        bool hardShadow = shadowLight.shadows == LightShadows.Hard;
        CoreUtils.SetKeyword(shadowBuffer, cascadeShadowsHardKeyword, hardShadow);
        CoreUtils.SetKeyword(shadowBuffer, cascadeShadowsSoftKeyword, !hardShadow);

        shadowBuffer.EndSample("Render Shadows");
        context.ExecuteCommandBuffer(shadowBuffer);
        shadowBuffer.Clear();
    }

    void ConfigureDitherPattern(ScriptableRenderContext context)
    {
        if (ditherSTIndex < 0)
        {
            ditherSTIndex = 0;
            lastDitherTime = Time.unscaledTime;
            cameraBuffer.SetGlobalTexture(ditherTextureID, ditherTexture);
            cameraBuffer.SetGlobalVector(ditherTextureSTID, new Vector4(1f / 64f, 1f / 64f, 0f, 0f));
            context.ExecuteCommandBuffer(cameraBuffer);
            cameraBuffer.Clear();
        }
        else if (ditherAnimationFrameDuration > 0f)
        {
            float currentTime = Time.unscaledTime;
            if (currentTime - lastDitherTime >= ditherAnimationFrameDuration)
            {
                lastDitherTime = currentTime;
                ditherSTIndex = ditherSTIndex < 15 ? ditherSTIndex + 1 : 0;
                cameraBuffer.SetGlobalVector(
                    ditherTextureSTID, ditherSTs[ditherSTIndex]
                );
            }
            context.ExecuteCommandBuffer(cameraBuffer);
            cameraBuffer.Clear();
        }
    }

    void ConfigureDitherAnimation(float ditherAnimationSpeed)
    {
        ditherAnimationFrameDuration = 1f / ditherAnimationSpeed;
        ditherSTs = new Vector4[16];
        Random.State state = Random.state;
        Random.InitState(0);
        for (int i = 0; i < ditherSTs.Length; i++)
        {
            ditherSTs[i] = new Vector4(
                (i & 1) == 0 ? (1f / 64f) : (-1f / 64f),
                (i & 2) == 0 ? (1f / 64f) : (-1f / 64f),
                Random.value, Random.value
            );
        }
        Random.state = state;
    }

    public override void Render(ScriptableRenderContext renderContext, Camera[] cameras)
    {
        base.Render(renderContext, cameras);

        ConfigureDitherPattern(renderContext);

        foreach (var camera in cameras)
        {
            Render(renderContext, camera);
        }
    }
    void Render(ScriptableRenderContext context, Camera camera)
    {
        ScriptableCullingParameters cullingParameters;
        if (!CullResults.GetCullingParameters(camera, out cullingParameters))
        {
            return;
        }

        cullingParameters.shadowDistance = Mathf.Min(shadowDistance, camera.farClipPlane);

#if UNITY_EDITOR
        if (camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
#endif
        CullResults.Cull(ref cullingParameters, context, ref cull);

        if(cull.visibleLights.Count > 0)
        {
            ConfigureLights();
            if(mainLightExist)
            {
                RendercascadeShadows(context);
            }
            else
            {
                cameraBuffer.DisableShaderKeyword(cascadeShadowsHardKeyword);
                cameraBuffer.DisableShaderKeyword(cascadeShadowsSoftKeyword);
            }

            if(shadowTileCount > 0)
            {
                RenderShadows(context);
            }
            else
            {
                cameraBuffer.DisableShaderKeyword(shadowsSoftKeyword);
                cameraBuffer.DisableShaderKeyword(shadowsHardKeyword);
            }
        }
        else
        {
            cameraBuffer.SetGlobalVector(lightIndicesOffsetAndCountID, Vector4.zero);
            cameraBuffer.DisableShaderKeyword(cascadeShadowsHardKeyword);
            cameraBuffer.DisableShaderKeyword(cascadeShadowsSoftKeyword);
            cameraBuffer.DisableShaderKeyword(shadowsSoftKeyword);
            cameraBuffer.DisableShaderKeyword(shadowsHardKeyword);
        }


        context.SetupCameraProperties(camera);

        var myPipelineCamera = camera.GetComponent<MyPipelineCamera>();
        MyPostprocessingStack activeStack = myPipelineCamera ?
            myPipelineCamera.PostProcessingStack : defaultStack;

        bool scaledRendering = (renderScale < 1f || renderScale > 1f) && camera.cameraType == CameraType.Game;
        int renderWidth = camera.pixelWidth;
        int renderHeight = camera.pixelHeight;
        if (scaledRendering)
        {
            renderWidth = (int)(renderWidth * renderScale);
            renderHeight = (int)(renderHeight * renderScale);
        }

        int renderSamples = camera.allowMSAA ? msaaSamples : 1;
        bool renderToTexture = scaledRendering || renderSamples > 1 || activeStack;
        bool needsDepth = activeStack && activeStack.NeedsDepth;
        bool needsDirectDepth = needsDepth && renderSamples == 1;
        bool needsDepthOnlyPass = needsDepth && renderSamples > 1;

        RenderTextureFormat format = allowHDR && camera.allowHDR ?
            RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;

        if (renderToTexture)
        {
            cameraBuffer.GetTemporaryRT(cameraColorTextureID, renderWidth, renderHeight, needsDirectDepth ? 0 : 24, FilterMode.Bilinear,
                format, RenderTextureReadWrite.Default, renderSamples);
            if (needsDepth)
            {
                cameraBuffer.GetTemporaryRT(cameraDepthTextureID, renderWidth, renderHeight, 24, FilterMode.Point, RenderTextureFormat.Depth,
                    RenderTextureReadWrite.Linear, 1);
            }
            if(needsDirectDepth)
            {
                cameraBuffer.SetRenderTarget(cameraColorTextureID, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store,
                    cameraDepthTextureID, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }
            else
            {
                cameraBuffer.SetRenderTarget(cameraColorTextureID, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
            }
        }

        CameraClearFlags clearFlags = camera.clearFlags;
        cameraBuffer.ClearRenderTarget(
            (clearFlags & CameraClearFlags.Depth) != 0,
            (clearFlags & CameraClearFlags.Color) != 0,
            camera.backgroundColor
            //new Color(0, 0, 0, 0)
            );
        cameraBuffer.BeginSample("Render Camera");
        cameraBuffer.SetGlobalVectorArray(visibleLightColorID, visibleLightColors);
        cameraBuffer.SetGlobalVectorArray(visibleLightDirectionOrPositionID, visibleLightDirectionsOrPositions);
        cameraBuffer.SetGlobalVectorArray(visibleLightAttenuationsID, visibleLightAttenuations);
        cameraBuffer.SetGlobalVectorArray(visibleLightSpotDirectionID, visibleLightSpotDirections);
        cameraBuffer.SetGlobalVectorArray(visibleLightOcclusionMasksID, visibleLightOcclusionMasks);
        globalShadowData.z = 1f - cullingParameters.shadowDistance * globalShadowData.y;
        cameraBuffer.SetGlobalVector(globalShadowDataID, globalShadowData);
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        ShaderPassName passName = new ShaderPassName("SRPDefaultUnlit");
   
        var drawSettings = new DrawRendererSettings(camera, passName)
        {
            flags = drawFlags
        };

        if (cull.visibleLights.Count > 0)
        {
            drawSettings.rendererConfiguration = RendererConfiguration.PerObjectLightIndices8;
        }

        drawSettings.rendererConfiguration |=
            RendererConfiguration.PerObjectReflectionProbes |
            RendererConfiguration.PerObjectLightmaps |
            RendererConfiguration.PerObjectLightProbe |
            RendererConfiguration.PerObjectLightProbeProxyVolume |
            RendererConfiguration.PerObjectShadowMask |
            RendererConfiguration.PerObjectOcclusionProbe |
            RendererConfiguration.PerObjectOcclusionProbeProxyVolume;

        // drawSettings.flags = drawFlags;
        drawSettings.sorting.flags = SortFlags.CommonOpaque;

        var filterSettings = new FilterRenderersSettings(true)
        {
            renderQueueRange = RenderQueueRange.opaque
        };
        context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);

        context.DrawSkybox(camera);

        if (activeStack)
        {
            if (needsDepthOnlyPass)
            {
                var depthOnlyDrawSettings = new DrawRendererSettings(camera, new ShaderPassName("DepthOnly"))
                {
                    flags = drawFlags
                };
                depthOnlyDrawSettings.sorting.flags = SortFlags.CommonOpaque;
                cameraBuffer.SetRenderTarget(cameraDepthTextureID, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cameraBuffer.ClearRenderTarget(true, false, Color.clear);
                context.ExecuteCommandBuffer(cameraBuffer);
                cameraBuffer.Clear();
                context.DrawRenderers(cull.visibleRenderers, ref depthOnlyDrawSettings, filterSettings);
            }
            activeStack.RenderAfterOpaque(postProcessingBuffer, cameraColorTextureID, cameraDepthTextureID, renderWidth, renderHeight, renderSamples, format);
            context.ExecuteCommandBuffer(postProcessingBuffer);
            postProcessingBuffer.Clear();

            if (needsDirectDepth)
            {
                cameraBuffer.SetRenderTarget(cameraColorTextureID, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store,
                    cameraDepthTextureID, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store);
            }
            else
            {
                cameraBuffer.SetRenderTarget(cameraColorTextureID, RenderBufferLoadAction.Load, RenderBufferStoreAction.Store);
            }
            context.ExecuteCommandBuffer(cameraBuffer);
            cameraBuffer.Clear();
        }

        drawSettings.sorting.flags = SortFlags.CommonTransparent;
        filterSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);

        DrawDefaultPipeline(context, camera);

        if (renderToTexture)
        {
            if (activeStack)
            {
                activeStack.RenderAfterTransparent(postProcessingBuffer, cameraColorTextureID, cameraDepthTextureID, renderWidth, renderHeight, renderSamples, format);
                context.ExecuteCommandBuffer(postProcessingBuffer);
                postProcessingBuffer.Clear();
            }
            else
            {
                cameraBuffer.Blit(cameraColorTextureID, BuiltinRenderTextureType.CameraTarget);
            }
            cameraBuffer.ReleaseTemporaryRT(cameraColorTextureID);
            if (needsDepth)
            {
                cameraBuffer.ReleaseTemporaryRT(cameraDepthTextureID);
            }
        }

        cameraBuffer.EndSample("Render Camera");
        context.ExecuteCommandBuffer(cameraBuffer);
        cameraBuffer.Clear();

        context.Submit();

        if(shadowMap)
        {
            RenderTexture.ReleaseTemporary(shadowMap);
            shadowMap = null;
        }

        if(cascadeShadowMap)
        {
            RenderTexture.ReleaseTemporary(cascadeShadowMap);
            cascadeShadowMap = null;
        }
    }

    Vector4 ConfigureShadows(int lightIndex, Light shadowLight)
    {
        Vector4 shadow = Vector4.zero;
        Bounds shadowBounds;
        if (shadowLight.shadows != LightShadows.None &&
            cull.GetShadowCasterBounds(lightIndex, out shadowBounds))
        {
            shadowTileCount += 1;
            shadow.x = shadowLight.shadowStrength;
            shadow.y = shadowLight.shadows == LightShadows.Soft ? 1 : 0;
        }
        return shadow;
    }

    void ConfigureLights()
    {
        mainLightExist = false;
        bool shadowmaskExists = false;
        bool subtractiveLighting = false;
        shadowTileCount = 0;
        for (int i = 0; i < cull.visibleLights.Count; i++)
        {
            if (i == maxVisibleLights)
                break;
            VisibleLight light = cull.visibleLights[i];
            visibleLightColors[i] = light.finalColor;
            Vector4 attenuation = Vector4.zero;
            attenuation.w = 1f;
            Vector4 shadow = Vector4.zero;

            LightBakingOutput baking = light.light.bakingOutput;
            visibleLightOcclusionMasks[i] = occlusionMasks[baking.occlusionMaskChannel + 1];
            if (baking.lightmapBakeType == LightmapBakeType.Mixed)
            {
                shadowmaskExists |= baking.mixedLightingMode == MixedLightingMode.Shadowmask;
                if(baking.mixedLightingMode == MixedLightingMode.Subtractive)
                {
                    subtractiveLighting = true;
                    cameraBuffer.SetGlobalColor(subtractiveShadowColorID, RenderSettings.subtractiveShadowColor.linear);
                }
            }

            if (light.lightType == LightType.Directional)
            {
                Vector4 v = light.localToWorld.GetColumn(2);
                v.x = -v.x;
                v.y = -v.y;
                v.z = -v.z;
                visibleLightDirectionsOrPositions[i] = v;
                shadow = ConfigureShadows(i, light.light);
                shadow.z = 1f;
                if(i == 0 && shadow.x > 0f && shadowCascades > 0)
                {
                    mainLightExist = true;
                    shadowTileCount -= 1;
                }
            }
            else
            {
                visibleLightDirectionsOrPositions[i] = light.localToWorld.GetColumn(3);
                attenuation.x = 1f / Mathf.Max(light.range * light.range, 0.00001f);

                if (light.lightType == LightType.Spot)
                {
                    Vector4 v = light.localToWorld.GetColumn(2);
                    v.x = -v.x;
                    v.y = -v.y;
                    v.z = -v.z;
                    visibleLightSpotDirections[i] = v;

                    float outerAngle = Mathf.Deg2Rad * light.spotAngle;
                    float outerCos = Mathf.Cos(outerAngle * 0.5f);
                    float innerAngle = 2.0f * Mathf.Atan(Mathf.Tan(outerAngle * 0.5f) * (64.0f - 18.0f) / 64.0f);
                    float innerCos = Mathf.Cos(innerAngle * 0.5f);
                    float angleRange = Mathf.Max(0.001f, innerCos - outerCos);
                    attenuation.z = 1.0f / angleRange;
                    attenuation.w = -outerCos * attenuation.z;

                    Light shadowLight = light.light;
                    shadow = ConfigureShadows(i, shadowLight);
                }
                else
                {
                    visibleLightSpotDirections[i] = Vector4.one;
                }
            }
            visibleLightAttenuations[i] = attenuation;
            shadowData[i] = shadow;

        }

        bool useDistanceShadowmask = QualitySettings.shadowmaskMode == ShadowmaskMode.DistanceShadowmask;
        CoreUtils.SetKeyword(cameraBuffer, shadowmaskKeyword, shadowmaskExists && !useDistanceShadowmask);
        CoreUtils.SetKeyword(cameraBuffer, distanceShadowmaskKeyword, shadowmaskExists && useDistanceShadowmask);
        CoreUtils.SetKeyword(cameraBuffer, subtractiveLightingKeyword, subtractiveLighting);

        if (mainLightExist || cull.visibleLights.Count > maxVisibleLights)
        {
            int[] lightIndices = cull.GetLightIndexMap();
            if(mainLightExist)
            {
                lightIndices[0] = -1;
            }
            for (int i = maxVisibleLights; i < cull.visibleLights.Count; i++)
            {
                lightIndices[i] = -1;
            }
            cull.SetLightIndexMap(lightIndices);
        }
    }

    [Conditional("DEVELOPMENT_BUILD"), Conditional("UNITY_EDITOR")]
    void DrawDefaultPipeline(ScriptableRenderContext context, Camera camera)
    {
        if (errorMaterial == null)
        {
            Shader errorShader = Shader.Find("Hidden/InternalErrorShader");
            errorMaterial = new Material(errorShader)
            {
                hideFlags = HideFlags.HideAndDontSave
            };
        }

        var drawSettings = new DrawRendererSettings(camera, new ShaderPassName("ForwardBase"));
        drawSettings.SetShaderPassName(1, new ShaderPassName("PrepassBase"));
        drawSettings.SetShaderPassName(2, new ShaderPassName("Always"));
        drawSettings.SetShaderPassName(3, new ShaderPassName("Vertex"));
        drawSettings.SetShaderPassName(4, new ShaderPassName("VertexLMRGBM"));
        drawSettings.SetShaderPassName(5, new ShaderPassName("VertexLM"));
        drawSettings.SetOverrideMaterial(errorMaterial, 0);

        var filterSettings = new FilterRenderersSettings(true);

        context.DrawRenderers(cull.visibleRenderers, ref drawSettings, filterSettings);
    }

#if UNITY_EDITOR
    static Lightmapping.RequestLightsDelegate lightmappingLightsDelegate =
        (Light[] inputLights, NativeArray<LightDataGI> outputLights) =>
        {
            LightDataGI lightData = new LightDataGI();
            for (int i = 0; i < inputLights.Length; i++)
            {
                Light light = inputLights[i];
                switch (light.type)
                {
                    case LightType.Directional:
                        var directionalLight = new DirectionalLight();
                        LightmapperUtils.Extract(light, ref directionalLight);
                        lightData.Init(ref directionalLight);
                        break;
                    case LightType.Point:
                        var pointLight = new PointLight();
                        LightmapperUtils.Extract(light, ref pointLight);
                        lightData.Init(ref pointLight);
                        break;
                    case LightType.Spot:
                        var spotLight = new SpotLight();
                        LightmapperUtils.Extract(light, ref spotLight);
                        lightData.Init(ref spotLight);
                        break;
                    case LightType.Area:
                        var rectangleLight = new RectangleLight();
                        LightmapperUtils.Extract(light, ref rectangleLight);
                        lightData.Init(ref rectangleLight);
                        break;
                    default:
                        lightData.InitNoBake(light.GetInstanceID());
                        break;
                }
                lightData.falloff = FalloffType.InverseSquared;
                outputLights[i] = lightData;
            }
        };
#endif
}
