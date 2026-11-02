// D3D11 port of SpeedTree/DepthBillboardsVS.hlsl. Generated from the legacy HLSL source; see README.md.
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
//	input/output
//----------------------------------------------------------------------------- 

struct SBillboardInput
{
    float4 _vPosition      : POSITION;		// xyz = position, w = corner index
    float4 _vGeom          : TEXCOORD0;		// x = width, y = height, z = tree azimuth, w = lod fade
    float4 _vMiscParams    : TEXCOORD1;		// x = scale, y = texcoord offset, z = num images, w = 360 transition %
    float4 _vLightAdjusts  : TEXCOORD2;		// x = bright side adjustment, y = dark side adjustment, z = ambient scale, w - tree theta
	float4 UpAxis		   : TEXCOORD3;		// xyz - up axis, w - unused
	float4 AxisX		   : TEXCOORD4;		// xyz - up axis, w - unused
};

struct SBillboardOutput
{
    float4  vPosition         : SV_Position;
    float4  vDiffuseTexCoords : TEXCOORD0; // uv1, uv2 for 2 nearest slices    
    float4	ScreenPos		  : TEXCOORD1;	// screen coord
	float2	SliceRatio		  : TEXCOORD2;
};

//----------------------------------------------------------------------------- 
//	uniforms
//----------------------------------------------------------------------------- 

cbuffer DepthBillboardsVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;							// composite modelview/projection matrix
column_major float4x4 ModelView;								// modelview transform				

// lighting & materials
float3 g_vLightDir;							// normalized light direction (shaders assume a single light source)
float3 g_vCameraPos;							// camera position
float2 g_vCameraAngles;						// shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
float4 g_vCameraAzimuthTrig;					// stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs
float g_fSpecialAzimuth;						// camera azimuth, adjusted to speed billboard vs computations


// vs
float4 g_v360TexCoords[NUM_360_IMAGES];		// each element defines the texcoords for a single billboard image - each element has:
															//     x = s-coord (rightmost s-coord of billboard)
															//     y = t-coord (topmost t-coord of billboard) 
															//     z = s-axis width (leftmost s-coord = x - z)
															//     w = t-axis height (bottommost t-coord = y - w)

float4 g_amBBNormals[4];                         // all billboards share the same normals since they all face the camera
float4 g_amBBBinormals[4];                       // all billboards share the same binormals since they all face the camera  
float4 g_amBBTangents[4];                        // all billboards share the same tangents since they all face the camera


//----------------------------------------------------------------------------- 
//	constants
//----------------------------------------------------------------------------- 

};
static const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
static const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
static const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
static const float c_fTwoPi = 6.28318530f;                     // 2 * pi

static const float4      g_afTexCoordScales[4] =				// used to compress & optimize the g_v360TexCoord lookups (x = s scale, y = t scale)
            { 
                float4(0.0f, 0.0f, 0.0f, 0.0f), 
                float4(1.0f, 0.0f, 0.0f, 0.0f), 
                float4(1.0f, 1.0f, 0.0f, 0.0f), 
                float4(0.0f, 1.0f, 0.0f, 0.0f) 
            };
static const float4		g_mBBUnitSquare[4] =                        // unit billboard card that's turned towards the camera.  card is aligned on 
            {														// YZ plane and centered at (0.0f, 0.0f, 0.5f)
                float4(0.0f, 0.5f, 1.0f, 0.0f), 
                float4(0.0f, -0.5f, 1.0f, 0.0f), 
                float4(0.0f, -0.5f, 0.0f, 0.0f), 
                float4(0.0f, 0.5f, 0.0f, 0.0f) 
            };



//-----------------------------------------------------------------------------
//  Modulate_Float
//
//  Returns x % y (some compilers generate way too many instructions when
//  using the native '%' operator)
//-----------------------------------------------------------------------------

float Modulate_Float(float x, float y)
{
    return x - (int(x / y) * y);
	//return frac(x/y);
}

//-----------------------------------------------------------------------------
//  Billboard1VS
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
//  Billboard1VS
//
//  In order to ensure smooth LOD transitions, two billboards are rendered
//  per tree instance.  Each billboard represents a partially faded rendering
//  of the two closest billboard images for the current camera azimuth and
//  current tree instance rotation.
//
//  Separate shaders are necessary because since different equations are used
//  to pick the billboard index and fade values for the two bb's.

