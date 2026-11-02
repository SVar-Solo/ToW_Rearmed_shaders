// D3D11 port of SpeedTree/LeafMeshVS.hlsl. Generated from the legacy HLSL source; see README.md.
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



//#define IDV_OPENGL

//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SLeafInput
{
	float4   _vPosition  : POSITION;	// xyz = position, w = compressed wind param 1
	float3   _vNormal    : NORMAL;		// xyz = normal xyz
	float4   _vTexCoord0 : TEXCOORD0;	// xy = diffuse texcoords, z = wind angle index, w = dimming
	float4   _vTexCoord1 : TEXCOORD1;	// xyz = vector xyz
	float4   _vTexCoord2 : TEXCOORD2;	// xyz = vector xyz
	float4   _vTexCoord3 : TEXCOORD3;	// xyz = mesh placement position, w = compressed wind param 2
#ifdef LEAF_NORMAL_MAPPING
	float3   _vTangent   : TEXCOORD4;
#endif
};

struct SLeafOutput
{
    float4 vPosition		: SV_Position;
    float2 vBaseTexCoords	: TEXCOORD0;
	float4 vScreenPos		: TEXCOORD1;

#ifdef LEAF_NORMAL_MAPPING	
	float3 vNormal			: TEXCOORD2;
#else
	float4 vColor			: TEXCOORD2;	
#endif
};

//-----------------------------------------------------------------------------
//	uniform
//-----------------------------------------------------------------------------

// wind 
cbuffer LeafMeshVS_CB0 : register(b0)
{
float g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
column_major float4x4 g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types

// lighting & materials
float3 g_vLightDir;                         // normalized light direction (shaders assume a single light source)
float4 g_vLightDiffuse;                    // light's diffuse color
float4 g_vMaterialDiffuse;                 // active material's diffuse color (set differently for branches, fronds, leaves, and billboards)

// other
column_major float4x4 ModelViewProj;                    // composite modelview/projection matrix

//uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
//uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
float4 g_vTreeMatrixRow0;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow1;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow2;                      // composite translate/rotation matrix

float g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)


///////////////////////////////////////////////////////////////////////  
//  Leaf-specific global variables

// vs
float4 g_avLeafAngles[MAX_NUM_LEAF_ANGLES]; // each element: .x = rock angle, .y = rustle angle
                                                 // each element is a float4, even though only a float2 is needed, to facilitate
                                                 // fast uploads on all platforms (one call to upload whole array)
float4 g_vLeafAngleScalars;                 // each tree model has unique scalar values: .x = rock scalar, .y = rustle scalar



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
//  LightDiffuse
//
//  Very simple lighting equation, used by the fronds and leaves (branches
//  and billboards are normal mapped).
//-----------------------------------------------------------------------------

float3 LightDiffuse(float3 vVertex,
                    float3 vNormal,
                    float3 vLightDir,
                    float3 vLightColor,
                    float3 vDiffuseMaterial)
{
    return vDiffuseMaterial * vLightColor * max(dot(vNormal, vLightDir), 0.0f);
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


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

SLeafOutput
main (in SLeafInput sInput)
{
    // this will be fed to the leaf pixel shader
    SLeafOutput sOutput;

	float4   vPosition  = sInput._vPosition;
	float4   vTexCoord0 = sInput._vTexCoord0;
	float4   vTexCoord1 = sInput._vTexCoord1;
	float4   vTexCoord2 = sInput._vTexCoord2;
	float4   vTexCoord3 = sInput._vTexCoord3;

#ifdef LEAF_NORMAL_MAPPING
	float3   vTangent = sInput._vTangent;
#endif
	float3   vNormal = sInput._vNormal;


	float3   vOrientX = vTexCoord1.xyz;
	float3   vOrientZ = vTexCoord2.xyz;
	float4   vOffset  = vTexCoord3;

    // define attribute aliases for readability
    float fWindAngleIndex = vTexCoord0.z;       // which wind matrix this leaf card will follow
    float fDimming = vTexCoord0.w;              // interior leaves are darker (range = [0.0,1.0])
    float2 vWindParams = float2(vPosition.w, vOffset.w);
	vPosition.w = 1.0f;
	vOffset.w = 1.0f;
    //float3 vTangent = float3(0, 0, 1);
	
    // vOffset represents the location where the leaf mesh will be placed - here it is rotated into place
    // and has the wind effect motion applied to it
// #ifdef UPVECTOR_POS_Y
//     vOffset.xz = float2(dot(g_vTreeRotationTrig.ywz, vOffset.xyz), dot(g_vTreeRotationTrig.xwy, vOffset.xyz));
// #else
//     vOffset.xy = float2(dot(g_vTreeRotationTrig.yxw, vOffset.xyz), dot(g_vTreeRotationTrig.zyw, vOffset.xyz));
// #endif

	vOffset.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vOffset.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vOffset.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vOffset.xyz));

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
    vNormal = mul(matOrientMesh, vNormal.xyz);
    
    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
