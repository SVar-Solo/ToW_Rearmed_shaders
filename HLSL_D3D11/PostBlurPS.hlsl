// D3D11 port of PostBlurPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From Post.hlsl vertex shader
struct VertexOUT
{
	float2 TexCoord[8]   : TEXCOORD0;
	// float2 texCoord_8 : TEXCOORD1;
};

#define MAX_SAMPLES 15

cbuffer PostBlurPS_CB0 : register(b0)
{
float2 avSampleOffsets[MAX_SAMPLES];
float4 avSampleWeights[MAX_SAMPLES];
};
Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture

float4 main(in VertexOUT IN) : SV_Target0
{
	if (true)
	{
		float kernel_scale = 0.75f;
		
		float4 sample = avSampleWeights[0].x * TexMap.Sample(TexMap_Sampler, IN.TexCoord[0] + kernel_scale*avSampleOffsets[0]);
		for (int i = 1; i < MAX_SAMPLES; i++)
		{
			sample += avSampleWeights[i].x * TexMap.Sample(TexMap_Sampler, IN.TexCoord[0] + kernel_scale*avSampleOffsets[i]);
		}
		return float4(sample.rgb, 1.0);
		//return float4(tex2D(TexMap, IN.texCoord).rgg, 1.0);
	}
	else
	{
		float4  sample[7];
		for (int i = 0; i < 7; i++)
		{
			sample[i] = TexMap.Sample(TexMap_Sampler, IN.TexCoord[i]);
		}
	 
		// 1D Gaussian 7 taps coefficients
		const float coeff[7] = {0.006f, 0.061f, 0.242f, 0.382f, 0.242f, 0.061f, 0.006f};     
		//const float coeff[7] = {0.0f, 0.1f, 0.1f, 0.6f, 0.1f, 0.1f, 0.0f};     

		float4 accum;
		//accum = log_conv( coeff[0], sample[0], coeff[1], sample[1] );
		accum = coeff[0]*sample[0] + coeff[1]*sample[1];
		for (int i = 2; i < 7; i++)
		{
			//accum = log_conv( 1.f, accum, coeff[i], sample[i] );
			accum += coeff[i]*sample[i];
		}        
		return float4(accum.rgb, 1.0);
	}
}