//
//---------------------------------------------------------------------------
//
// Copyright(C) 2020-2021 Eugene Grigorchuk
// All rights reserved.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/
//
//--------------------------------------------------------------------------
//

#include "v_video.h"
#include "r_videoscale.h"

#include "files.h"
#include "v_video.h"
#include "m_png.h"
//#include "w_wad.h"
#include "doomstat.h"
#include "i_time.h"
#include "p_effect.h"
#include "d_player.h"
#include "a_dynlight.h"
#include "cmdlib.h"
#include "g_game.h"
#include "swrenderer/r_swscene.h"
#include "hw_clock.h"

#include "metal/system/ml_framebuffer.h"
#include "hw_cvars.h"
#include "metal/renderer/ml_renderer.h"
#include "metal/renderer/ml_RenderState.h"
#include "metal/renderer/ml_renderbuffers.h"
#include "metal/shaders/ml_shader.h"
#include "metal/textures/ml_hwtexture.h"
#include "hw_vrmodes.h"
#include "hwrenderer/data/flatvertices.h"
#include "hw_skydome.h"
//#include "hw_fakeflat.h"
#include "metal/textures/ml_samplers.h"
#include "hw_lightbuffer.h"
#include "hwrenderer/data/hw_viewpointbuffer.h"
#include "hwrenderer/postprocessing/hw_postprocess.h"
#include "hwrenderer/postprocessing/hw_postprocess_cvars.h"
#include "r_videoscale.h"
#include "models.h"
#include "metal/system/ml_buffer.h"
#include "metal/system/ml_framebuffer.h"

#import "Metal/Metal.h"
#include "filesystem.h"

EXTERN_CVAR(Int, screenblocks)
EXTERN_CVAR(Bool, cl_capfps)
MetalCocoaView* GetMacWindow();
extern bool NoInterpolateView;
extern bool vid_hdr_active;

void DoWriteSavePic(FileWriter *file, ESSType ssformat, uint8_t *scr, int width, int height, sector_t *viewsector, bool upsidedown);

namespace MetalRenderer
{

