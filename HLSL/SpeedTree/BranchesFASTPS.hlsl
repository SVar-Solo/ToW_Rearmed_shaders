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


//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SBranchOutput
{
    float4  vDiffuseAndSelfTexCoords	: TEXCOORD0;	// Diffuse + SelfShadow
	float4  vNormal						: TEXCOORD1;	// xyz normal, w - INTERMEDIATE_FRONDBRANCH_FADING
	float4  vNormAndDetailTexCoords		: TEXCOORD2;	// NormalMap + DetailTexMap
	float4  vScreenPos					: TEXCOORD3;
};

//-----------------------------------------------------------------------------
//	uniform
//-----------------------------------------------------------------------------

// wind
uniform float       g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
uniform float2      g_vSelfShadowMotion;					// offsets the self-shadow coordinates based on wind strength

// lighting & materials
uniform float3      g_vLightDiffuse;                    // light's diffuse color
uniform float3      g_vLightAmbient;                    // light's ambient color
uniform float3      g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
uniform float       g_fLeafLightingAdjust;              // used to clamp the dot product operation during the leaf vertex lighting operations

// other
uniform float4x4    g_mModelViewProj;                    // composite modelview/projection matrix
uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
uniform float       g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)
uniform float2      g_vCameraAngles;                     // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
uniform float4      g_vCameraAzimuthTrig;               // stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs

#ifdef INTERMEDIATE_FRONDBRANCH_FADING
	uniform float2      g_vBranchLodValues;                 // .x = current LOD, .y = transition radius
#endif

// constants
const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
const float c_fTwoPi = 6.28318530f;                     // 2 * pi

///////////////////////////////////////////////////////////////////////  
//  Branch VS Ouput, PS Input
//
//  Cannot use more than four texture layers in order to compile down to ps_1_1


uniform sampler2D	samBranchDiffuseMap	: register(s0);
uniform sampler2D	samBranchNormalMap	: register(s1);
uniform sampler2D	samSelfShadowMap	: register(s2); 
uniform sampler2D	GBufferTex			: register(s3);

#ifdef BRANCH_DETAIL_LAYER
	uniform sampler2D samBranchDetailMap  : register(s4);
#endif

//-----------------------------------------------------------------------------
//	TOW_Lighting
//-----------------------------------------------------------------------------

float3 TOW_Lighting(float light_value, float ambient_value, float3 diffuse_light, float3 ambient_light, float3 light_koeff)
{
	float light = clamp(light_value*light_koeff.x + light_koeff.y, 0, 1);
	return lerp(ambient_light.rgb*ambient_value, diffuse_light.rgb*light_koeff.z, light);
}


//-----------------------------------------------------------------------------
//  ComputeFadeValue

#ifdef INTERMEDIATE_FRONDBRANCH_FADING

float ComputeFadeValue(float fHint)
{
    float fCurrentLod = g_vBranchLodValues.x;
    float fLodRadius = g_vBranchLodValues.y;
    
    float fValue = (fCurrentLod - fHint) / fLodRadius;
    
    // we don't scale the fade from 0.0 to 1.0 because the range typically used by
    // SpeedTree for its alpha fizzle/fade effect is c_fOpaqueAlpha (84) to 
    // c_fClearAlpha (255), making the low end 84 / 255 instead of 0.
    //
    // 0.33f = c_fOpaqueAlpha / 255.0f
    return lerp(0.33f, 1.0f, clamp(fValue, 0.0f, 1.0f));
}

#endif // INTERMEDIATE_FRONDBRANCH_FADING


///////////////////////////////////////////////////////////////////////  
//  BranchPS
//
//  Branch geometry pixel shader.  This shader can process up to four texture layers:
//      - diffuse bark map
//      - normal map
//      - detail map (lerped against the diffuse map using detail's alpha layer)
//      - self-shadow map (greyscale composite map generated via SpeedTreeCAD)

float4 main(in SBranchOutput In) : COLOR
{

	float2 uv = float2(frac(1000.0+In.vNormAndDetailTexCoords.x), frac(1000.0 - In.vNormAndDetailTexCoords.y));

	float2 dsdx = ddx(uv); // float2(0, 0);
	float2 dsdy = ddy(uv); // float2(0, 0);

#ifdef BRANCH_NORMAL_MAPPING
    // since the normal map normal values (normally ranged [-1,1]) are stored
    // as a color value (ranged [0,1]), they must be uncompressed.  a dot product 
    // is used to compute the diffuse lighting contribution.
	
	
    float4 texNormal = tex2D(samBranchNormalMap, uv); // , dsdx, dsdy);
    const float3 vHalves = { 0.5f, 0.5f, 0.5f };
    float fDot = saturate(dot(2.0f * (texNormal.rgb - vHalves), In.vNormal.rgb));
#endif

    // look up the diffuse map layer
    float4 texDiffuse = tex2D(samBranchDiffuseMap, uv); // , dsdx, dsdy);
    
#ifdef BRANCH_DETAIL_LAYER
    // if branch detail layer is active, look it up and lerp between it
    // and the base layer.  this allows for a smooth transition between diffuse
    // and detail layers if the detail layer's alpha map is done correctly
    // (the diffuse map's alpha layer doesn't figure into it)
    //float4 texDetail = tex2D(samBranchDetailMap, In.vNormAndDetailTexCoords.zw);
    //texDiffuse.rgb = lerp(texDiffuse.rgb, texDetail.rgb, texDetail.a);
#endif
    
	// read GBuffer
	float2 screen_uv = In.vScreenPos.xy/In.vScreenPos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x);
	screen_uv.y = 0.5f * (1.0f - screen_uv.y);
	float4 gbuffer = tex2D(GBufferTex, screen_uv.xy);
	
#ifdef USE_SHADOWS
	float shadow_factor = gbuffer.r;
#endif  //USE_SHADOWS

	// self shadow
	float self_shadow = 1.0f;
#ifdef SELF_SHADOW_LAYER
    //float4 texShadow = tex2D(samSelfShadowMap, float2(In.vDiffuseAndSelfTexCoords.z, 1 - In.vDiffuseAndSelfTexCoords.w));
    //self_shadow = texShadow.r;
#endif   

	// texDiffuse.rgb = float3(1, 1, 1);
	// compute the diffuse contribution, using normal mapping or standard vertex-based lighting
#ifdef BRANCH_NORMAL_MAPPING
    float3 vColor3 = texDiffuse.rgb * TOW_Lighting (fDot*gbuffer.r, gbuffer.g,  g_vLightDiffuse.rgb, g_vLightAmbient.rgb,  g_fDiffuseScale.rgb);
#else
    float3 vColor3 = texDiffuse.rgb * (In.vNormal.rgb * g_fDiffuseScale.x + g_fDiffuseScale.y);
#endif
    
	float4 resault_color = float4(vColor3.rgb, texDiffuse.a);

#ifdef INTERMEDIATE_FRONDBRANCH_FADING
    float fade = In.vNormal.w;
    resault_color.a *= fade;
#endif

	//return float4(1, 0, 1, 1);
	//return float4(uv.y, 0, 0, 1);
	//return float4(texDiffuse.rgb, 1);
    return resault_color;
}


