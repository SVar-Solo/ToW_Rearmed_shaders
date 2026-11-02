// D3D11 port of SpeedTree/DepthBranchesFASTPS.hlsl. Generated from the legacy HLSL source; see README.md.
#include "../SpeedTreeDefaults.hlsli"
//-----------------------------------------------------------------------------
//	input/output
//-----------------------------------------------------------------------------

struct SBranchOutput
{
    float2  vDiffuseTexCoords			: TEXCOORD0;	// Diffuse + SelfShadow
	float   vFade						: TEXCOORD1;	// xyz normal, w - INTERMEDIATE_FRONDBRANCH_FADING
	float4	zCoord						: TEXCOORD2;
};

//-----------------------------------------------------------------------------
//	uniform
//-----------------------------------------------------------------------------

Texture2D samBranchDiffuseMap : register(t0);
SamplerState samBranchDiffuseMap_Sampler : register(s0);


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(in SBranchOutput In) : SV_Target0
{
    // look up the diffuse map layer
    //float4 texDiffuse = tex2D(samBranchDiffuseMap, float2(In.vDiffuseTexCoords.x, 1.0 - In.vDiffuseTexCoords.y));

	//if (texDiffuse.a < 0.3)
	{
		// discard;
	}

#ifdef DEPTH_PASS
	float rz = -In.zCoord.z;
#else
	float rz = -0.001 * In.zCoord.z;
#endif

		
	return float4(rz, 0.0, 0.0, 1.0);
}