 MTLRenderer *MLRenderer;

//===========================================================================
//
// Renderer interface
//
//===========================================================================

//-----------------------------------------------------------------------------
//
// Initialize
//
//-----------------------------------------------------------------------------

MTLRenderer::MTLRenderer(MetalFrameBuffer *fb)
{
    framebuffer = fb;
    ml_RenderState = new MTLRenderState();
    if (ml_RenderState)
        ml_RenderState->InitialaziState();
    mHWViewpointUniforms = new mtlHWViewpointUniforms();
    loadDepthStencil = false;
    semaphore = dispatch_semaphore_create(3);
}

void MTLRenderer::Initialize(int width, int height, OBJC_ID(MTLDevice) device)
{
    mScreenBuffers = new MTLRenderBuffers();
    mSaveBuffers = new MTLRenderBuffers();
    mBuffers = mScreenBuffers;
    mPresentShader = new PresentUniforms();
    mPresent3dCheckerShader = new MTLShaderProgram();
    mPresent3dColumnShader = new MTLShaderProgram();
    mPresent3dRowShader = new MTLShaderProgram();
    //mShadowMapShader = new FShadowMapShader();

    mFBID = 0;
    mOldFBID = 0;

    mShaderManager = new MTLShaderManager();
    mSamplerManager = new MTLSamplerManager(device);
}

MTLRenderer::~MTLRenderer()
{
    FlushModels();
//    TexMan.FlushAll();
    if (mShaderManager != nullptr)
        delete mShaderManager;
    
    if (mSamplerManager != nullptr)
        delete mSamplerManager;
    
    if (swdrawer)
        delete swdrawer;
    
    if (mBuffers)
        delete mBuffers;
    
    if (mSaveBuffers)
        delete mSaveBuffers;
    
    if (mPresentShader)
        delete mPresentShader;
    
    if (mPresent3dCheckerShader)
        delete mPresent3dCheckerShader;
    
    if (mPresent3dColumnShader)
        delete mPresent3dColumnShader;
    
    if (mPresent3dRowShader)
        delete mPresent3dRowShader;
    
    //if (mShadowMapShader)
    //    delete mShadowMapShader;
    
    if (ml_RenderState)
        delete ml_RenderState;
}

//===========================================================================
//
//
//
//===========================================================================

void MTLRenderer::ResetSWScene()
{
    // force recreation of the SW scene drawer to ensure it gets a new set of resources.
    if (swdrawer != nullptr)
        delete swdrawer;
    
    swdrawer = nullptr;
}

//===========================================================================
//
//
//
//===========================================================================

bool MTLRenderer::StartOffscreen()
{
    //bool firstBind = (mFBID == 0);
    //if (mFBID == 0)
    //    glGenFramebuffers(1, &mFBID);
    //glGetIntegerv(GL_FRAMEBUFFER_BINDING, &mOldFBID);
    //glBindFramebuffer(GL_FRAMEBUFFER, mFBID);
    //if (firstBind)
    //    FGLDebug::LabelObject(GL_FRAMEBUFFER, mFBID, "OffscreenFB");
    //return true;
}

//===========================================================================
//
//
//
//===========================================================================

void MTLRenderer::EndOffscreen()
{
    //glBindFramebuffer(GL_FRAMEBUFFER, mOldFBID);
}

//===========================================================================
//
//
//
//===========================================================================

void MTLRenderer::UpdateShadowMap()
{
    //if (screen->mShadowMap.PerformUpdate())
    //{
    //    FGLDebug::PushGroup("ShadowMap");

    //    FGLPostProcessState savedState;

    //    static_cast<GLDataBuffer*>(screen->mShadowMap.mLightList)->BindBase();
    //    static_cast<GLDataBuffer*>(screen->mShadowMap.mNodesBuffer)->BindBase();
    //    static_cast<GLDataBuffer*>(screen->mShadowMap.mLinesBuffer)->BindBase();

    //    mBuffers->BindShadowMapFB();

    //    mShadowMapShader->Bind();
    //    mShadowMapShader->Uniforms->ShadowmapQuality = gl_shadowmap_quality;
    //    mShadowMapShader->Uniforms->NodesCount = screen->mShadowMap.NodesCount();
    //    mShadowMapShader->Uniforms.SetData();
    //    static_cast<GLDataBuffer*>(mShadowMapShader->Uniforms.GetBuffer())->BindBase();

    //    glViewport(0, 0, gl_shadowmap_quality, 1024);
    //    RenderScreenQuad();

    //    const auto &viewport = screen->mScreenViewport;
    //    glViewport(viewport.left, viewport.top, viewport.width, viewport.height);

    //    mBuffers->BindShadowMapTexture(16);
    //    FGLDebug::PopGroup();
    //    screen->mShadowMap.FinishUpdate();
    //}
}

//-----------------------------------------------------------------------------
//
// renders the view
//
//-----------------------------------------------------------------------------

//sector_t *MTLRenderer::RenderView(player_t* player)
//{
//    ml_RenderState->SetVertexBuffer(screen->mVertexData);
//    screen->mVertexData->Reset();
//    sector_t *retsec;
//
//    if (!V_IsHardwareRenderer())
//    {
//        if (swdrawer == nullptr)
//            swdrawer = new SWSceneDrawer;
//        
//        retsec = swdrawer->RenderView(player);
//    }
//    else
//    {
//        hw_ClearFakeFlat();
//
//        iter_dlightf = iter_dlight = draw_dlight = draw_dlightf = 0;
//
//        checkBenchActive();
//
//        // reset statistics counters
//        ResetProfilingData();
//
//        // Get this before everything else
//        if (cl_capfps || r_NoInterpolate) r_viewpoint.TicFrac = 1.;
//        else r_viewpoint.TicFrac = I_GetTimeFrac();
//
//        screen->mLights->Clear();
//        screen->mViewpoints->Clear();
//
//        // NoInterpolateView should have no bearing on camera textures, but needs to be preserved for the main view below.
//        bool saved_niv = NoInterpolateView;
//        NoInterpolateView = false;
//
//        // Shader start time does not need to be handled per level. Just use the one from the camera to render from.
//        ml_RenderState->CheckTimer(player->camera->Level->ShaderStartTime);
//        // prepare all camera textures that have been used in the last frame.
//        // This must be done for all levels, not just the primary one!
//        for (auto Level : AllLevels())
//        {
//            Level->canvasTextureInfo.UpdateAll([&](AActor *camera, FCanvasTexture *camtex, double fov)
//            {
//                RenderTextureView(camtex, camera, fov);
//            });
//        }
//        NoInterpolateView = saved_niv;
//
//
//        // now render the main view
//        float fovratio;
//        float ratio = r_viewwindow.WidescreenRatio;
//        if (r_viewwindow.WidescreenRatio >= 1.3f)
//        {
//            fovratio = 1.333333f;
//        }
//        else
//        {
//            fovratio = ratio;
//        }
//
//        retsec = RenderViewpoint(r_viewpoint, player->camera, NULL, r_viewpoint.FieldOfView.Degrees, ratio, fovratio, true, true);
//    }
//    All.Unclock();
//    return retsec;
//}

//===========================================================================
//
//
//
//===========================================================================

void MTLRenderer::BindToFrameBuffer(FTexture *mat)
{
//    auto BaseLayer = static_cast<IHardwareTexture*>(mat->GetLayer(0, 0));

    //if (BaseLayer == nullptr)
    //{
    //    // must create the hardware texture first
    //    BaseLayer->BindOrCreate(mat->sourcetex, 0, 0, 0, 0);
    //    FHardwareTexture::Unbind(0);
    //  //  gl_RenderState.ClearLastMaterial();
    //}
    //BaseLayer->BindToFrameBuffer(mat->GetWidth(), mat->GetHeight());
}

//===========================================================================
//
// Camera texture rendering
//
//===========================================================================

void MTLRenderer::RenderTextureView(FCanvasTexture* tex, std::function<void(IntRect&)> renderFunc)
{
    StartOffscreen();
    BindToFrameBuffer(tex);

    IntRect bounds;
    bounds.left = bounds.top = 0;
    bounds.width  = tex->GetWidth();
    bounds.height = tex->GetHeight();

    renderFunc(bounds);
    EndOffscreen();

    tex->SetUpdated(true);
    static_cast<MetalFrameBuffer*>(screen)->camtexcount++;
}

//===========================================================================
//
// Render the view to a savegame picture
//
//===========================================================================

void MTLRenderer::PostProcessScene(int fixedcm, float flash, const std::function<void()> &afterBloomDrawEndScene2D)
{
    int sceneWidth = mBuffers->GetSceneWidth();
    int sceneHeight = mBuffers->GetSceneHeight();

    MTLPPRenderState renderstate(mBuffers);

    hw_postprocess.Pass1(&renderstate, fixedcm, sceneWidth, sceneHeight);
    afterBloomDrawEndScene2D();
    hw_postprocess.Pass2(&renderstate, fixedcm, flash, sceneWidth, sceneHeight);
}

typedef struct
{
    float  InvGamma;
    float  Contrast;
    float  Brightness;
    float  Saturation;
    int    GrayFormula;
    int    WindowPositionParity;
    vector_float2 UVScale;
    vector_float2 UVOffset;
    float  ColorScale;
    int    HdrMode;
} secondUniforms;

void MTLRenderer::RenderScreenQuad()
{
    MTLRenderPassDescriptor*     passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];
    
