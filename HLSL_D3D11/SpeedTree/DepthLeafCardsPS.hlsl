// D3D11 port of SpeedTree/DepthLeafCardsPS.hlsl. Generated from the legacy HLSL source; see README.md.
#include "../SpeedTreeDefaults.hlsli"

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

Texture2D samCompositeDiffuseLeafMap : register(t0);
SamplerState samCompositeDiffuseLeafMap_Sampler : register(s0); 
cbuffer DepthLeafCardsPS_CB0 : register(b0)
{
float g_fAlphaRef;

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

};
float4 
main (SLeafOutput In) : SV_Target0
{
    // look up the diffuse layer
    float4 texDiffuse =  samCompositeDiffuseLeafMap.Sample(samCompositeDiffuseLeafMap_Sampler, float2(In.vBaseTexCoords.x, 1.0f - In.vBaseTexCoords.y)); 

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


