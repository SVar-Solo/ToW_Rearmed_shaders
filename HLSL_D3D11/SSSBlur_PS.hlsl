// D3D11 port of SSSBlur_PS.hlsl. Generated from the legacy HLSL source; see README.md.

struct VertexOUT
{
	float2 TexCoord[2]   : TEXCOORD0;
};

#define MAX_SAMPLES 15

// uniforms
cbuffer SSSBlur_PS_CB0 : register(b0)
{
float SampleWeights[MAX_SAMPLES];
float2 SampleOffsets[MAX_SAMPLES];

};
Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture
Texture2D DepthMap : register(t1);
SamplerState DepthMap_Sampler : register(s1); // Base texture

float4 main(in VertexOUT IN) : SV_Target0
{
	// return tex2D (TexMap, IN.TexCoord[0]); 
	
	if (true)
	{
		//float2 PixelSize = float2(1.0f/1280.0f, 1.0f/960.0f);
		float2 tex_coord0 =  IN.TexCoord[0]; // + 0.5*PixelSize;
	
		float4	sample = float4(0.0f, 0.0f, 0.0f, 0.0f);
		float	weight = 0.0f;
		float	accum_weight = 0.0f;
		float	sample_depth;
		float	pixel_depth = DepthMap.Sample(DepthMap_Sampler, tex_coord0);
		
		float	kernel_scale = clamp(5.0/pixel_depth, 0.5f, 2.0);
		
		for (int i = 0; i < MAX_SAMPLES; i++)
		{
			sample_depth = DepthMap.Sample(DepthMap_Sampler, tex_coord0 + kernel_scale*SampleOffsets[i]);
			weight = abs(sample_depth - pixel_depth) > 0.5f ? 0.0f : SampleWeights[i];
			//weight = SampleWeights[i];
			accum_weight += weight;
			
			sample += weight * TexMap.Sample(TexMap_Sampler, tex_coord0 + kernel_scale*SampleOffsets[i]);
		}
		
		return float4(sample.rgb/accum_weight, 1.0);
		//return tex2D (TexMap, tex_coord0); 
		//return float4(IN.TexCoord[0].uv, 1.0, 1.0);
		//return kernel_scale.xxxx;
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