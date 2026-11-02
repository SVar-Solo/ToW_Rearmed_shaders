// D3D11 port of SunPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2 TEX0 : TEXCOORD0;
	float4 color : TEXCOORD1;
};

Texture2D DiffuseMap : register(t0);
SamplerState DiffuseMap_Sampler : register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float4 decalColor = DiffuseMap.Sample(DiffuseMap_Sampler, IN.TEX0) * IN.color;
	return float4(decalColor.rgb*decalColor.a, decalColor.a);
}


