// D3D11 port of FarTreeFP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Far trees fragment shader
//****************************************************

struct InStruct
{
  float4 color    : COLOR0;
  float4 fogColor : COLOR1;
  float2 tex0     : TEXCOORD0;
  float4 fogCoord : TEXCOORD1;
};

cbuffer FarTreeFP_CB0 : register(b0)
{
float fSkyMultiplier;
};
Texture2D TreeTex : register(t0);
SamplerState TreeTex_Sampler : register(s0);
TextureCube SkyMap : register(t1);
SamplerState SkyMap_Sampler : register(s1); // Fog texture

half4 main(InStruct IN) : SV_Target0
{

  float4 color;
  float4 texColor;
  
  texColor  = TreeTex.Sample(TreeTex_Sampler, IN.tex0.xy);  
  color.rgb = IN.color.rgb * texColor.rgb;
  color.a   = texColor.a;
#ifdef FOG
  float4 fogColor = SkyMap.Sample(SkyMap_Sampler, IN.fogCoord.xyz);
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
  // compute final color
  color.rgb = lerp(color.rgb, fogColor.rgb, IN.fogCoord.w);
#endif
  return color;
}

