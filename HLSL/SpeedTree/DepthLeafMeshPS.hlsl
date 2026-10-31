
#define IDV_OPENGL

//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SLeafOutput
{
    float4 vPosition		: POSITION;
    float2 vBaseTexCoords	: TEXCOORD0;
	float4 zCoord			: TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

uniform sampler2D samCompositeDiffuseLeafMap	: register(s0);



//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

//
//  Leaf geometry pixel shader, shared by both leaf cards and mshes.  This 
//  shader processes only one layer:
//      - diffuse composite leaf/frond map
//
//  There is no self-shadow layer used in the leaf geometry.

float4 
main (SLeafOutput In) : COLOR
{
    // look up the diffuse layer
    float4 texDiffuse =  tex2D(samCompositeDiffuseLeafMap, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y)); 

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


