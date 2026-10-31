
//-----------------------------------------------------------------------------
//	SFrondOutput
//-----------------------------------------------------------------------------

struct SFrondOutput
{
    float2  vDiffuseTexCoords			: TEXCOORD0;
	float4  zCoord						: TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

uniform sampler2D	samCompositeDiffuseLeafMap	: register(s0);



//-----------------------------------------------------------------------------
//  FrondPS
//
//  Frond geometry pixel shader.  This shader can process up to two texture layers:
//      - diffuse composite leaf/frond map
//      - self-shadow map (greyscale composite map generated via SpeedTreeCAD)
//-----------------------------------------------------------------------------

float4
main(SFrondOutput In) : COLOR
{	
	float2 dsdx = float2(0, 0);
	float2 dsdy = float2(0, 0);

    // look up the diffuse layer
    float4 texDiffuse = tex2D(samCompositeDiffuseLeafMap, float2(In.vDiffuseTexCoords.x, 1.0 - In.vDiffuseTexCoords.y)); // ,

	float fade = 1.0;

#ifdef INTERMEDIATE_FRONDBRANCH_FADING
    fade = In.vNormal.w;
#endif

    if (texDiffuse.a <= 85.0/255.0)
	{
		discard;
	}


  
#ifdef DEPTH_PASS
	float rz = -In.zCoord.z;
#else
	float rz = -0.001 * In.zCoord.z;
#endif

    return float4(rz, 0, 0, 1);
}
