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

// wind 
uniform float       g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
uniform float4x4    g_amWindMatrices[MAX_NUM_LEAF_ANGLES];	// houses all of the wind matrices shared by all geometry types


// other
uniform float4x4    ModelViewProj;                    // composite modelview/projection matrix
uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
uniform float       g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)
uniform float2      g_vCameraAngles;                     // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations



// constants
const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
const float c_fTwoPi = 6.28318530f;                     // 2 * pi


///////////////////////////////////////////////////////////////////////  
//  Leaf-specific global variables

// vs
uniform float4      g_avLeafAngles[MAX_NUM_LEAF_ANGLES]; // each element: .x = rock angle, .y = rustle angle
                                                 // each element is a float4, even though only a float2 is needed, to facilitate
                                                 // fast uploads on all platforms (one call to upload whole array)
uniform float4      g_vLeafAngleScalars;                 // each tree model has unique scalar values: .x = rock scalar, .y = rustle scalar


///////////////////////////////////////////////////////////////////////  
//  Leaf VS Ouput, PS Input

struct SLeafOutput
{
    float4 vPosition      : POSITION;
    float2 vBaseTexCoords : TEXCOORD0;
};

//-----------------------------------------------------------------------------
//	WindEffect
//-----------------------------------------------------------------------------

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
//  RotationMatrix_zAxis
//
//  Constructs a Z-axis rotation matrix
//-----------------------------------------------------------------------------

float3x3 RotationMatrix_zAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(vSinCos.y, -vSinCos.x, 0.0f, 
                    vSinCos.x, vSinCos.y, 0.0f, 
                    0.0f, 0.0f, 1.0f);
}


//-----------------------------------------------------------------------------
//  RotationMatrix_yAxis
//
//  Constructs a Y-axis rotation matrix
//-----------------------------------------------------------------------------

float3x3 RotationMatrix_yAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(vSinCos.y, 0.0f, vSinCos.x,
                    0.0f, 1.0f, 0.0f,
                    -vSinCos.x, 0.0f, vSinCos.y);
}


//-----------------------------------------------------------------------------
//  RotationMatrix_xAxis
//
//  Constructs a X-axis rotation matrix
//-----------------------------------------------------------------------------


float3x3 RotationMatrix_xAxis(float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    sincos(fAngle, vSinCos.x, vSinCos.y);
    
    return float3x3(1.0f, 0.0f, 0.0f,
                    0.0f, vSinCos.y, -vSinCos.x,
                    0.0f, vSinCos.x, vSinCos.y);
}



///////////////////////////////////////////////////////////////////////  
//  LeafMeshVS

SLeafOutput main      (float4   _vPosition  : POSITION,   // xyz = position, w = compressed wind param 1
                       float4   _vTexCoord0 : TEXCOORD0,  // xy = diffuse texcoords, z = wind angle index, w = dimming
                       float4   _vTexCoord1 : TEXCOORD1,  // xyz = vector xyz
                       float4   _vTexCoord2 : TEXCOORD2,  // xyz = vector xyz
                       float4   _vTexCoord3 : TEXCOORD3  // xyz = mesh placement position, w = compressed wind param 2
					   ) 
{
    // this will be fed to the leaf pixel shader
    SLeafOutput sOutput;

	float4   vPosition  = _vPosition;
	float4   vTexCoord0 = _vTexCoord0;
	float4   vTexCoord1 = _vTexCoord1;
	float4   vTexCoord2 = _vTexCoord2;
	float4   vTexCoord3 = _vTexCoord3;


	float3   vOrientX = vTexCoord1.xyz;
	float3   vOrientZ = vTexCoord2.xyz;
	float4   vOffset  = vTexCoord3;

    // define attribute aliases for readability
    float fWindAngleIndex = vTexCoord0.z;       // which wind matrix this leaf card will follow
    float fDimming = vTexCoord0.w;              // interior leaves are darker (range = [0.0,1.0])
    float2 vWindParams = float2(vPosition.w, vOffset.w);
	vPosition.w = 1.0f;
	vOffset.w = 1.0f;
    
	
    // vOffset represents the location where the leaf mesh will be placed - here it is rotated into place
    // and has the wind effect motion applied to it
#ifdef UPVECTOR_POS_Y
    vOffset.xz = float2(dot(g_vTreeRotationTrig.ywz, vOffset.xyz), dot(g_vTreeRotationTrig.xwy, vOffset.xyz));
#else
    vOffset.xy = float2(dot(g_vTreeRotationTrig.yxw, vOffset.xyz), dot(g_vTreeRotationTrig.zyw, vOffset.xyz));
#endif

    vOffset.xyz = WindEffect(vOffset.xyz, vWindParams);
    
    // compute rock and rustle values (all trees share the g_avLeafAngles table), but g_vLeafAngleScalars
    // scales the angles to match wind settings specified in SpeedTreeCAD
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;
    
    // vPosition stores the leaf mesh geometry, not yet put into place at position vOffset.
    // leaf meshes rock and rustle, which requires rotations on two axes (rustling is not
    // useful on leaf mesh geometry)
    float3x3 matRockRustle = RotationMatrix_xAxis(vLeafRockAndRustle.x); // rock
    vPosition.xyz = mul(matRockRustle, float3(vPosition.xyz));
    
    // build mesh orientation matrix - cannot be done beforehand on CPU due to wind effect / rotation order issues.
    // it is used to orient each mesh into place at vOffset
    float3 vOrientY = cross(vOrientX.xyz, vOrientZ.xyz);
#ifdef UPVECTOR_POS_Y
    vOrientY = -vOrientY;
#endif

    //float3x3 matOrientMesh = float3x3(float3(vOrientX.xyz), float3(vOrientY.xyz), float3(vOrientZ.xyz));
	float3x3 matOrientMesh =
    {
        vOrientX, vOrientY, vOrientZ
    };
    
    // apply orientation matrix to the mesh positon & normal
    vPosition.xyz = mul(matOrientMesh, vPosition.xyz);
    
    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
#ifdef UPVECTOR_POS_Y
    vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));    
#else
    vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));    
#endif

    // put oriented mesh into place at rotated and wind-affected vOffset
    vPosition.xyz += vOffset.xyz;

    // scale the geometry (each tree instance can be uniquely scaled)
    vPosition.xyz *= g_fTreeScale;
    
    // translate tree into position (must be done after the rotation)
    vPosition.xyz += g_vTreePos.xyz;
    
    // project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
    
    // pass through other texcoords exactly as they were received
    sOutput.vBaseTexCoords.xy = float2(vTexCoord0.x, vTexCoord0.y);

    return sOutput;
}