    MetalCocoaView* const window = GetMacWindow();
    MLRenderer->mScreenBuffers->mDrawable = [window getDrawable];
    
    // Color render target
    passDesc.colorAttachments[0].texture = MLRenderer->mScreenBuffers->mDrawable.texture;
    passDesc.colorAttachments[0].loadAction  = MTLLoadActionClear;
    passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    //Depth render target
    passDesc.depthAttachment.texture = MLRenderer->mScreenBuffers->mSceneDepthStencilTex;
    passDesc.stencilAttachment.texture = MLRenderer->mScreenBuffers->mSceneDepthStencilTex;
    
    passDesc.depthAttachment.loadAction = MTLLoadActionClear;
    passDesc.depthAttachment.storeAction = MTLStoreActionDontCare;
    passDesc.depthAttachment.clearDepth = 1.f;
    
    passDesc.stencilAttachment.loadAction = MTLLoadActionClear;
    passDesc.stencilAttachment.storeAction = MTLStoreActionDontCare;
    passDesc.stencilAttachment.clearStencil = 0.f;
    
    passDesc.renderTargetWidth  = screen->mOutputLetterbox.width;
    passDesc.renderTargetHeight = screen->mOutputLetterbox.height;
    passDesc.defaultRasterSampleCount = 1;
    
    [MLRenderer->ml_RenderState->renderCommandEncoder endEncoding];
    
    MLRenderer->ml_RenderState->renderCommandEncoder = [MLRenderer->ml_RenderState->commandBuffer renderCommandEncoderWithDescriptor:passDesc];
    MLRenderer->ml_RenderState->renderCommandEncoder.label = @"RenderScreenQuad";
    [MLRenderer->ml_RenderState->renderCommandEncoder setFrontFacingWinding:MTLWindingClockwise];
    [MLRenderer->ml_RenderState->renderCommandEncoder setCullMode:MTLCullModeNone];
    
