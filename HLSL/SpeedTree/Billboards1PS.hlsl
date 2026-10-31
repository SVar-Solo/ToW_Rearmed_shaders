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

// lighting & materials
uniform float3      g_vLightDiffuse;                    // light's diffuse color
uniform float3      g_vLightAmbient;                    // light's diffuse color
uniform float3      g_fDiffuseScale;                    // diffuse scale

// ps
uniform float       g_fBillboardLightAdjust;		    // used to assist in accuracy of normal map lit bb's matching the 3D tree

#ifdef HORZ_BILLBOARDS
uniform float       g_fBillboardFadeValue;              // [0,1], 0 = transparent, 1 = opaque
#endif

uniform sampler2D	samBillboardDiffuseMap  : register(s0);
uniform sampler2D	samBillboardNormalMap   : register(s1);
uniform sampler2D	GBufferTex				: register(s2);

//----------------------------------------------------------------------------- 
//  SBillboardOutput structure

struct SBillboardOutput
{
    float2  vDiffuseTexCoords : TEXCOORD0;
    float2  vNormalTexCoords  : TEXCOORD1;
#ifdef BILLBOARD_NORMAL_MAPPING
    float4  vNormal           : TEXCOORD2;
#else
    float   fNormal           : TEXCOORD2;
#endif
    float3  vLightAdjusts     : TEXCOORD3;
	float4	vScreenPos		  : TEXCOORD4;	// screen coord
};

//#undef BILLBOARD_NORMAL_MAPPING

//-----------------------------------------------------------------------------
//	TOW_Lighting
//-----------------------------------------------------------------------------

float3 TOW_Lighting(float light_value, float ambient_value, float3 diffuse_light, float3 ambient_light, float3 light_koeff)
{
	float light = clamp(light_value*light_koeff.x + light_koeff.y, 0, 1);
	return lerp(ambient_light.rgb*ambient_value, diffuse_light.rgb*light_koeff.z, light);
}

///////////////////////////////////////////////////////////////////////  
//  BillboardPS
//
//  Billboard geometry pixel shader
//
//  Not having BILLBOARD_NORMAL_MAPPING #define'd makes for a much shorter
//  pixel shader - one that should be used on lower compile targets

float4 main(SBillboardOutput In) : COLOR
{
#ifndef BILLBOARD_NORMAL_MAPPING
    float4 texDiffuse = tex2D(samBillboardDiffuseMap, In.vDiffuseTexCoords.xy); // , dsdx, dsdy);
    texDiffuse.a *= In.fNormal;
	return texDiffuse;

#else // BILLBOARD_NORMAL_MAPPING

	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);

    // look up the diffuse and normal-map layers
    float4 texDiffuse = tex2D(samBillboardDiffuseMap, In.vDiffuseTexCoords.xy, dsdx, dsdy);
    float4 texNormal = tex2D(samBillboardNormalMap, In.vNormalTexCoords.xy, dsdx, dsdy);

    // compute the ambient value
    const float4 vecNoiseOffset = { -0.32f, -0.32f, -0.32f, 0.0f };
    float4 vecAmbient = float4(g_vLightAmbient, 0.0) + (texNormal.aaaa + vecNoiseOffset) * In.vLightAdjusts.z; // float4(g_vLightAmbient, 1.0) * 
    vecAmbient = vecAmbient * texDiffuse;
    
    // since the normal map normal values (normally ranged [-1,1]) are store
    // as a color value (ranged [0,1]), they must be uncompressed.  a dot product 
    // is used to compute the diffuse lighting contribution.
    const float3 vecHalves = { 0.5f, 0.5f, 0.5f };
    float fDot = saturate(dot(texNormal.rgb - vecHalves, In.vNormal.rgb)) * 2.0f;

	// read GBuffer
	float2 screen_uv = In.vScreenPos.xy/In.vScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x);
	screen_uv.y = 0.5f * (1.0f - screen_uv.y);
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);
	
#ifdef USE_SHADOWS
	float shadow_factor = gbuffer.r;
    //fDot *= shadow_factor;
#endif  //USE_SHADOWS

#if 0 // old lighting
    // lighting adjustment to use SpeedTreeCAD parameters to help make the bb
    // match the 3D geometry
    float fLightAdjust = lerp(In.vLightAdjusts.x, In.vLightAdjusts.y, g_fBillboardLightAdjust);
    float4 vColor = (fDot * float4(g_vLightDiffuse, 1.0) * texDiffuse * fLightAdjust) + vecAmbient;
#else
	float3 color3 = texDiffuse.rgb * TOW_Lighting (fDot*gbuffer.r, gbuffer.g, g_vLightDiffuse.rgb, g_vLightAmbient.rgb,  g_fDiffuseScale.rgb);
	float4 vColor = float4(color3, 1.0);
#endif

    // use an alpha value that is the diffuse map's noisy alpha channel multiplied
    // against the faded alpha color from the vertex shader
    vColor.a = texDiffuse.a * In.vNormal.w;

	//return float4 (1, 0, 1, In.vNormal.w);
    return vColor;
#endif // BILLBOARD_NORMAL_MAPPING
}

