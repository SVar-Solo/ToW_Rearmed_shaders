// D3D11 port of SpeedTree/ZPassFrondsVS.hlsl. Generated from the legacy HLSL source; see README.md.
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


// wind 
cbuffer ZPassFrondsVS_CB0 : register(b0)
{
float g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
column_major float4x4 g_amWindMatrices[MAX_NUM_LEAF_ANGLES];	// houses all of the wind matrices shared by all geometry types

// other
column_major float4x4 ModelViewProj;						// composite modelview/projection matrix
float4 g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
float4 g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
float g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)
float2 g_vCameraAngles;                     // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
float4 g_vCameraAzimuthTrig;               // stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs



//-----------------------------------------------------------------------------
//	WindEffect
//-----------------------------------------------------------------------------

};
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
    float3 vWindEffect = lerp(vPosition.xyz, mul(vPosition.xyz, float3x3(tmp_mat[0].xyz, tmp_mat[1].xyz, tmp_mat[2].xyz)), vWeights.x);
#else
    float3 vWindEffect = lerp(vPosition.xyz, mul(vPosition, g_amWindMatrices[int(vIndices.x)]), vWeights.x);
#endif
    
    // second-level wind effect - interpolate between first-level wind position and 
    // the fully-blown wind position by the second wind weight value
#ifdef TWO_WEIGHT_WIND
    #ifdef IDV_OPENGL
		tmp_mat = g_amWindMatrices[int(vIndices.y)];
        return lerp(vWindEffect, mul(vWindEffect.xyz, float3x3(tmp_mat[0].xyz, tmp_mat[1].xyz, tmp_mat[2].xyz)), vWeights.y);
    #else
        return lerp(vWindEffect, mul(vWindEffect, g_amWindMatrices[int(vIndices.y)]), vWeights.y);
    #endif
#else
    return vWindEffect;
#endif
}

//-----------------------------------------------------------------------------
//	SFrondOutput
//-----------------------------------------------------------------------------

struct SFrondOutput
{
    float2 vDiffuseTexCoords    : TEXCOORD0;
    float4 vPosition            : SV_Position;
};


//-----------------------------------------------------------------------------
//  FrondVS
//
//  Frond geometry vertex shader
//-----------------------------------------------------------------------------

SFrondOutput main(float4     _vPosition   : POSITION,
                  float4     _vNormal     : TEXCOORD0,
                  float4     _vTexCoords1 : TEXCOORD1)
{
    // this will be fed to the frond pixel shader
    SFrondOutput sOutput;


	float4 vPosition   = _vPosition;
	float4 vNormal     = _vNormal;
	float4 vTexCoords1 = _vTexCoords1;

    // define attribute aliases for readability    
    float2 vDiffuseTexCoords = float2(vTexCoords1.x, 1.0f - vTexCoords1.y);
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
    
    // compute new position from wind effect
    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);
    
    // translate tree into position (must be done after the rotation)
    vPosition.xyz += g_vTreePos.xyz;

        
    // project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
    
    // pass through other texcoords exactly as they were received
    sOutput.vDiffuseTexCoords.xy = vDiffuseTexCoords;

    return sOutput;
}