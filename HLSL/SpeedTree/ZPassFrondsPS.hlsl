///////////////////////////////////////////////////////////////////////  
//  Leaf Shaders
//
//  *** INTERACTIVE DATA VISUALIZATION (IDV) CONFIDENTIAL AND PROPRIETARY INFORMATION ***
//
//  This software is supplied under the terms of a license agreement or
//  nondisclosure agreement with Interactive Data Visualization, Inc. and
//  may not be copied, disclosed, or exploited except in accordance with 
//  the terms of that agreement.
//
//      Copyright (c) 2003-2007 IDV, Inc.
//      All rights reserved in all media.
//
//      IDV, Inc.
//      Web: http://www.idvinc.com
//
//  *** Release Version 4.1 ***

#ifdef SHADER_TEST
#include "defines.cg"
#endif

#define IDV_OPENGL


//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
//	SFrondOutput
//-----------------------------------------------------------------------------

struct SFrondOutput
{
    float4 vPosition            : POSITION;
    float2 vDiffuseTexCoords    : TEXCOORD0;
};


//-----------------------------------------------------------------------------
//  FrondPS
//
//  Frond geometry pixel shader.  This shader can process up to two texture layers:
//      - diffuse composite leaf/frond map
//      - self-shadow map (greyscale composite map generated via SpeedTreeCAD)
//-----------------------------------------------------------------------------

float4
main(SFrondOutput In 
	, uniform sampler2D samCompositeDiffuseLeafMap : TEXUNIT0 
	) : COLOR
{
    // look up the diffuse layer
    float4 texDiffuse = tex2D(samCompositeDiffuseLeafMap, In.vDiffuseTexCoords.xy);
	float4 vColor = texDiffuse;
    return vColor;
}
