// D3D11 port of SSAO_Downsample_PS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
	float2 pixelsize : TEXCOORD1;
};

Texture2D sceneDepthBuffer : register(t0);
SamplerState sceneDepthBuffer_Sampler : register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float2 tc0 = IN.texCoord.xy;
	float2 offset = IN.pixelsize;
   float sum = sceneDepthBuffer.Sample(sceneDepthBuffer_Sampler, tc0).r/5.f;
   sum += sceneDepthBuffer.Sample(sceneDepthBuffer_Sampler, tc0 + offset).r/5.f;
   sum += sceneDepthBuffer.Sample(sceneDepthBuffer_Sampler, tc0 + float2(offset.x, -offset.y)).r/5.f;
   sum += sceneDepthBuffer.Sample(sceneDepthBuffer_Sampler, tc0 + float2(-offset.x, offset.y)).r/5.f;
   sum += sceneDepthBuffer.Sample(sceneDepthBuffer_Sampler, tc0 - offset).r/5.f;
   
   return sum;
   //return IN.texCoord.x;
}