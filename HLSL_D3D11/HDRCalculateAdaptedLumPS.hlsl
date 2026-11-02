// D3D11 port of HDRCalculateAdaptedLumPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

Texture2D TexMap1 : register(t0);
SamplerState TexMap1_Sampler : register(s0); // Base texture
Texture2D TexMap2 : register(t1);
SamplerState TexMap2_Sampler : register(s1); // Base texture
cbuffer HDRCalculateAdaptedLumPS_CB0 : register(b0)
{
float3 fElapsedTimeEyeLimit;

};
float EyeLimit(float lum)
{
  float res;
  res = saturate(lum);
  res = clamp(res, fElapsedTimeEyeLimit.y, fElapsedTimeEyeLimit.z);
  return res;
}

float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float2 fAdaptedLum = TexMap1.Sample(TexMap1_Sampler, float2(0.5, 0.5)).xy;
	float2 fCurrentLum = TexMap2.Sample(TexMap2_Sampler, float2(0.5, 0.5)).xy;

	fCurrentLum.x = EyeLimit(fCurrentLum.x);
    
    // The user's adapted luminance level is simulated by closing the gap between
    // adapted luminance and current luminance by 2% every frame, based on a
    // 30 fps rate. This is not an accurate model of human adaptation, which can
    // take longer than half an hour.
	float2 fNewAdaptation = fAdaptedLum + (fCurrentLum - fAdaptedLum) * ( 1.0 - pow( 0.98, 100.0 * fElapsedTimeEyeLimit.x ) );
	//float2 fNewAdaptation.xy = fCurrentLum.xy;

	return float4(fNewAdaptation.xy,0.0,1.0);
}