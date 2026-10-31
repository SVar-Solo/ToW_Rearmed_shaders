
//-----------------------------------------------------------------------------
//	input
//-----------------------------------------------------------------------------

struct SLeafOutput
{
    float2 vBaseTexCoords	: TEXCOORD0;
	float4 zCoord			: TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	global parameters
//-----------------------------------------------------------------------------

uniform sampler2D samCompositeDiffuseLeafMap : register(s0); 
uniform float g_fAlphaRef;

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

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