    [MLRenderer->ml_RenderState->renderCommandEncoder setViewport:(MTLViewport)
    {   0.0, 0.0,
        (double)screen->mOutputLetterbox.width, (double)screen->mOutputLetterbox.height,
        0.0, 1.0
    }];
    
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    pipelineDesc.colorAttachments[0].alphaBlendOperation         = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor      = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].blendingEnabled = YES;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor   = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.colorAttachments[0].rgbBlendOperation           = MTLBlendOperationAdd;
    // fix it
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    //########################ATTRIBUTE 0#########################
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;
    //#######################ATTRIBUTE 1#########################
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = 0;
    vertexDesc.attributes[1].bufferIndex = 1;
    //#######################LAYOUTS#############################
    vertexDesc.layouts[0].stride = sizeof(vector_float4);
    vertexDesc.layouts[0].stepRate = 1;
    vertexDesc.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    vertexDesc.layouts[1].stride = 8;
    vertexDesc.layouts[1].stepRate = 1;
    vertexDesc.layouts[1].stepFunction = MTLVertexStepFunctionPerVertex;
    //##############################################################
    NSError* error = nil;

    if (error && MLRenderer->ml_RenderState->defaultLibrary == nil)
        assert(true);
    OBJC_ID(MTLFunction) vs = [MLRenderer->ml_RenderState->defaultLibrary newFunctionWithName:@"vertexSecondRT"];
    OBJC_ID(MTLFunction) fs = [MLRenderer->ml_RenderState->defaultLibrary newFunctionWithName:@"fragmentSecondRT"];
    
    pipelineDesc.label = @"Second RT";
    pipelineDesc.vertexFunction = vs;
    pipelineDesc.fragmentFunction = fs;
    pipelineDesc.vertexDescriptor = vertexDesc;
    pipelineDesc.sampleCount = 1;
    
    if (MLRenderer->ml_RenderState->pipelineState[PIPELINE_STATE] == nil)
        MLRenderer->ml_RenderState->pipelineState[PIPELINE_STATE] = [device newRenderPipelineStateWithDescriptor:pipelineDesc  error:&error];
    if(error)
    {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    secondUniforms uniforms;
    uniforms.Brightness = mPresentShader->Brightness;
    uniforms.ColorScale = mPresentShader->ColorScale;
    uniforms.Contrast = mPresentShader->Contrast;
    uniforms.InvGamma = mPresentShader->InvGamma;
    uniforms.Saturation = mPresentShader->Saturation;
    uniforms.GrayFormula = mPresentShader->GrayFormula;
    uniforms.WindowPositionParity = mPresentShader->WindowPositionParity;
    uniforms.UVScale = {mPresentShader->Scale.X, mPresentShader->Scale.Y};
    uniforms.UVOffset = {mPresentShader->Offset.X, mPresentShader->Offset.Y};
    uniforms.HdrMode = mPresentShader->HdrMode;
    
    [MLRenderer->ml_RenderState->renderCommandEncoder setRenderPipelineState:MLRenderer->ml_RenderState->pipelineState[PIPELINE_STATE]];
    MLRenderer->mScreenBuffers->BindDitherTexture(1);
    
    vector_float4 inputPIP[4] =
    {
        vector_float4{-1, -1, 0, 1},
        vector_float4{-1, 1 , 0, 1},
        vector_float4{1 , -1, 0, 1},
        vector_float4{1 , 1 , 0, 1}
    };
    
    vector_float2 inputUV[4] =
    {
        vector_float2{0, 1},
        vector_float2{0, 0},
        vector_float2{1, 1},
        vector_float2{1, 0}
    };
    
    [MLRenderer->ml_RenderState->renderCommandEncoder setVertexBytes:&inputPIP length:sizeof(vector_float4)*4 atIndex:0];
    [MLRenderer->ml_RenderState->renderCommandEncoder setVertexBytes:&inputUV  length:sizeof(vector_float2)*4 atIndex:1];
    
    [MLRenderer->ml_RenderState->renderCommandEncoder setFragmentBytes:&uniforms length:sizeof(secondUniforms)      atIndex:0];
    [MLRenderer->ml_RenderState->renderCommandEncoder setFragmentTexture:MLRenderer->mScreenBuffers->mSceneFB       atIndex:0];
    [MLRenderer->ml_RenderState->renderCommandEncoder setFragmentTexture:MLRenderer->mScreenBuffers->mDitherTexture atIndex:1];
    
    int indexes[6] {0,1,2, 1,3,2};
    OBJC_ID(MTLBuffer) buff = [device newBufferWithBytes:indexes length:sizeof(int) * 6 options:MTLResourceStorageModeShared];
        
    [MLRenderer->ml_RenderState->renderCommandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                                                 indexCount:6
                                                                  indexType:MTLIndexTypeUInt32
                                                                indexBuffer:buff
                                                          indexBufferOffset:0];
    [buff release];
    
    [MLRenderer->ml_RenderState->commandBuffer addCompletedHandler:^(OBJC_ID(MTLCommandBuffer) buffer)
    {
        dispatch_semaphore_signal(MLRenderer->semaphore);
    }];
}

//void MetalFrameBuffer::CleanForRestart()
//{
//    if (MLRenderer)
//        MLRenderer->ResetSWScene();
//}

//===========================================================================
//
//
//
//===========================================================================

void MTLRenderer::BeginFrame()
{
    mScreenBuffers->Setup(screen->mScreenViewport.width, screen->mScreenViewport.height, screen->mSceneViewport.width, screen->mSceneViewport.height);
    mSaveBuffers->Setup(SAVEPICWIDTH, SAVEPICHEIGHT, SAVEPICWIDTH, SAVEPICHEIGHT);
}

}
