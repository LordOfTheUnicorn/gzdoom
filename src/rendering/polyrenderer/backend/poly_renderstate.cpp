
#include "polyrenderer/backend/poly_renderstate.h"
#include "polyrenderer/backend/poly_framebuffer.h"
#include "polyrenderer/backend/poly_hwtexture.h"
#include "templates.h"
#include "doomstat.h"
#include "r_data/colormaps.h"
#include "hwrenderer/scene/hw_skydome.h"
#include "hwrenderer/scene/hw_viewpointuniforms.h"
#include "hwrenderer/dynlights/hw_lightbuffer.h"
#include "hwrenderer/utility/hw_cvars.h"
#include "hwrenderer/utility/hw_clock.h"
#include "hwrenderer/data/flatvertices.h"
#include "hwrenderer/data/hw_viewpointbuffer.h"
#include "hwrenderer/data/shaderuniforms.h"
#include "swrenderer/r_swcolormaps.h"

static PolyDrawMode dtToDrawMode[] =
{
	PolyDrawMode::Triangles, // DT_Points
	PolyDrawMode::Triangles, // DT_Lines
	PolyDrawMode::Triangles, // DT_Triangles
	PolyDrawMode::TriangleFan, // DT_TriangleFan
	PolyDrawMode::TriangleStrip, // DT_TriangleStrip
};

PolyRenderState::PolyRenderState()
{
	mIdentityMatrix.loadIdentity();
	Reset();
}

void PolyRenderState::ClearScreen()
{
	screen->mViewpoints->Set2D(*this, SCREENWIDTH, SCREENHEIGHT);
	SetColor(0, 0, 0);
	Draw(DT_TriangleStrip, FFlatVertexBuffer::FULLSCREEN_INDEX, 4, true);
}

void PolyRenderState::Draw(int dt, int index, int count, bool apply)
{
	if (apply)
		Apply();

	PolyTriangleDrawer::Draw(GetPolyFrameBuffer()->GetDrawCommands(), index, count, dtToDrawMode[dt]);
}

void PolyRenderState::DrawIndexed(int dt, int index, int count, bool apply)
{
	if (apply)
		Apply();

	PolyTriangleDrawer::DrawIndexed(GetPolyFrameBuffer()->GetDrawCommands(), index, count, dtToDrawMode[dt]);
}

bool PolyRenderState::SetDepthClamp(bool on)
{
	bool lastValue = mDepthClamp;
	mDepthClamp = on;
	PolyTriangleDrawer::SetDepthClamp(GetPolyFrameBuffer()->GetDrawCommands(), on);
	return lastValue;
}

void PolyRenderState::SetDepthMask(bool on)
{
	PolyTriangleDrawer::SetDepthMask(GetPolyFrameBuffer()->GetDrawCommands(), on);
}

void PolyRenderState::SetDepthFunc(int func)
{
	PolyTriangleDrawer::SetDepthFunc(GetPolyFrameBuffer()->GetDrawCommands(), func);
}

void PolyRenderState::SetDepthRange(float min, float max)
{
	PolyTriangleDrawer::SetDepthRange(GetPolyFrameBuffer()->GetDrawCommands(), min, max);
}

void PolyRenderState::SetColorMask(bool r, bool g, bool b, bool a)
{
	PolyTriangleDrawer::SetColorMask(GetPolyFrameBuffer()->GetDrawCommands(), r, g, b, a);
}

void PolyRenderState::SetStencil(int offs, int op, int flags)
{
	PolyTriangleDrawer::SetStencil(GetPolyFrameBuffer()->GetDrawCommands(), screen->stencilValue + offs, op);

	if (flags != -1)
	{
		bool cmon = !(flags & SF_ColorMaskOff);
		SetColorMask(cmon, cmon, cmon, cmon); // don't write to the graphics buffer
		SetDepthMask(!(flags & SF_DepthMaskOff));
	}
}

void PolyRenderState::SetCulling(int mode)
{
	PolyTriangleDrawer::SetCulling(GetPolyFrameBuffer()->GetDrawCommands(), mode);
}

void PolyRenderState::EnableClipDistance(int num, bool state)
{
	PolyTriangleDrawer::EnableClipDistance(GetPolyFrameBuffer()->GetDrawCommands(), num, state);
}

void PolyRenderState::Clear(int targets)
{
	//if (targets & CT_Color)
	//	PolyTriangleDrawer::ClearColor(GetPolyFrameBuffer()->GetDrawCommands());
	if (targets & CT_Depth)
		PolyTriangleDrawer::ClearDepth(GetPolyFrameBuffer()->GetDrawCommands(), 0.0f);
	if (targets & CT_Stencil)
		PolyTriangleDrawer::ClearStencil(GetPolyFrameBuffer()->GetDrawCommands(), 0);
}

void PolyRenderState::EnableStencil(bool on)
{
	PolyTriangleDrawer::EnableStencil(GetPolyFrameBuffer()->GetDrawCommands(), on);
}

void PolyRenderState::SetScissor(int x, int y, int w, int h)
{
	auto fb = GetPolyFrameBuffer();
	if (w < 0)
	{
		x = 0;
		y = 0;
		w = fb->GetCanvas()->GetWidth();
		h = fb->GetCanvas()->GetHeight();
	}
	PolyTriangleDrawer::SetScissor(fb->GetDrawCommands(), x, fb->GetCanvas()->GetHeight() - y - h, w, h);
}

