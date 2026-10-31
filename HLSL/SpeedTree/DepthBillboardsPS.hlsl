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


//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------


uniform sampler2D	samBillboardDiffuseMap  : register(s0);


//----------------------------------------------------------------------------- 
//  SBillboardOutput structure

struct SBillboardOutput
{
    float4  vDiffuseTexCoords : TEXCOORD0;   
	float4	ScreenPos		  : TEXCOORD1;	// screen coord
	float2	SliceRatio		  : TEXCOORD2;
};

//-----------------------------------------------------------------------------
//  DepthBillboardPS
//-----------------------------------------------------------------------------

float4 main(SBillboardOutput In) : COLOR
{
	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);

    // look up the diffuse and normal-map layers
    float4 texDiffuse = tex2D(samBillboardDiffuseMap, In.vDiffuseTexCoords.xy, dsdx, dsdy);    
	float4 texDiffuse1 = tex2D(samBillboardDiffuseMap, In.vDiffuseTexCoords.zw, dsdx, dsdy);
    
	texDiffuse = lerp(texDiffuse, texDiffuse1, In.SliceRatio.x);
	texDiffuse = float4(1, 1, 1, texDiffuse.a); // 
	texDiffuse.a *= In.SliceRatio.y;

	if (texDiffuse.a <= 85.0/255.0)
	{
		discard;
	}

//#ifdef DEPTH_PASS
	float rz = -In.ScreenPos.z;
//#else
	//float rz = -0.001 * In.ScreenPos.z;
//#endif

    return float4(rz, 0, 0, rz);
}

