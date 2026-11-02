// D3D11 port of SkyCubePS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float3 TEX0 : TEXCOORD0;
};

static const float3 LUMINANCE_WEIGHT = float3( 0.299f, 0.587f, 0.114f );
TextureCube SkyMap : register(t0);
SamplerState SkyMap_Sampler : register(s0); // Base texture
cbuffer SkyCubePS_CB0 : register(b0)
{
float fSkyMultiplier;

};
float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float3 texcoord = normalize(IN.TEX0.xyz);
	float4 decalColor = SkyMap.Sample(SkyMap_Sampler, texcoord);
	//float lum = dot(decalColor, LUMINANCE_WEIGHT);
	//decalColor.rgb *= 1+lum;
	//return float4(1,0,0,1);//decalColor;
	//decalColor.rgb = decalColor.rgb * lerp(1.0, fSkyMultiplier, decalColor.a);
	//decalColor.rgb = decalColor.aaa;
	return float4(decalColor.rgb * fSkyMultiplier, 1.0);
}


