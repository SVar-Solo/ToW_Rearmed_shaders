///////////////////////////////////////////////////////////////////////  
//  Branch Shaders
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

#define  IDV_OPENGL 
 

///////////////////////////////////////////////////////////////////////  
//  Branch VS Ouput, PS Input
//
//  Cannot use more than four texture layers in order to compile down to ps_1_1

struct SBranchOutput
{
    float4  vPosition             : POSITION;
    float2  vDiffuseTexCoords     : TEXCOORD0;
};

///////////////////////////////////////////////////////////////////////  
//  BranchPS
//
//  Branch geometry pixel shader.  This shader can process up to four texture layers:
//      - diffuse bark map
//      - normal map
//      - detail map (lerped against the diffuse map using detail's alpha layer)
//      - self-shadow map (greyscale composite map generated via SpeedTreeCAD)

float4 main(
	SBranchOutput In
	,uniform sampler2D samBranchDiffuseMap : TEXUNIT0
	) : COLOR
{
    // look up the diffuse map layer
    float4 texDiffuse = tex2D(samBranchDiffuseMap, In.vDiffuseTexCoords.xy);
        	
    return texDiffuse;
}


