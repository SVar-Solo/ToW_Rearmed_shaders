// D3D11 port of HDRResampleAvgLumPS.hlsl. Generated from the legacy HLSL source; see README.md.
#define MAX_SAMPLES 16

// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture
cbuffer HDRResampleAvgLumPS_CB0 : register(b0)
{
float2 avSampleOffsets[MAX_SAMPLES];

};
float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float fResampleSum = 0.0; 
	float maxLum = 0;
	for(int iSample = 0; iSample < 16; iSample++)
	{
		// Compute the sum of luminance throughout the sample points
		float4 lum = TexMap.Sample(TexMap_Sampler, IN.texCoord + avSampleOffsets[iSample]);
		fResampleSum += lum.r;
		maxLum = max(maxLum, lum.g);
	}
	// Divide the sum to complete the average
	fResampleSum *= (1.f/16.0);

	return float4(fResampleSum, maxLum, 0.0 ,1.0);
}