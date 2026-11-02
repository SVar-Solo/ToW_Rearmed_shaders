// D3D11 port of SpeedTree/BillboardsPS.hlsl. Generated from the legacy HLSL source; see README.md.
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


//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

// lighting & materials
cbuffer BillboardsPS_CB0 : register(b0)
{
float3 g_vLightDiffuse;                    // light's diffuse color
float3 g_vLightAmbient;                    // light's ambient color
float3 g_fDiffuseScale;                    // diffuse scale

// ps
float g_fBillboardLightAdjust;		    // used to assist in accuracy of normal map lit bb's matching the 3D tree

};
#ifdef HORZ_BILLBOARDS
cbuffer BillboardsPS_CB1 : register(b1)
{
float g_fBillboardFadeValue;              // [0,1], 0 = transparent, 1 = opaque
};
#endif

Texture2D samBillboardDiffuseMap : register(t0);
SamplerState samBillboardDiffuseMap_Sampler : register(s0);
Texture2D samBillboardNormalMap : register(t1);
SamplerState samBillboardNormalMap_Sampler : register(s1);
Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);


//----------------------------------------------------------------------------- 
//  SBillboardOutput structure

struct SBillboardOutput
{
    float4  vDiffuseTexCoords : TEXCOORD0;
    float4  vNormalTexCoords  : TEXCOORD1;
    float4  vNormal           : TEXCOORD2;
    float4  vLightAdjusts     : TEXCOORD3;
	float4	vScreenPos		  : TEXCOORD4;	// screen coord
	float4	vNormal2		  : TEXCOORD5;	// normal2
	float2  vAbsCoord		  : TEXCOORD6;  // Координаты для прозрачности на границах ландшафта
};



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
float4 main(SBillboardOutput In) : SV_Target0
{
	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);

    // look up the diffuse and normal-map layers
    float4 texDiffuse = samBillboardDiffuseMap.Sample(samBillboardDiffuseMap_Sampler, In.vDiffuseTexCoords.xy, dsdx, dsdy);
    float4 texNormal = samBillboardNormalMap.Sample(samBillboardNormalMap_Sampler, In.vNormalTexCoords.xy, dsdx, dsdy);

	float4 texDiffuse1 = samBillboardDiffuseMap.Sample(samBillboardDiffuseMap_Sampler, In.vDiffuseTexCoords.zw, dsdx, dsdy);
    float4 texNormal1 = samBillboardNormalMap.Sample(samBillboardNormalMap_Sampler, In.vNormalTexCoords.zw, dsdx, dsdy);

	texDiffuse = lerp(texDiffuse, texDiffuse1, In.vNormal.w);
	texNormal  = lerp(texNormal, texNormal1, In.vNormal.w);
	//texDiffuse = float4(1, 1, 1, texDiffuse.a); 
	texDiffuse.a *= In.vLightAdjusts.w;

	float3 light_in_tangent = lerp(In.vNormal.rgb, In.vNormal2.rgb, In.vNormal.w);

    // compute the ambient value
    const float4 vecNoiseOffset = { -0.32f, -0.32f, -0.32f, 0.0f };
    float4 vecAmbient = (texNormal.aaaa + vecNoiseOffset) * 1.471f * In.vLightAdjusts.z;

    
    // since the normal map normal values (normally ranged [-1,1]) are store
    // as a color value (ranged [0,1]), they must be uncompressed.  a dot product 
    // is used to compute the diffuse lighting contribution.
    const float3 vecHalves = { 0.5f, 0.5f, 0.5f };
    //float fDot = saturate(dot((2.0f*(texNormal.rgb - vecHalves)), (In.vNormal.xyz)));
	float fDot = saturate( dot(texNormal.rgb - vecHalves, light_in_tangent.xyz)) * 2.0f;
	// float fDot = saturate(In.vNormal.z); // saturate(dot(2.0f*(texNormal.rgb - vecHalves), In.vNormal.rgb));

	float  light_adjust = lerp(In.vLightAdjusts.y, In.vLightAdjusts.x, fDot); // g_fBillboardLightAdjust);

	// read GBuffer
	float2 screen_uv = In.vScreenPos.xy/In.vScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x);
	screen_uv.y = 0.5f * (1.0f - screen_uv.y);
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);
	
#ifdef USE_SHADOWS
	float shadow_factor = gbuffer.r;
    // fDot *= shadow_factor;
#endif  //USE_SHADOWS

#if 0// old lighting
    // lighting adjustment to use SpeedTreeCAD parameters to help make the bb
    // match the 3D geometry
    
    float4 vColor = (fDot * float4(g_vLightDiffuse, 1.0) * texDiffuse * fLightAdjust) + vecAmbient;
#else
	///float fLightAdjust = lerp(In.vLightAdjusts.x, In.vLightAdjusts.y, g_fBillboardLightAdjust);
	float3 lighting3 = TOW_Lighting (fDot * light_adjust * gbuffer.r, gbuffer.g, g_vLightDiffuse.rgb, g_vLightAmbient.rgb, g_fDiffuseScale.rgb);
	float4 vColor = float4(lighting3 * texDiffuse.rgb, 1.0);
	//float4 vColor = float4(lighting3, 1.0);
#endif

    // use an alpha value that is the diffuse map's noisy alpha channel multiplied
    // against the faded alpha color from the vertex shader
    vColor.a = texDiffuse.a;// * (1.0-In.vNormal.w);
	//vColor.a = In.vNormal.w;

	//return texNormal; // In.vNormal.w);
	//return float4(texDiffuse.rgb, vColor.a);
	//return float4(In.vNormal.xyz, vColor.a);
	//return float4(In.vLightAdjusts.www, vColor.a);
	//return float4(vecAmbient.rgb, texDiffuse.a);	
	//return float4(light_adjust.rrr, texDiffuse.a);
	
	float fogBorder1 = 1.0f/8.0f;
	float fogBorder2 = 1.0f - fogBorder1;
	
	if (In.vAbsCoord.x > fogBorder1 && In.vAbsCoord.x < fogBorder2 && In.vAbsCoord.y > fogBorder1 && In.vAbsCoord.y < fogBorder2)
	{
		//vColor.a = 1.0f;
	}
	else
	{	
		float alphaX = smoothstep(0.0f, fogBorder1, In.vAbsCoord.x) * (1.0f - smoothstep(fogBorder2, 1.0f, In.vAbsCoord.x));
		float alphaY = smoothstep(0.0f, fogBorder1, In.vAbsCoord.y) * (1.0f - smoothstep(fogBorder2, 1.0f, In.vAbsCoord.y));

		vColor.a *= alphaX * alphaY;
	}
	
    return vColor;
}

