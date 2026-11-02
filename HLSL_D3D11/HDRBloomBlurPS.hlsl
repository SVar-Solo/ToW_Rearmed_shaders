// D3D11 port of HDRBloomBlurPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

#define MAX_SAMPLES 15

cbuffer HDRBloomBlurPS_CB0 : register(b0)
{
float2 avSampleOffsets[MAX_SAMPLES];
float4 avSampleWeights[MAX_SAMPLES];
};
Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float4 sample = avSampleWeights[0] * TexMap.Sample(TexMap_Sampler, IN.texCoord + avSampleOffsets[0]);
	for( int i=1; i < MAX_SAMPLES; i++ )
	{
		sample += avSampleWeights[i] * TexMap.Sample(TexMap_Sampler, IN.texCoord + avSampleOffsets[i]);
	}
	return float4(sample.rgb,1.0);
}