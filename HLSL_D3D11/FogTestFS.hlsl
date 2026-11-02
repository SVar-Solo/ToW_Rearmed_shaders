// D3D11 port of FogTestFS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct vfconn
{
	float4 Color0    : COLOR0;
	float3 fogCoord : TEXCOORD0;
};

cbuffer FogTestFS_CB0 : register(b0)
{
float fSkyMultiplier;
};
TextureCube SkyMap : register(t0);
SamplerState SkyMap_Sampler : register(s0); // Base texture

float4 main(in vfconn IN // From vertex shader
			) : SV_Target0
{
	// Base
	float4 decalColor = SkyMap.Sample(SkyMap_Sampler, IN.fogCoord);
	decalColor.rgb = lerp(decalColor.rgb, decalColor.rgb*fSkyMultiplier, decalColor.a);	
	return float4(decalColor.xyz,IN.Color0.a);
}


