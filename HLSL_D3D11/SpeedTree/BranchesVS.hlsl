// D3D11 port of SpeedTree/BranchesVS.hlsl. Generated from the legacy HLSL source; see README.md.
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



//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SBranchInput
{
	float4   _vPosition   : POSITION;     // xyz = coords, w = self-shadow texcoord s
	float4   _vNormal     : TEXCOORD0;    // xyz = normal, w = self-shadow texcoord t
	float4   _vTexCoords1 : TEXCOORD1;    // xy = diffuse texcoords, zw = compressed wind parameters
	float4   _vTexCoords2 : TEXCOORD2;    // xy = detail texcoords, zw = normal-map texcoords

#ifdef INTERMEDIATE_FRONDBRANCH_FADING
	float4   _vTexCoords3 : TEXCOORD3;    // xyz = tangent (binormal is derived from normal and tangent), w = lod fade hint
#else                
	float3   _vTexCoords3 : TEXCOORD3;    // xyz = tangent (binormal is derived from normal and tangent)
#endif // INTERMEDIATE_FRONDBRANCH_FADING

};

struct SBranchOutput
{
    float4  vDiffuseAndSelfTexCoords	: TEXCOORD0;	// Diffuse + SelfShadow
    float4  vNormal						: TEXCOORD1;	// xyz normal, w - INTERMEDIATE_FRONDBRANCH_FADING
    float4  vNormAndDetailTexCoords		: TEXCOORD2;	// NormalMap + DetailTexMap
    float4  vScreenPos					: TEXCOORD3;
    float4  vPosition					: SV_Position;
};

//-----------------------------------------------------------------------------
//	uniforms
//-----------------------------------------------------------------------------

// wind 
cbuffer BranchesVS_CB0 : register(b0)
{
float g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
column_major float4x4 g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types
float2 g_vSelfShadowMotion;					// offsets the self-shadow coordinates based on wind strength

// lighting & materials
float3 g_vLightDir;                         // normalized light direction (shaders assume a single light source)
float3 g_vLightDiffuse;                    // light's diffuse color
//uniform float4      g_vMaterialDiffuse;                 // active material's diffuse color (set differently for branches, fronds, leaves, and billboards)
float3 g_fDiffuseScale;                    // mirrors the diffuse scalar value in CAD, used to help combat the darkening effect of multiple texture layers
float g_fLeafLightingAdjust;              // used to clamp the dot product operation during the leaf vertex lighting operations

// other
column_major float4x4 ModelViewProj;                      // composite modelview/projection matrix

//uniform float4      g_vTreePos;                         // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
//uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)

float4 g_vTreeMatrixRow0;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow1;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow2;                      // composite translate/rotation matrix

float g_fTreeScale;                       // each tree has a unique scale (1.0 is no scale)

float2 g_vCameraAngles;                    // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
float4 g_vCameraAzimuthTrig;               // stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs

};
#ifdef INTERMEDIATE_FRONDBRANCH_FADING
cbuffer BranchesVS_CB1 : register(b1)
{
float2 g_vBranchLodValues;                 // .x = current LOD, .y = transition radius
};
#endif

//-----------------------------------------------------------------------------
//	constants
//-----------------------------------------------------------------------------
static const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
static const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
static const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
static const float c_fTwoPi = 6.28318530f;                     // 2 * pi



///////////////////////////////////////////////////////////////////////  
//  Modulate_Float
//
//  Returns x % y (some compilers generate way too many instructions when
//  using the native '%' operator)

float Modulate_Float(float x, float y)
{
    return x - (int(x / y) * y);
}


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
//  LightDiffuse
//
//  Very simple lighting equation, used by the fronds and leaves (branches
//  and billboards are normal mapped).

float3 LightDiffuse(float3 vVertex,
                    float3 vNormal,
                    float3 vLightDir,
                    float3 vLightColor,
                    float3 vDiffuseMaterial)
{
    return vDiffuseMaterial * vLightColor * max(dot(vNormal, vLightDir), 0.0f);
}


#ifdef INTERMEDIATE_FRONDBRANCH_FADING
///////////////////////////////////////////////////////////////////////  
//  ComputeFadeValue

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
//  BranchVS
//
//  Branch geometry vertex shader

