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

uniform float fSkyMultiplier;
uniform sampler2D TreeTex : register(s0);
uniform samplerCUBE SkyMap: register(s1); // Fog texture

half4 main(InStruct IN) : COLOR
{

  float4 color;
  float4 texColor;
  
  texColor  = tex2D(TreeTex, IN.tex0.xy);  
  color.rgb = IN.color.rgb * texColor.rgb;
  color.a   = texColor.a;
#ifdef FOG
  float4 fogColor = texCUBE(SkyMap, IN.fogCoord.xyz);
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
  // compute final color
  color.rgb = lerp(color.rgb, fogColor.rgb, IN.fogCoord.w);
#endif
  return color;
}

