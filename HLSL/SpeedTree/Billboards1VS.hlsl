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
    float3 _vLightAdjusts  : TEXCOORD2;		// x = bright side adjustment, y = dark side adjustment, z = ambient scale
};

struct SBillboardOutput
{
    float4  vPosition         : POSITION;
    float2  vDiffuseTexCoords : TEXCOORD0;
    float2  vNormalTexCoords  : TEXCOORD1;
#ifdef BILLBOARD_NORMAL_MAPPING
    float4  vNormal           : TEXCOORD2;
#else
    float   fNormal           : TEXCOORD2;
#endif

    float3  vLightAdjusts     : TEXCOORD3;
	float4	vScreenPos		  : TEXCOORD4;	// screen coord
};

//----------------------------------------------------------------------------- 
//	uniforms
//----------------------------------------------------------------------------- 

// wind 
uniform float       g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
uniform float4x4    g_amWindMatrices[MAX_NUM_LEAF_ANGLES];	// houses all of the wind matrices shared by all geometry types

// lighting & materials
uniform float3      g_vLightDir;                         // normalized light direction (shaders assume a single light source)
//uniform float3      g_vLightDiffuse;                    // light's diffuse color

// other
uniform float4x4    ModelViewProj;                    // composite modelview/projection matrix

uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)
uniform float       g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)
uniform float2      g_vCameraAngles;                     // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
uniform float4      g_vCameraAzimuthTrig;               // stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs

// vs
uniform float4      g_v360TexCoords[NUM_360_IMAGES]; // each element defines the texcoords for a single billboard image - each element has:
                                                     //     x = s-coord (rightmost s-coord of billboard)
                                                     //     y = t-coord (topmost t-coord of billboard) 
                                                     //     z = s-axis width (leftmost s-coord = x - z)
                                                     //     w = t-axis height (bottommost t-coord = y - w)
uniform float       g_fSpecialAzimuth;                       // camera azimuth, adjusted to speed billboard vs computations
/*
uniform float4x4    g_amBBNormals;                           // all billboards share the same normals since they all face the camera
uniform float4x4    g_amBBBinormals;                         // all billboards share the same binormals since they all face the camera  
uniform float4x4    g_amBBTangents;                          // all billboards share the same tangents since they all face the camera
*/

uniform float4    g_amBBNormals[4];                           // all billboards share the same normals since they all face the camera
uniform float4    g_amBBBinormals[4];                         // all billboards share the same binormals since they all face the camera  
uniform float4    g_amBBTangents[4];                          // all billboards share the same tangents since they all face the camera

//-----------------------------------------------------------------------------
// constants
//-----------------------------------------------------------------------------


static const  float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
static const  float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
static const  float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
static const  float c_fTwoPi = 6.28318530f;                     // 2 * pi


static const  float4		g_mBBUnitSquare[4] =                        // unit billboard card that's turned towards the camera.  card is aligned on 
            {                                        // YZ plane and centered at (0.0f, 0.0f, 0.5f)
                float4(0.0f, 0.5f, 1.0f, 0.0f), 
                float4(0.0f, -0.5f, 1.0f, 0.0f), 
                float4(0.0f, -0.5f, 0.0f, 0.0f), 
                float4(0.0f, 0.5f, 0.0f, 0.0f) 
            };

