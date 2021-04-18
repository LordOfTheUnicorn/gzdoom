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

#pragma once

#include "tarray.h"
#include "hw_ihwtexture.h"
#include "metal/system/ml_buffer.h"
#include "metal/renderer/ml_renderer.h"
#import  <Metal/Metal.h>



namespace MetalRenderer
{

struct MetalTexFilter
{
    MTLSamplerMinMagFilter minfilter;
    MTLSamplerMinMagFilter magfilter;
    bool mipmapping;
};

struct offsetSize
{
    int offset;
    int size;
};

class MTLHardwareTexture : public IHardwareTexture
{
private:
    bool forcenofilter;
    int mlTexID;
    int mlTextureBytes = 4;
    bool mipmapped = false;
    MTLBuffer *mBuffer;
    int mBufferSize = 0;
    NSString *nameTex;
    int GetDepthBuffer(int w, int h);

public:
    MTLHardwareTexture();
    ~MTLHardwareTexture();

    void Unbind(int texunit);
    void UnbindAll();

    void BindToFrameBuffer(int w, int h);
    uint32 FindFreeTexIndex();

  //  unsigned int Bind(int texunit, bool needmipmap);
  //  bool BindOrCreate(FTexture *tex, int texunit, int clampmode, int translation, int flags);

    void AllocateBuffer(int w, int h, int texelsize);
    uint8_t* MapBuffer();

    //bool CreateTexture(uint8_t texID, int w, int h, int pixelsize, int format, const void *pixels, OBJC_ID(MTLDevice) device);
    unsigned int CreateTexture(unsigned char * buffer, int w, int h, int texunit, bool mipmap, int translation, const char *name);
    unsigned int CreateWipeScreen(unsigned char * buffer, int w, int h, int texunit, bool mipmap, const char *name);
    unsigned int CreateTexture(unsigned char * buffer, int w, int h, int texunit, bool mipmap, const char *name);
    void ResetAll();
    void Reset(size_t id);
    bool BindOrCreate(FTexture *tex, int texunit, int clampmode, int translation, int flags);
    int Bind(int texunit, bool needmipmap);
 //   unsigned int GetTextureHandle(int translation);
};
}
