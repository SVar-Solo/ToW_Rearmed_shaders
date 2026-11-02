// D3D11 port of SSFogCopy_PS.hlsl. Generated from the legacy HLSL source; see README.md.

struct VertexOUT 
{
    float2 texCoord : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0);
cbuffer SSFogCopy_PS_CB0 : register(b0)
{
float fSkyMultiplier;

};
float4 main(in VertexOUT IN) : SV_Target0
{
	float4 fog_color = TexMap.Sample(TexMap_Sampler, IN.texCoord);
	if (fog_color.a <= 0.0001) discard;
    return float4(fog_color.rgb*fSkyMultiplier, fog_color.a);
} 