static const  float4    g_afTexCoordScales[4] =                     // used to compress & optimize the g_v360TexCoord lookups (x = s scale, y = t scale)
            { 
                float4(0.0f, 0.0f, 0.0f, 0.0f), 
                float4(1.0f, 0.0f, 0.0f, 0.0f), 
                float4(1.0f, 1.0f, 0.0f, 0.0f), 
                float4(0.0f, 1.0f, 0.0f, 0.0f) 
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

///////////////////////////////////////////////////////////////////////  
//  Billboard2VS
//
//  In order to ensure smooth LOD transitions, two billboards are rendered
//  per tree instance.  Each billboard represents a partially faded rendering
//  of the two closest billboard images for the current camera azimuth and
//  current tree instance rotation.
//
//  Separate shaders are necessary because since different equations are used
//  to pick the billboard index and fade values for the two bb's.

SBillboardOutput main (in SBillboardInput sInput)
{
    // this will be fed to the billboard pixel shader
    SBillboardOutput sOutput;

	float4 vPosition				= sInput._vPosition;
	float4 vGeom					= sInput._vGeom;
	float4 vMiscParams				= sInput._vMiscParams;
	float3 vLightAdjusts			= sInput._vLightAdjusts;
    
    // define attribute aliases for readability
    float fAzimuth					= g_vCameraAngles.x;			// current camera azimuth
    float fPitch					= g_vCameraAngles.y;			// current camera pitch
    int nCorner						= vPosition.w;                  // which card corner this vertex represents [0,3]
    int nNumImages					= vMiscParams.z;				// # of 360-degree images

    float c_fSliceDiameter			= c_fTwoPi / float(nNumImages); // diameter = 360 / g_nNum360Images
    float c_fLodFade				= vGeom.w;						// computed on CPU - the amount the billboard as a whole is faded from 3D geometry
    float c_fTreeScale				= vMiscParams.x;				// uniform scale of tree instance
    float c_fTransitionPercentage	= vMiscParams.w;				// controls how thick or thin the 360-degree image transition is 
    int nTexCoordTableOffset		= vMiscParams.y;				// offset into g_v360TexCoords where this instance's texcoords begin
    
    // there are two azimuth values to consider:
    //    1) fAzimuth: the azimuth of the camera position
    //    2) fAdjustedAzimuth: the azimuth of the camera plus the orientation of the tree the billboard 
    //                         represents (used to determine which bb image to use and its alpha value)

    // modify the adjusted azimuth to appear in range [0,2*pi]
    float fAdjustedAzimuth = g_fSpecialAzimuth - vGeom.z;
    if (fAdjustedAzimuth < 0.0f)			fAdjustedAzimuth += c_fTwoPi;
    else if (fAdjustedAzimuth > c_fTwoPi)	fAdjustedAzimuth -= c_fTwoPi;
    
    // pick the billboard image index and access the extract texcoords from the table
    int nIndex1 = int(fAdjustedAzimuth / c_fSliceDiameter);
    if (nIndex1 > nNumImages - 1)
	{
        nIndex1 = 0;
	}
        
    // determine texcoords based on corner position - while not a straighforward method for determining the texcoords
    // for a specific corner, this one provided a good compromise of speed and space
    float4 vTexCoords = g_v360TexCoords[nIndex1 + nTexCoordTableOffset];
    sOutput.vDiffuseTexCoords.x = vTexCoords.x - vTexCoords.z * g_afTexCoordScales[nCorner].x;
    sOutput.vDiffuseTexCoords.y = 1 - (vTexCoords.y - vTexCoords.w * g_afTexCoordScales[nCorner].y);
    sOutput.vNormalTexCoords = sOutput.vDiffuseTexCoords;
  
    // compute the alpha fade value
#ifdef SUPPORT_360_BILLBOARDS
    //float fAlpha1 = (fAdjustedAzimuth - (nIndex1 * c_fSliceDiameter)) / c_fSliceDiameter;
	float fAlpha1 = Modulate_Float(fAdjustedAzimuth, c_fSliceDiameter) / c_fSliceDiameter;
#else
    float fAlpha1 = 0.0f;
#endif

    float fFadePoint = lerp(c_fClearAlpha, c_fOpaqueAlpha, c_fLodFade);

    // 4.0
    fAlpha1 = lerp(fFadePoint, c_fClearAlpha, pow(fAlpha1, 1.7));
    
    // 4.1 (helps reduce a too-faded look)
    //fAlpha1 = max(fAlpha1, c_fTransitionPercentage);
    //fAlpha1 = lerp(fFadePoint, c_fClearAlpha, pow( (fAlpha1 - c_fTransitionPercentage) / (1.0f - c_fTransitionPercentage), 1.7f));
    
    // each billboard may be faded at a distinct value, but it isn't efficient to change
    // the alpha test value per billboard.  instead we adjust the alpha value of the 
    // billboards's outgoing color to achieve the same effect against a static alpha test 
    // value (c_gOpaqueAlpha).
    fAlpha1 = 1.0f - (fAlpha1 - c_fOpaqueAlpha) / c_fAlphaSpread;

    // multiply by the correct corner
#ifdef UPVECTOR_POS_Y
	float3 vecCorner = g_mBBUnitSquare[nCorner].xzy * vGeom.xyx;
#else
    float3 vecCorner = g_mBBUnitSquare[nCorner].xyz * vGeom.xxy;
#endif

    // apply rotation to scaled corner
#ifdef UPVECTOR_POS_Y
    vecCorner.xz = float2(dot(g_vCameraAzimuthTrig.ywz, vecCorner.xyz), dot(g_vCameraAzimuthTrig.xwy, vecCorner.xyz));
#else
    vecCorner.xy = float2(dot(g_vCameraAzimuthTrig.yxw, vecCorner.xyz), dot(g_vCameraAzimuthTrig.zyw, vecCorner.xyz));
#endif
    
	vPosition.xyz += c_fTreeScale * vecCorner;
    vPosition.w = 1.0f;
    
#ifdef BILLBOARD_NORMAL_MAPPING
    // setup per-pixel normal mapping  (assumes normalized light direction)

    // 0.5f + 0.5f * expr not used since texcoords aren't clamped to [0,1] range - this approach saves
    // several instructions	
    sOutput.vNormal.x = dot(g_vLightDir.xyz, g_amBBTangents[nCorner].xyz);
    sOutput.vNormal.y = dot(g_vLightDir.xyz, g_amBBBinormals[nCorner].xyz);
    sOutput.vNormal.z = dot(g_vLightDir.xyz, g_amBBNormals[nCorner].xyz);
    sOutput.vNormal.w = fAlpha1;
#else
    sOutput.fNormal = fAlpha1;
#endif

    // project to the screen
    sOutput.vPosition = mul(ModelViewProj, vPosition);
    sOutput.vScreenPos = sOutput.vPosition;

    // pass through light adjustments
    sOutput.vLightAdjusts.xyz = vLightAdjusts.xyz;

    return sOutput;
}