void PolyRenderState::SetViewport(int x, int y, int w, int h)
{
	auto fb = GetPolyFrameBuffer();
	if (w < 0)
	{
		x = 0;
		y = 0;
		w = fb->GetCanvas()->GetWidth();
		h = fb->GetCanvas()->GetHeight();
	}
	PolyTriangleDrawer::SetViewport(fb->GetDrawCommands(), x, fb->GetCanvas()->GetHeight() - y - h, w, h, fb->GetCanvas());
}

void PolyRenderState::EnableDepthTest(bool on)
{
	PolyTriangleDrawer::EnableDepthTest(GetPolyFrameBuffer()->GetDrawCommands(), on);
}

void PolyRenderState::EnableMultisampling(bool on)
{
}

void PolyRenderState::EnableLineSmooth(bool on)
{
}

void PolyRenderState::EnableDrawBuffers(int count)
{
}

void PolyRenderState::Apply()
{
	drawcalls.Clock();
	auto fb = GetPolyFrameBuffer();

	PolyPushConstants constants;

	int fogset = 0;
	if (mFogEnabled)
	{
		if (mFogEnabled == 2)
		{
			fogset = -3;	// 2D rendering with 'foggy' overlay.
		}
		else if ((GetFogColor() & 0xffffff) == 0)
		{
			fogset = gl_fogmode;
		}
		else
		{
			fogset = -gl_fogmode;
		}
	}

	int tempTM = TM_NORMAL;
	if (mMaterial.mMaterial && mMaterial.mMaterial->tex && mMaterial.mMaterial->tex->isHardwareCanvas())
		tempTM = TM_OPAQUE;

	constants.uFogEnabled = fogset;
	constants.uTextureMode = mTextureMode == TM_NORMAL && tempTM == TM_OPAQUE ? TM_OPAQUE : mTextureMode;
	constants.uLightDist = mLightParms[0];
	constants.uLightFactor = mLightParms[1];
	constants.uFogDensity = mLightParms[2];
	constants.uLightLevel = mLightParms[3];
	constants.uAlphaThreshold = mAlphaThreshold;
	constants.uClipSplit = { mClipSplit[0], mClipSplit[1] };
	constants.uLightIndex = mLightIndex;

	if (mVertexBuffer) PolyTriangleDrawer::SetVertexBuffer(fb->GetDrawCommands(), mVertexBuffer->Memory());
	if (mIndexBuffer) PolyTriangleDrawer::SetIndexBuffer(fb->GetDrawCommands(), mIndexBuffer->Memory());
	PolyTriangleDrawer::SetInputAssembly(fb->GetDrawCommands(), static_cast<PolyVertexBuffer*>(mVertexBuffer));
	PolyTriangleDrawer::SetRenderStyle(fb->GetDrawCommands(), mRenderStyle);
	PolyTriangleDrawer::PushStreamData(fb->GetDrawCommands(), mStreamData, constants);
	ApplyMatrices();
	ApplyMaterial();

	if (mBias.mChanged)
	{
		PolyTriangleDrawer::SetDepthBias(fb->GetDrawCommands(), mBias.mUnits, mBias.mFactor);
		mBias.mChanged = false;
	}

	drawcalls.Unclock();
}

void PolyRenderState::ApplyMaterial()
{
	if (mMaterial.mChanged && mMaterial.mMaterial)
	{
		auto base = static_cast<PolyHardwareTexture*>(mMaterial.mMaterial->GetLayer(0, mMaterial.mTranslation));
		if (base)
		{
			DCanvas *texcanvas = base->GetImage(mMaterial);
			PolyTriangleDrawer::SetTexture(GetPolyFrameBuffer()->GetDrawCommands(), texcanvas->GetPixels(), texcanvas->GetHeight(), texcanvas->GetWidth());
		}

		mMaterial.mChanged = false;
	}
}

template<typename T>
static void BufferedSet(bool &modified, T &dst, const T &src)
{
	if (dst == src)
		return;
	dst = src;
	modified = true;
}

static void BufferedSet(bool &modified, VSMatrix &dst, const VSMatrix &src)
{
	if (memcmp(dst.get(), src.get(), sizeof(FLOATTYPE) * 16) == 0)
		return;
	dst = src;
	modified = true;
}

void PolyRenderState::ApplyMatrices()
{
	bool modified = mFirstMatrixApply;
	if (mTextureMatrixEnabled)
	{
		BufferedSet(modified, mMatrices.TextureMatrix, mTextureMatrix);
	}
	else
	{
		BufferedSet(modified, mMatrices.TextureMatrix, mIdentityMatrix);
	}

	if (mModelMatrixEnabled)
	{
		BufferedSet(modified, mMatrices.ModelMatrix, mModelMatrix);
		if (modified)
			mMatrices.NormalModelMatrix.computeNormalMatrix(mModelMatrix);
	}
	else
	{
		BufferedSet(modified, mMatrices.ModelMatrix, mIdentityMatrix);
		BufferedSet(modified, mMatrices.NormalModelMatrix, mIdentityMatrix);
	}

	if (modified)
	{
		mFirstMatrixApply = false;
		PolyTriangleDrawer::PushMatrices(GetPolyFrameBuffer()->GetDrawCommands(), mMatrices.ModelMatrix, mMatrices.NormalModelMatrix, mMatrices.TextureMatrix);
	}
}

void PolyRenderState::Bind(PolyDataBuffer *buffer, uint32_t offset, uint32_t length)
{
	if (buffer->bindingpoint == VIEWPOINT_BINDINGPOINT)
	{
		mViewpointUniforms = reinterpret_cast<HWViewpointUniforms*>(static_cast<uint8_t*>(buffer->Memory()) + offset);
		PolyTriangleDrawer::SetViewpointUniforms(GetPolyFrameBuffer()->GetDrawCommands(), mViewpointUniforms);
	}
}