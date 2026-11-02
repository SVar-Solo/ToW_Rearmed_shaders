// D3D11 port of SpeedTree/ZPassBillboardsPS.hlsl. Generated from the legacy HLSL source; see README.md.
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


//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

// lighting & materials
cbuffer ZPassBillboardsPS_CB0 : register(b0)
{
float4 g_vLightDiffuse;                    // light's diffuse color
float4 g_vMaterialDiffuse;                 // active material's diffuse color (set differently for branches, fronds, leaves, and billboards)
float g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
float4 g_vMaterialAmbient;                 // active material's ambient color (set differently for branches, fronds, leaves, and billboards)
float g_fAmbientScale;                    // mirrors the ambient scalar value in CAD, used to help combat the darkening effect of multiple texture layers

// other
float4 g_vFogColor;                        // fog color
float3 g_vFogParams;                       // used for fog distance calcs: .x = fog start, .y = fog end, .z = end - start

// ps
float g_fBillboardLightAdjust;		       // used to assist in accuracy of normal map lit bb's matching the 3D tree

//----------------------------------------------------------------------------- 
//  SBillboardOutput structure

};
struct SBillboardOutput
{
    float4  vPosition         : SV_Position;
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



Texture2D samBillboardDiffuseMap : register(t0);
SamplerState samBillboardDiffuseMap_Sampler : register(s0);
Texture2D samBillboardNormalMap : register(t1);
SamplerState samBillboardNormalMap_Sampler : register(s1);
#ifdef USE_SHADOWS
Texture2D samShadowMap : register(t2);
SamplerState samShadowMap_Sampler : register(s2);
#endif

float4 main(SBillboardOutput In) : SV_Target0
{	
    // look up the diffuse layer
    float4 vColor = samBillboardDiffuseMap.Sample(samBillboardDiffuseMap_Sampler, In.vDiffuseTexCoords.xy); 
    return vColor;
}