// #ifdef UPVECTOR_POS_Y
//     vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));
//     vNormal.xz = float2(dot(g_vTreeRotationTrig.ywz, vNormal.xyz), dot(g_vTreeRotationTrig.xwy, vNormal.xyz));
// #else
//     vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));
//     vNormal.xy = float2(dot(g_vTreeRotationTrig.yxw, vNormal.xyz), dot(g_vTreeRotationTrig.zyw, vNormal.xyz));
// #endif

	vPosition.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vPosition.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vPosition.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vPosition.xyz));

	vNormal.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vNormal.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vNormal.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vNormal.xyz));

    // put oriented mesh into place at rotated and wind-affected vOffset
    vPosition.xyz += vOffset.xyz;

    // scale the geometry (each tree instance can be uniquely scaled)
    vPosition.xyz *= g_fTreeScale;
    
    // translate tree into position (must be done after the rotation)
    // vPosition.xyz += g_vTreePos.xyz;
	vPosition.xyz += float3(g_vTreeMatrixRow0.w, g_vTreeMatrixRow1.w, g_vTreeMatrixRow2.w);

    // compute the leaf lighting (not using normal mapping, but per-vertex lighting)
#ifdef LEAF_NORMAL_MAPPING
    // setup per-pixel normal mapping  (assumes normalized light direction)
    
    // rotate the tangent by this instance's rotation and derive the binormal from the normal & tangent 
    // in order to keep vertex attribute count lower
// #ifdef UPVECTOR_POS_Y
//     vTangent.xz = float2(dot(g_vTreeRotationTrig.ywz, vTangent.xyz), dot(g_vTreeRotationTrig.xwy, vTangent.xyz));
// #else
//     vTangent.xy = float2(dot(g_vTreeRotationTrig.yxw, vTangent.xyz), dot(g_vTreeRotationTrig.zyw, vTangent.xyz));
// #endif

	vTangent.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vTangent.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vTangent.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vTangent.xyz));

     float3 vBinormal = cross(vNormal.xyz, vTangent);
    
    // 0.5f + 0.5f * expr not used since texcoords aren't clamped to [0,1] range - this approach saves
    // several instructions
    sOutput.vNormal.x = dot(g_vLightDir.xyz, vTangent.xyz);
    sOutput.vNormal.y = dot(g_vLightDir.xyz, vBinormal.xyz);
    sOutput.vNormal.z = dot(g_vLightDir.xyz, vNormal.xyz);
    
    //sOutput.vNormal.xyz *= fDimming;
#else
    //sOutput.vColor.rgb = fDimming * LightDiffuse(vPosition.xyz, vNormal.xyz, g_vLightDir, g_vLightDiffuse.rgb, g_vMaterialDiffuse.rgb);
	vNormal = normalize (vNormal);
	sOutput.vColor.rgb = vNormal.rgb; // g_vLightDiffuse.rgb * max(dot(vNormal, g_vLightDir), 0.0f);
    sOutput.vColor.a = 1.0f;
#endif

    // project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
	sOutput.vScreenPos = sOutput.vPosition;
    
    // pass through other texcoords exactly as they were received
    sOutput.vBaseTexCoords.xy = float2(vTexCoord0.x, vTexCoord0.y);

    return sOutput;
}
