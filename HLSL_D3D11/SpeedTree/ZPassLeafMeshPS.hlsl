// D3D11 port of SpeedTree/ZPassLeafMeshPS.hlsl. Generated from the legacy HLSL source; see README.md.
#include "../SpeedTreeDefaults.hlsli"
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
#include "../SpeedTreeDefaults.hlsli"
#endif

#define IDV_OPENGL



///////////////////////////////////////////////////////////////////////  
//  Leaf VS Ouput, PS Input

struct SLeafOutput
{
    float2 vBaseTexCoords : TEXCOORD0;
    float4 vPosition      : SV_Position;
};


///////////////////////////////////////////////////////////////////////  
//  LeafPS
//
//  Leaf geometry pixel shader, shared by both leaf cards and mshes.  This 
//  shader processes only one layer:
//      - diffuse composite leaf/frond map
//
//  There is no self-shadow layer used in the leaf geometry.



Texture2D samCompositeDiffuseLeafMap : register(t0);
SamplerState samCompositeDiffuseLeafMap_Sampler : register(s0);

float4 
main (SLeafOutput In
	  ) : SV_Target0
{
    // look up the diffuse layer
    float4 texDiffuse = samCompositeDiffuseLeafMap.Sample(samCompositeDiffuseLeafMap_Sampler, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y));
    float4 vColor = texDiffuse;
		
	//vColor.xyz = float3(1, 1, 1);
	//vColor.a = 1.0;

    return vColor;
}


