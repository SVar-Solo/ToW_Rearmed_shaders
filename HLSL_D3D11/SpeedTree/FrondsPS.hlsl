// D3D11 port of SpeedTree/FrondsPS.hlsl. Generated from the legacy HLSL source; see README.md.
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
//	SFrondOutput
//-----------------------------------------------------------------------------

struct SFrondOutput
{
    float4  vDiffuseAndSelfTexCoords	: TEXCOORD0;	// Diffuse + SelfShadow
	float4  vNormal						: TEXCOORD1;	// xyz normal, w - INTERMEDIATE_FRONDBRANCH_FADING
	float4  vScreenPos					: TEXCOORD3;
};

//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

// lighting & materials
cbuffer FrondsPS_CB0 : register(b0)
{
float3 g_vLightDiffuse;           // light's diffuse color
float3 g_vLightAmbient;           // light's diffuse color
float3 g_fDiffuseScale;           // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers

};
Texture2D samCompositeDiffuseLeafMap : register(t0);
SamplerState samCompositeDiffuseLeafMap_Sampler : register(s0);
Texture2D samCompositeNormalLeafMap : register(t1);
SamplerState samCompositeNormalLeafMap_Sampler : register(s1);
Texture2D samSelfShadowMap : register(t2);
SamplerState samSelfShadowMap_Sampler : register(s2);
Texture2D GBufferTex : register(t3);
SamplerState GBufferTex_Sampler : register(s3);


//-----------------------------------------------------------------------------
//	TOW_Lighting
//-----------------------------------------------------------------------------

float3 TOW_Lighting(float light_value, float ambient_value, float3 diffuse_light, float3 ambient_light, float3 light_koeff)
{
	float light = clamp(light_value*light_koeff.x + light_koeff.y, 0, 1);
	return lerp(ambient_light.rgb*ambient_value, diffuse_light.rgb*light_koeff.z, light);
}

//-----------------------------------------------------------------------------
//  FrondPS
//
//  Frond geometry pixel shader.  This shader can process up to two texture layers:
//      - diffuse composite leaf/frond map
//      - self-shadow map (greyscale composite map generated via SpeedTreeCAD)
//-----------------------------------------------------------------------------

float4
main(SFrondOutput In) : SV_Target0
{
	
	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);

#ifdef FROND_NORMAL_MAPPING
    // since the normal map normal values (normally ranged [-1,1]) are stored
    // as a color value (ranged [0,1]), they must be uncompressed.  a dot product 
    // is used to compute the diffuse lighting contribution.
    float4 texNormal = samCompositeNormalLeafMap.Sample(samCompositeNormalLeafMap_Sampler, float2(In.vDiffuseAndSelfTexCoords.x, 1.0 - In.vDiffuseAndSelfTexCoords.y)); // ,
		// dsdx, dsdy);

    const float3 vHalves = { 0.5f, 0.5f, 0.5f };
    float fDot = saturate(abs(dot(2.0f * (texNormal.rgb - vHalves), In.vNormal.rgb)));
	//float fDot = saturate(abs(dot(texNormal.rgb, In.vNormal.rgb)));
	//float fDot = In.vNormal.z;
#endif
    
    // look up the diffuse layer
    float4 texDiffuse = samCompositeDiffuseLeafMap.Sample(samCompositeDiffuseLeafMap_Sampler, float2(In.vDiffuseAndSelfTexCoords.x, 1.0 - In.vDiffuseAndSelfTexCoords.y)); // ,
		//dsdx, dsdy);
    //texDiffuse.rgb = float3(1, 1, 1);

	// read GBuffer
	float2 screen_uv = In.vScreenPos.xy/In.vScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x);
	screen_uv.y = 0.5f * (1.0f - screen_uv.y);
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);
	
#ifdef USE_SHADOWS
	float shadow_factor = gbuffer.r;
#endif  //USE_SHADOWS

	// self shadow
	float self_shadow = 1.0f;

#ifdef SELF_SHADOW_LAYER
	 // overlay the shadow if active
    float4 texShadow = samSelfShadowMap.Sample(samSelfShadowMap_Sampler, float2(In.vDiffuseAndSelfTexCoords.z, 1.0 - In.vDiffuseAndSelfTexCoords.w));
    self_shadow = texShadow.r;
#endif   

	//fDot = 1;
	// compute the diffuse contribution, using normal mapping or standard vertex-based lighting
#ifdef FROND_NORMAL_MAPPING
    float3 vColor3 = texDiffuse.rgb * TOW_Lighting (fDot*gbuffer.r, gbuffer.g,  g_vLightDiffuse.rgb, g_vLightAmbient.rgb,  g_fDiffuseScale.rgb);
#else
    float3 vColor3 = texDiffuse.rgb * (In.vNormal.rgb * g_fDiffuseScale.x + g_fDiffuseScale.y);
#endif
    
	float4 resault_color = float4(vColor3.rgb, texDiffuse.a);

    
#ifdef INTERMEDIATE_FRONDBRANCH_FADING
    float fFade = In.vNormal.w;
    resault_color.a *= fFade;
#endif
  
	//return float4(In.vNormal.rgb, texDiffuse.a);	
	//return	float4(screen_uv.xy, 1, 1);
    return resault_color;
}