SBillboardOutput 
main (in SBillboardInput sInput)
{
    // this will be fed to the billboard pixel shader
    SBillboardOutput sOutput;
    
	float4 vPosition				= sInput._vPosition;
	float4 vGeom					= sInput._vGeom;
	float4 vMiscParams				= sInput._vMiscParams;
	float3 vLightAdjusts			= sInput._vLightAdjusts.xyz;

    // define attribute aliases for readability
    float fAzimuth					= g_vCameraAngles.x;			// current camera azimuth
    float fPitch					= g_vCameraAngles.y;			// current camera pitch
    int nCorner						= vPosition.w;					// which card corner this vertex represents [0,3]
    int image_count					= vMiscParams.z;				// # of 360-degree images

    float c_fSliceDiameter			= c_fTwoPi / float(image_count); // diameter = 360 / g_nNum360Images
    float c_fLodFade				= vGeom.w;						// computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale				= vMiscParams.x;				// uniform scale of tree instance
    float c_fTransitionPercentage	= vMiscParams.w;				// controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset		= vMiscParams.y;				// offset into g_v360TexCoords where this instance's texcoords begin

	float tree_phi = sInput._vGeom.z;
	//float tree_theta = sInput._vLightAdjusts.w;
    
	float3 spr2cam = g_vCameraPos.xyz - vPosition.xyz;

	// sprite world axiz
	float3 tree_axis_z = sInput.UpAxis.xyz;
	float3 tree_axis_x = sInput.AxisX.xyz; // float3(cos(tree_phi), sin(tree_phi), 0.0);
	float3 tree_axis_y = normalize(cross(tree_axis_z, tree_axis_x));
	//tree_axis_x = cross(tree_axis_y, tree_axis_z);

	float2 view_dir = -float2(dot(spr2cam,tree_axis_x), dot(spr2cam, tree_axis_y));
	
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)
    
    // modify the adjusted azimuth to appear in range [0,2*pi]
	float view_azimuth = c_fTwoPi + atan2(view_dir.y, view_dir.x);
	if (view_azimuth > c_fTwoPi) view_azimuth -= c_fTwoPi;

    // pick the billboard image index and access the extract texcoords from the table
	int slice = (int)(view_azimuth / c_fSliceDiameter);
	float slice_ratio = (view_azimuth - slice*c_fSliceDiameter)/c_fSliceDiameter;

    int image_index0 = slice;
    if (image_index0 > image_count - 1)
	{
        image_index0 = 0;
	}

	// pick the billboard image index and access the extract texcoords from the table
    int image_index1 = slice + 1;
    if (image_index1 > image_count - 1)
	{
        image_index1 = 0;
	}

	
	//float3 axis_y = sInput.UpAxis.xyz; // float3(-cos(tree_phi)*sin(tree_theta), -sin(tree_phi)*sin(tree_theta), cos(tree_theta));
	//float3 axis_x = normalize(cross(axis_y, spr2cam));

	float3 sprite_axis_y = sInput.UpAxis.xyz; // float3(-cos(tree_phi)*sin(tree_theta), -sin(tree_phi)*sin(tree_theta), cos(tree_theta));
	float3 sprite_axis_x = normalize(cross(sprite_axis_y, spr2cam));

    // determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
	// first slice
    float4 vTexCoords = g_v360TexCoords[image_index0 + nTexCoordTableOffset];
    sOutput.vDiffuseTexCoords.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vDiffuseTexCoords.y = 1 - (vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y);
    //sOutput.vNormalTexCoords.xy = sOutput.vDiffuseTexCoords;

	// second slice
	vTexCoords = g_v360TexCoords[image_index1 + nTexCoordTableOffset];
    sOutput.vDiffuseTexCoords.z = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vDiffuseTexCoords.w = 1 - (vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y);
   // sOutput.vNormalTexCoords.zw = sOutput.vDiffuseTexCoords;

    // compute the alpha fade value
	// return x - (int(x / y) * y);
#ifdef SUPPORT_360_BILLBOARDS
    //float fAlpha0 = 1.0f - Modulate_Float(fAdjustedAzimuth, c_fSliceDiameter) / c_fSliceDiameter;
	float fAlpha0 = 1.0f - Modulate_Float(view_azimuth, c_fSliceDiameter) / c_fSliceDiameter;
#else
    float fAlpha0 = 0.0f; // g_fSpecialAzimuth/(c_fSliceDiameter*vMiscParams.z); // 0.0f;
#endif

    float fFadePoint = c_fLodFade; // lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);

    // 4.0
    fAlpha0 = lerp(fFadePoint, c_fClearAlpha, pow(fAlpha0, 1.7));
    
    // 4.1 (helps reduce a too-faded look)
    //fAlpha0 = max(fAlpha0, c_fTransitionPercentage);
    //fAlpha0 = lerp(fFadePoint, c_fClearAlpha, pow( (fAlpha0 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha0 = 1.0f - (fAlpha0 - c_fOpaqueAlpha) / c_fAlphaSpread;
	fAlpha0 = slice_ratio;

    // multiply by the correct corner
	float3 vecCorner = g_mBBUnitSquare[nCorner].y*vGeom.x*sprite_axis_x + g_mBBUnitSquare[nCorner].z*vGeom.y*sprite_axis_y;
    vPosition.xyz += c_fTreeScale *  vecCorner.xyz;
    vPosition.w = 1.0f;
    
    
    // project to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
	sOutput.ScreenPos = mul(ModelView, float4(vPosition.xyz, 1.0f));
    sOutput.SliceRatio.x = slice_ratio;
	sOutput.SliceRatio.y = fFadePoint;

    return sOutput;
}
