
#define IDV_OPENGL

//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

// input
struct SLeafInput
{
	float4   _vPosition  : POSITION;  // xyz = position, w = corner index	
	float3   _vNormal    : NORMAL;
	float4   _vTexCoord0 : TEXCOORD0; // xy = diffuse texcoords, zw = compressed wind parameters
	float4   _vTexCoord1 : TEXCOORD1; // .x = width, .y = height, .z = pivot x, .w = pivot.y
	float4   _vTexCoord2 : TEXCOORD2; // .x = angle.x, .y = angle.y, .z = wind angle index, .w = dimming
	float3   _vTangent   : TEXCOORD3;
};

// output
struct SLeafOutput
{
    float4 vPosition		: POSITION;
    float2 vBaseTexCoords	: TEXCOORD0;
	float4 zCoord			: TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	uniform
//-----------------------------------------------------------------------------

// wind 
uniform float       g_fWindMatrixOffset;					// keeps two instances of the same tree model from using the same wind matrix (range: [0,NUM_WIND_MATRICES])
uniform float4x4    g_amWindMatrices[NUM_WIND_MATRICES];	// houses all of the wind matrices shared by all geometry types


// other
uniform float4x4    ModelViewProj;	// composite modelview/projection matrix
uniform float4x4	ModelView;		// modelview transform				

//uniform float4      g_vTreePos;                          // each tree is in a unique position and rotation: .xyz = pos, .w = rotation
//uniform float4      g_vTreeRotationTrig;                // stores (sin, cos, -sin, 0.0) for an instance's rotation angle (optimizes rotation code)

uniform float4		g_vTreeMatrixRow0;                      // composite translate/rotation matrix
uniform float4		g_vTreeMatrixRow1;                      // composite translate/rotation matrix
uniform float4		g_vTreeMatrixRow2;                      // composite translate/rotation matrix

uniform float       g_fTreeScale;                        // each tree has a unique scale (1.0 is no scale)
uniform float2      g_vCameraAngles;                     // shared by Billboard.fx and Leaf.fx - stores camera azimuth and pitch for billboarding computations
//uniform float4      g_vCameraAzimuthTrig;               // stores (sin, cos, -sin, 0.0) for the camera azimuth angle for optimized rotation in billboard vs


// constants
const float c_fClearAlpha = 255.0f;                     // alpha testing, 255 means not visible
const float c_fOpaqueAlpha = 84.0f;                     // alpha testing, 84 means fully visible
const float c_fAlphaSpread = 171.0f;                    // 171 = 255 - 84
const float c_fTwoPi = 6.28318530f;                     // 2 * pi


///////////////////////////////////////////////////////////////////////  
//  Leaf-specific global variables

// vs
uniform float4      g_avLeafAngles[MAX_NUM_LEAF_ANGLES];	// each element: .x = rock angle, .y = rustle angle
															// each element is a float4, even though only a float2 is needed, to facilitate
															// fast uploads on all platforms (one call to upload whole array)
uniform float4      g_vLeafAngleScalars;					// each tree model has unique scalar values: .x = rock scalar, .y = rustle scalar



static const float4      g_mLeafUnitSquare[4] =							// unit leaf card that's turned towards the camera and wind-rocked/rustled by the
            {												// vertex shader.  card is aligned on YZ plane and centered at (0.0f, 0.0f, 0.0f)
                float4(0.0f, 0.5f, 0.5f, 0.0f), 
                float4(0.0f, -0.5f, 0.5f, 0.0f), 
                float4(0.0f, -0.5f, -0.5f, 0.0f), 
                float4(0.0f, 0.5f, -0.5f, 0.0f)
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
//  LeafCardVS
//
//  Leaf card geometry vertex shader

SLeafOutput main (in SLeafInput sInput)
{
    // this will be fed to the leaf pixel shader
    SLeafOutput sOutput;
    
	float4   vPosition  = sInput._vPosition;
	float4   vTexCoord0 = sInput._vTexCoord0;
	float4   vTexCoord1 = sInput._vTexCoord1;
	float4   vTexCoord2 = sInput._vTexCoord2;

    // define attribute aliases for readability
    float fAzimuth = g_vCameraAngles.x;      // camera azimuth for billboarding
    float fPitch = g_vCameraAngles.y;        // camera pitch for billboarding
    float2 vSize = vTexCoord1.xy;            // leaf card width & height
    int nCorner =  vPosition.w;				// which card corner this vertex represents [0,3]
    float fRotAngleX = vTexCoord2.x;         // angle offset for leaf rocking (helps make it distinct)
    float fRotAngleY = vTexCoord2.y;         // angle offset for leaf rustling (helps make it distinct)
    float fWindAngleIndex = vTexCoord2.z;    // which wind matrix this leaf card will follow
    float2 vPivotPoint = vTexCoord1.zw;      // point about which card will rock and rustle
    float fDimming = vTexCoord2.w;           // interior leaves are darker (range = [0.0,1.0])
    float2 vWindParams = vTexCoord0.zw;      // compressed wind parameters

	vPosition.w = 1.0f;

    // rotate the whole tree (each tree instance can be uniquely rotated) - use optimized z-axis rotation
    // algorithm where float(sin(a), cos(a), -sin(a), 0.0f) is uploaded instead of angle a
// #ifdef UPVECTOR_POS_Y
//     vPosition.xz = float2(dot(g_vTreeRotationTrig.ywz, vPosition.xyz), dot(g_vTreeRotationTrig.xwy, vPosition.xyz));
// #else
//     vPosition.xy = float2(dot(g_vTreeRotationTrig.yxw, vPosition.xyz), dot(g_vTreeRotationTrig.zyw, vPosition.xyz));
// #endif
    
	vPosition.xyz = float3(
 		dot(g_vTreeMatrixRow0.xyz, vPosition.xyz), 
 		dot(g_vTreeMatrixRow1.xyz, vPosition.xyz),
 		dot(g_vTreeMatrixRow2.xyz, vPosition.xyz));

    // compute new position from wind effect
    vPosition.xyz = WindEffect(vPosition.xyz, vWindParams);
    
    // compute rock and rustle values (all trees share the g_avLeafAngles table, but each can be scaled uniquely)
    float2 vLeafRockAndRustle = g_vLeafAngleScalars.xy * g_avLeafAngles[fWindAngleIndex].xy;
    
    // access g_mLeafUnitSquare matrix with corner index and apply scales
#ifdef UPVECTOR_POS_Y
    float3 vPivotedPoint = g_mLeafUnitSquare[nCorner].xzy;
#else
    float3 vPivotedPoint = g_mLeafUnitSquare[nCorner].xyz;
#endif

    // adjust by pivot point so rotation occurs around the correct point
    vPivotedPoint.yz += vPivotPoint;
#ifdef UPVECTOR_POS_Y
    float3 vCorner = vPivotedPoint * vSize.xyx;
#else
    float3 vCorner = vPivotedPoint * vSize.xxy;
#endif

    // rock & rustling on the card corner
    // * note: The bulk of the LeafCardVS instructions come from this section of code. Please use the
    //         code commented out just below this block if you want a quick and dirty approximation
    //         of the wind as tuned in CAD as opposed to this 100% faithful implementation.  Using the
    //         shorter code reduces the compiled shader length by ~25%.
    //      
	/*
#ifdef UPVECTOR_POS_Y
    float3x3 matRotation = RotationMatrix_yAxis(fAzimuth + fRotAngleX);
    matRotation = mul(matRotation, RotationMatrix_zAxis(fPitch + fRotAngleY));
    matRotation = mul(matRotation, RotationMatrix_yAxis(-vLeafRockAndRustle.y));
    matRotation = mul(matRotation, RotationMatrix_xAxis(vLeafRockAndRustle.x));
#else
    float3x3 matRotation = RotationMatrix_zAxis(fAzimuth + fRotAngleX);
    matRotation = mul(matRotation, RotationMatrix_yAxis(fPitch + fRotAngleY));
    matRotation = mul(matRotation, RotationMatrix_zAxis(vLeafRockAndRustle.y));
    matRotation = mul(matRotation, RotationMatrix_xAxis(vLeafRockAndRustle.x));
#endif
	*/

    // quick & dirty rock/rustle code
    #ifdef UPVECTOR_POS_Y
        float3x3 matRotation = RotationMatrix_yAxis(fAzimuth + fRotAngleX + vLeafRockAndRustle.y);
        matRotation = mul(matRotation, RotationMatrix_zAxis(fPitch + fRotAngleY + vLeafRockAndRustle.x));
    #else
        float3x3 matRotation = RotationMatrix_zAxis(fAzimuth + fRotAngleX);
        matRotation = mul(matRotation, RotationMatrix_yAxis(fPitch + fRotAngleY));
        matRotation = mul(matRotation, RotationMatrix_zAxis(vLeafRockAndRustle.y));
        matRotation = mul(matRotation, RotationMatrix_xAxis(vLeafRockAndRustle.x));
    #endif
        

	//float3x3 matRotation = float3x3(1.0f, 0.0f, 0.0f,
	//								0.0f, 1.0f, 0.0f,
	//								0.0f, 0.0f, 1.0f);

    vCorner = mul(matRotation, vCorner);
    
    // place and scale the leaf card
    vPosition.xyz += vCorner;
    vPosition.xyz *= g_fTreeScale;


    // translate tree into position (must be done after the rotation)
    // vPosition.xyz += g_vTreePos.xyz;
	vPosition.xyz += float3(g_vTreeMatrixRow0.w, g_vTreeMatrixRow1.w, g_vTreeMatrixRow2.w);

    // project position to the screen
    sOutput.vPosition = mul(ModelViewProj, float4(vPosition.xyz, 1.0f));
	sOutput.zCoord = mul(ModelView, float4(vPosition.xyz, 1.0f));
    
    // pass through other texcoords exactly as they were received
    sOutput.vBaseTexCoords.xy = vTexCoord0.xy;

    return sOutput;
}