SBranchOutput
main(in SBranchInput sInput)
{
    // this will be fed to the branch pixel shader
    SBranchOutput sOutput;

	float4 vPosition	= sInput._vPosition;
	float4 vNormal		= sInput._vNormal;
	float4 vTexCoords1	= sInput._vTexCoords1;
	float4 vTexCoords2	= sInput._vTexCoords2;
	
#ifdef INTERMEDIATE_FRONDBRANCH_FADING
    float4 vTexCoords3	= sInput._vTexCoords3;
#else                
    float3 vTexCoords3	= sInput._vTexCoords3;
#endif

    // define attribute aliases for readability
    float2 vShadowTexCoords = float2(vPosition.w, vNormal.w);
    float2 vDiffuseTexCoords = float2(vTexCoords1.xy);
    float2 vWindParams = float2(vTexCoords1.zw);
    float2 vDetailTexCoords = float2(vTexCoords2.xy);
    float2 vNormalTexCoords = float2(vTexCoords2.zw);
    float3 vTangent = float3(vTexCoords3.xyz);

    // scale the geometry (each tree instance can be uniquely scaled)
    vPosition.xyz *= g_fTreeScale;

    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
	
// #ifdef UPVECTOR_POS_Y
//     vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));
//     vNormal.xz = float2(dot(g_vTreeRotationTrig.ywz, vNormal.xyz), dot(g_vTreeRotationTrig.xwy, vNormal.xyz));
// #else
//     vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));
//     vNormal.xy = float2(dot(g_vTreeRotationTrig.yxw, vNormal.xyz), dot(g_vTreeRotationTrig.zyw, vNormal.xyz));
// #endif
	
	// rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
 	vPosition.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vPosition.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vPosition.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vPosition.xyz));
		
	vNormal.xyz = float3(
		dot(g_vTreeMatrixRow0.xyz, vNormal.xyz), 
		dot(g_vTreeMatrixRow1.xyz, vNormal.xyz),
		dot(g_vTreeMatrixRow2.xyz, vNormal.xyz));

    // compute new position from wind effect - improved lighting accuracy may be achieved by also transforming 
    // the normal, binormal, and tangent by the wind matrix, but this was judged too expensive for the minimal 
    // effect it achieved.
    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);
    
    // translate tree into position (must be done after the rotation)
    //vPosition.xyz += g_vTreePos.xyz;
	vPosition.xyz += float3(g_vTreeMatrixRow0.w, g_vTreeMatrixRow1.w, g_vTreeMatrixRow2.w);


    // project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
    sOutput.vScreenPos = sOutput.vPosition;

#ifdef BRANCH_NORMAL_MAPPING
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
	
	// pass normal tex coords
	sOutput.vNormAndDetailTexCoords.xy = vNormalTexCoords;

#else
    // simple per-vertex lighting (nearly a dozen instructions are still generated, so normal-mapping is about
    // the same expense as far as the vertex shader goes)
    sOutput.vNormal.xyz = LightDiffuse(vPosition.xyz, vNormal.xyz, g_vLightDir.xyz, g_vLightDiffuse.xyz, g_vMaterialDiffuse.xyz);
	sOutput.vNormAndDetailTexCoords.xy = float2(0.0f, 0.0f);
#endif

    // pass through other texcoords exactly as they were received
    sOutput.vDiffuseAndSelfTexCoords.xy = vDiffuseTexCoords.xy;

#ifdef INTERMEDIATE_FRONDBRANCH_FADING
    // compute some fade value (0.0 = transparent, 1.0 = opaque)
    float fLodFadeHint = vTexCoords3.w;
    sOutput.vNormal.w = ComputeFadeValue(fLodFadeHint);
#else
	sOutput.vNormal.w = 0.0f;
#endif

#ifdef BRANCH_DETAIL_LAYER
    sOutput.vNormAndDetailTexCoords.zw = vDetailTexCoords.xy;
#else
	sOutput.vNormAndDetailTexCoords.zw = float2(0.0f, 0.0f);
#endif

#ifdef SELF_SHADOW_LAYER
    // move self-shadow texture coordinates based on wind strength - motion computed on CPU and uploaded
    sOutput.vDiffuseAndSelfTexCoords.zw = vShadowTexCoords + g_vSelfShadowMotion;
#else
	sOutput.vDiffuseAndSelfTexCoords.zw = float2(0.0f, 0.0f);
#endif

    return sOutput;
}


