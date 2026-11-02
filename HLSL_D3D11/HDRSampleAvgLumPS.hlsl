// D3D11 port of HDRSampleAvgLumPS.hlsl. Generated from the legacy HLSL source; see README.md.

#define MAX_SAMPLES 9

// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture
cbuffer HDRSampleAvgLumPS_CB0 : register(b0)
{
float2 avSampleOffsets[MAX_SAMPLES];

};
float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float3 vSample = float3(0.0, 0.0, 0.0);
	float fLogLumSum = 0.0;
	float maxLum = 0;
	float3 LUMINANCE_WEIGHT = float3( 0.299f, 0.587f, 0.114f );
	for(int iSample = 0; iSample < MAX_SAMPLES; iSample++)
	{
		// Compute the sum of log(luminance) throughout the sample points
		float2 uv = IN.texCoord + avSampleOffsets[iSample];
		vSample = TexMap.Sample(TexMap_Sampler, uv).rgb;
		//float lum = clamp(saturate(dot(vSample, LUMINANCE_WEIGHT)),0,500);
		float lum = max(vSample.x, max(vSample.y, vSample.z));
		// weights in center of screen
		//float2 coord = uv-0.5;
		//float R = 0.1;
		//float z = saturate(R*R-dot(coord,coord));
		fLogLumSum += log( lum + 0.0001f);
		//delta += z;
		maxLum = max(maxLum, lum);
	}
	// Divide the sum to complete the average
	fLogLumSum *= (1.f/9.f);

	return float4(fLogLumSum, maxLum, 0.0 ,1.0);
}