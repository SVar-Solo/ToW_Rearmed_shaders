// D3D11 port of SpeedTree/ZPassBranchesVS.hlsl. Generated from the legacy HLSL source; see README.md.
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

// wind 
cbuffer ZPassBranchesVS_CB0 : register(b0)
{
float g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
column_major float4x4 g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types

// lighting & materials
float g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers

// tree position
float4 g_vTreePos;
float4 g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
float g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)

// matrices
column_major float4x4 ModelViewProj;
column_major float4x4 g_ShadowMapProj;


// constants
};
const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
const float c_fTwoPi = 6.28318530f;                     // 2 * pi



///////////////////////////////////////////////////////////////////////  
//  WindEffect
//
//  New with 4.0 is a two-weight wind system that allows the tree model
//  to bend at more than one branch level.
//
//  In order to keep the vertex size small, the wind parameters have been
//  compressed as detailed here:
//
//      vWindInfo.x = (wind_matrix_index1 * 10.0) / NUM_WIND_MATRICES  + wind_weight1
//      vWindInfo.y = (wind_matrix_index2 * 10.0) / NUM_WIND_MATRICES  + wind_weight2
//
//  * Note: NUM_WIND_MATRICES cannot be larger than 10 in this case
//
//  * Caution: Negative wind weights will not work with this scheme.  We rely on the
//             fact that the SpeedTreeRT library clamps wind weights to [0.0, 1.0]

#define TWO_WEIGHT_WIND

float3 WindEffect(float3 vPosition, float2 vWindInfo)
{
    // decode both wind weights and matrix indices at the same time in order to save
    // vertex instructions
    vWindInfo.xy += g_fWindMatrixOffset.xx;
    float2 vWeights = frac(vWindInfo.xy);
    float2 vIndices = (vWindInfo - vWeights) * 0.05f * NUM_WIND_MATRICES;
    
    // first-level wind effect - interpolate between static position and fully-blown
    // wind position by the wind weight value
#ifdef IDV_OPENGL
	float4x4 tmp_mat = g_amWindMatrices[int(vIndices.x)];
    float3 vWindEffect = lerp(vPosition.xyz, mul(vPosition, float3x3(tmp_mat[0].xyz, tmp_mat[1].xyz, tmp_mat[2].xyz)), vWeights.x);
#else
    float3 vWindEffect = lerp(vPosition.xyz, mul(vPosition, g_amWindMatrices[int(vIndices.x)]), vWeights.x);
#endif
    
    // second-level wind effect - interpolate between first-level wind position and 
    // the fully-blown wind position by the second wind weight value
#ifdef TWO_WEIGHT_WIND
    #ifdef IDV_OPENGL
		tmp_mat = g_amWindMatrices[int(vIndices.y)];
        return lerp(vWindEffect, mul(vWindEffect, float3x3(tmp_mat[0].xyz, tmp_mat[1].xyz, tmp_mat[2].xyz)), vWeights.y);
    #else
        return lerp(vWindEffect, mul(vWindEffect, g_amWindMatrices[int(vIndices.y)]), vWeights.y);
    #endif
#else
    return vWindEffect;
#endif
}



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
//  BranchVS
//
//  Branch geometry vertex shader

SBranchOutput main(float4   _vPosition   : POSITION,     // xyz = coords, w = self-shadow texcoord s                   
                   float4   _vTexCoords1 : TEXCOORD1    // xy = diffuse texcoords, zw = compressed wind parameters
				   )
{
    // this will be fed to the branch pixel shader
    SBranchOutput sOutput;

	float4 vPosition	= _vPosition;
	float4 vTexCoords1	=_vTexCoords1;

    // define attribute aliases for readability    
    float2 vDiffuseTexCoords = float2(vTexCoords1.xy);
    float2 vWindParams = float2(vTexCoords1.zw);

	// scale the geometry (each tree instance can be uniquely scaled)
    vPosition.xyz *= g_fTreeScale;

    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
	
#ifdef UPVECTOR_POS_Y
    vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));
#else
    vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));
#endif
	
        
    // compute new position from wind effect - improved lighting accuracy may be achieved by also transforming 
    // the normal, binormal, and tangent by the wind matrix, but this was judged too expensive for the minimal 
    // effect it achieved.
    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);
    
    // translate tree into position (must be done after the rotation)
	//g_vTreePos.z = 0.0f;
    vPosition.xyz += g_vTreePos.xyz;

    
    // project position to the screen
    //sOutput.vPosition = mul(g_ShadowMapProj, float4(vPosition.xyz, 1.0f));
	sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));

    // pass through other texcoords exactly as they were received
    sOutput.vDiffuseTexCoords.xy = vDiffuseTexCoords.xy;

    return sOutput;
}


