// D3D11 port of SpeedTree/ZPassBranchesPS.hlsl. Generated from the legacy HLSL source; see README.md.
#include "../SpeedTreeDefaults.hlsli"
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
#include "../SpeedTreeDefaults.hlsli"
#endif

#define  IDV_OPENGL 
 

///////////////////////////////////////////////////////////////////////  
//  Branch VS Ouput, PS Input
//
//  Cannot use more than four texture layers in order to compile down to ps_1_1

struct SBranchOutput
{
    float4  vPosition             : SV_Position;
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



Texture2D samBranchDiffuseMap : register(t0);
SamplerState samBranchDiffuseMap_Sampler : register(s0);

float4 main(
	SBranchOutput In
	) : SV_Target0
{
    // look up the diffuse map layer
    float4 texDiffuse = samBranchDiffuseMap.Sample(samBranchDiffuseMap_Sampler, In.vDiffuseTexCoords.xy);
        	
    return texDiffuse;
}


