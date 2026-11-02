// D3D11 port of SpeedTree/LeafCardsFASTPS.hlsl. Generated from the legacy HLSL source; see README.md.
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
//	input
//-----------------------------------------------------------------------------

struct SLeafOutput
{
    float2 vBaseTexCoords	: TEXCOORD0;
	float4 vScreenPos		: TEXCOORD1;
	float4 vNormal			: TEXCOORD2;
};

//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

// lighting & materials
cbuffer LeafCardsFASTPS_CB0 : register(b0)
{
float3 g_vLightDiffuse;                    // light's diffuse color
float3 g_vLightAmbient;                    // light's ambient color
float3 g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
float g_fLeafLightingAdjust;				// light adjustment

// dont used
//uniform float       g_fAmbientScale;                    // mirrors the ambient scalar value in CAD, used to help combat the darkening effect of multiple texture layers
//uniform float3      g_vMaterialDiffuse;                 // active material's diffuse color (set differently for branches, fronds, leaves, and billboards)
//uniform float3      g_vMaterialAmbient;                 // active material's ambient color (set differently for branches, fronds, leaves, and billboards)

};
Texture2D samCompositeDiffuseLeafMap : register(t0);
SamplerState samCompositeDiffuseLeafMap_Sampler : register(s0); 
Texture2D samCompositeNormalLeafMap : register(t1);
SamplerState samCompositeNormalLeafMap_Sampler : register(s1);
Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);


//-----------------------------------------------------------------------------
//	TOW_Lighting
//-----------------------------------------------------------------------------

float3 TOW_Lighting(float light_value, float ambient_value, float3 diffuse_light, float3 ambient_light, float3 light_koeff)
{
	float light = clamp(light_value*light_koeff.x + light_koeff.y, 0, 1);
	return lerp(ambient_light.rgb*ambient_value, diffuse_light.rgb*light_koeff.z, light);
}

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

//
//  Leaf geometry pixel shader, shared by both leaf cards and mshes.  This 
//  shader processes only one layer:
//      - diffuse composite leaf/frond map
//
//  There is no self-shadow layer used in the leaf geometry.

float4 
main (SLeafOutput In) : SV_Target0
{
	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);
	

    // since the normal map normal values (normally ranged [-1,1]) are stored
    // as a color value (ranged [0,1]), they must be uncompressed.  a dot product 
    // is used to compute the diffuse lighting contribution.
    //float4 texNormal = tex2D(samCompositeNormalLeafMap, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y)); // , dsdx, dsdy); 

    //const float3 vHalves = { 0.5f, 0.5f, 0.5f };

// 	float3 normal = (In.vNormal.xyz);
//     float fDot1 = saturate(dot((2.0f * (texNormal.rgb - vHalves)), normal)); //In.vNormal.w * 	
// 	float fDot2 = In.vNormal.w * saturate(normal.z);
	//float fDot = fDot1; // abs(fDot1 - fDot2);
	
	float4 texNormal = samCompositeNormalLeafMap.Sample(samCompositeNormalLeafMap_Sampler, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y));
	//texNormal = float4(0, 0, 1, 1); // texDiffuse.a);

    const float3 vHalves = { 0.5f, 0.5f, 0.5f };
    float fDot = saturate(dot(2.0f * (texNormal.rgb - vHalves), In.vNormal.rgb));
	
    fDot = lerp(g_fLeafLightingAdjust, 1.0f, fDot);
	

    // look up the diffuse layer
    float4 texDiffuse =  samCompositeDiffuseLeafMap.Sample(samCompositeDiffuseLeafMap_Sampler, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y)); 
	//texDiffuse = float4(1, 1, 1, 1); // texDiffuse.a);

	// read GBuffer
	float2 screen_uv = In.vScreenPos.xy/In.vScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x);
	screen_uv.y = 0.5f * (1.0f - screen_uv.y);
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);
	
#ifdef USE_SHADOWS1
	// get shadowing factor
	float shadow_factor = gbuffer.r;
    /// vDiffuse *= shadow_factor;
#endif  //USE_SHADOWS

	//float fDot = 1;
	// compute the diffuse contribution, using normal mapping or standard vertex-based lighting

   // float3 vColor3 = texDiffuse.rgb * TOW_Lighting (fDot*gbuffer.r, gbuffer.g,  g_vLightDiffuse.rgb, g_vLightAmbient.rgb,  g_fDiffuseScale.rgb);
	 float3 vColor3 = texDiffuse.rgb * TOW_Lighting (fDot, gbuffer.g,  g_vLightDiffuse.rgb, g_vLightAmbient.rgb,  g_fDiffuseScale.rgb);
    
	//return float4(In.vNormal.rgb, 1);
	//return float4(fDot.rrr, texDiffuse.a);
	//return float4(texDiffuse.rgb, texDiffuse.a);
    return float4(vColor3.rgb, texDiffuse.a);
}


