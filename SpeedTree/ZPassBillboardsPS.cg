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

// lighting & materials
uniform float4      g_vLightDiffuse;                    // light's diffuse color
uniform float4      g_vMaterialDiffuse;                 // active material's diffuse color (set differently for branches, fronds, leaves, and billboards)
uniform float       g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
uniform float4      g_vMaterialAmbient;                 // active material's ambient color (set differently for branches, fronds, leaves, and billboards)
uniform float       g_fAmbientScale;                    // mirrors the ambient scalar value in CAD, used to help combat the darkening effect of multiple texture layers

// other
uniform float4      g_vFogColor;                        // fog color
uniform float3      g_vFogParams;                       // used for fog distance calcs: .x = fog start, .y = fog end, .z = end - start

// ps
uniform float       g_fBillboardLightAdjust;		       // used to assist in accuracy of normal map lit bb's matching the 3D tree

//----------------------------------------------------------------------------- 
//  SBillboardOutput structure

struct SBillboardOutput
{
    float4  vPosition         : POSITION;
    float2  vDiffuseTexCoords : TEXCOORD0;
    float2  vNormalTexCoords  : TEXCOORD1;
#ifdef BILLBOARD_NORMAL_MAPPING
    float4  vNormal           : TEXCOORD2;
#else
    float   fNormal           : TEXCOORD2;
#endif

#ifdef USE_FOG
    float4  vLightAdjusts     : TEXCOORD3;
#else
    float3  vLightAdjusts     : TEXCOORD3; 
#endif

#ifdef USE_SHADOWS
	float4	vShadowMapTexCoords	: TEXCOORD4;
#endif

};

// #undef BILLBOARD_NORMAL_MAPPING

///////////////////////////////////////////////////////////////////////  
//  BillboardPS
//
//  Billboard geometry pixel shader
//
//  Not having BILLBOARD_NORMAL_MAPPING #define'd makes for a much shorter
//  pixel shader - one that should be used on lower compile targets

float4 main(SBillboardOutput In
			, uniform sampler2D samBillboardDiffuseMap : TEXUNIT0 
			, uniform sampler2D samBillboardNormalMap : TEXUNIT1 
#ifdef USE_SHADOWS
			, uniform sampler2D samShadowMap   : TEXUNIT2
#endif // USE_SHADOWS
			) : COLOR
{	
    // look up the diffuse layer
    float4 vColor = tex2D(samBillboardDiffuseMap, In.vDiffuseTexCoords.xy); 
    return vColor;
}

