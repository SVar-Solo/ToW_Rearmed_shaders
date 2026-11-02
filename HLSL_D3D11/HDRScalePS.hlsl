// D3D11 port of HDRScalePS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexOUT {
    float2 texCoord : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0);
cbuffer HDRScalePS_CB0 : register(b0)
{
float2 avSampleOffsets[16];

 // main procedure, the original name was main
};
float4 main(in VertexOUT IN) : SV_Target0
{

	float4 sample = TexMap.Sample(TexMap_Sampler, IN.texCoord + avSampleOffsets[0]);
	for(int i=1;i<16;i++)
	{
		sample += TexMap.Sample(TexMap_Sampler, IN.texCoord + avSampleOffsets[i]);
	}
	sample *= (1.f/16);
	return sample;
} // main end
