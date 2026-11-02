// D3D11 port of SpeedTree/DepthFrondsVS.hlsl. Generated from the legacy HLSL source; see README.md.
#include "../SpeedTreeDefaults.hlsli"

//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SFrondInput
{
	float4	_vPosition   : POSITION;
	float4	_vNormal     : TEXCOORD0;
	float4	_vTexCoords1 : TEXCOORD1;

#if defined(INTERMEDIATE_FRONDBRANCH_FADING) || defined(FROND_NORMAL_MAPPING)
	float4	_vMisc       : TEXCOORD2;
#endif

};

struct SFrondOutput
{
    float2  vDiffuseTexCoords			: TEXCOORD0;
    float4  zCoord						: TEXCOORD1;
    float4  vPosition					: SV_Position;
};

//-----------------------------------------------------------------------------
//	uniform
//-----------------------------------------------------------------------------

// wind 
cbuffer DepthFrondsVS_CB0 : register(b0)
{
float g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
column_major float4x4 g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types

};
#ifdef INTERMEDIATE_FRONDBRANCH_FADING
cbuffer DepthFrondsVS_CB1 : register(b1)
{
	float2 g_vBranchLodValues;                 // .x = current LOD, .y = transition radius
};
#endif


// other
cbuffer DepthFrondsVS_CB2 : register(b2)
{
column_major float4x4 ModelViewProj;                    // composite modelview/projection matrix
column_major float4x4 ModelView;


//uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
//uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)

float4 g_vTreeMatrixRow0;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow1;                      // composite translate/rotation matrix
float4 g_vTreeMatrixRow2;                      // composite translate/rotation matrix

float g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)

//-----------------------------------------------------------------------------
// constants
//-----------------------------------------------------------------------------

};
static const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
static const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
static const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
static const float c_fTwoPi = 6.28318530f;                     // 2 * pi


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

//-----------------------------------------------------------------------------
//  ComputeFadeValue
//-----------------------------------------------------------------------------

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
#endif




//-----------------------------------------------------------------------------
//  FrondVS
//
//  Frond geometry vertex shader
//-----------------------------------------------------------------------------

SFrondOutput main(in SFrondInput sInput)
{
    // this will be fed to the frond pixel shader
    SFrondOutput sOutput;

	float4 vPosition	= sInput._vPosition;
	float4 vNormal		= sInput._vNormal;
	float4 vTexCoords1	= sInput._vTexCoords1;

#if defined(INTERMEDIATE_FRONDBRANCH_FADING) || defined(FROND_NORMAL_MAPPING)
	float4 vMisc		= sInput._vMisc;
#endif

    // define attribute aliases for readability
    float2 vDiffuseTexCoords	= float2(vTexCoords1.x, vTexCoords1.y);
    float2 vWindParams			= float2(vTexCoords1.zw);
    
    // scale the geometry (each tree instance can be uniquely scaled)
    vPosition.xyz *= g_fTreeScale;
    
    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
// #ifdef UPVECTOR_POS_Y
//     vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));
//     //vNormal.xz = float2(dot(g_vTreeRotationTrig.ywz, vNormal.xyz), dot(g_vTreeRotationTrig.xwy, vNormal.xyz));
// #else
//     vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));
//     //vNormal.xy = float2(dot(g_vTreeRotationTrig.yxw, vNormal.xyz), dot(g_vTreeRotationTrig.zyw, vNormal.xyz));
// #endif
    vPosition.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vPosition.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vPosition.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vPosition.xyz));

    // compute new position from wind effect
    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);
    
    // translate tree into position (must be done after the rotation)
    //vPosition.xyz += g_vTreePos.xyz;
	vPosition.xyz += float3(g_vTreeMatrixRow0.w, g_vTreeMatrixRow1.w, g_vTreeMatrixRow2.w);

	// project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
	sOutput.zCoord = mul(ModelView, float4(vPosition.xyz, 1.0f));
  
	// pass through other texcoords exactly as they were received
    sOutput.vDiffuseTexCoords.xy = vDiffuseTexCoords.xy;

// #ifdef INTERMEDIATE_FRONDBRANCH_FADING
//     float fLodFadeHint = vMisc.w;
//     sOutput.vNormal.w = ComputeFadeValue(fLodFadeHint);
// #else
// 	sOutput.vNormal.w = 0.0f;
// #endif

	return sOutput;
}