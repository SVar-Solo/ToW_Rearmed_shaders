// D3D11 port of GrassFP.hlsl. Generated from the legacy HLSL source; see README.md.
//********* Options for Custom Build step ************
//for vertex program
//"E:\Program Files\NVIDIA Corporation\Cg\bin\cgc.exe"  -profile vp20 -posinv -o $(InputName).txt $(InputPath)
//for fragment program
//"E:\Program Files\NVIDIA Corporation\Cg\bin\cgc.exe"  -profile fp20 -o $(InputName).txt $(InputPath)
//****************************************************

//****************************************************
//Fragment shader for Far grass: pass1 - without shadows
//calc ambient + diffuse light
//****************************************************

//-----------------FP20----------------------
struct VertexOut {
  float2 texCoord0 : TEXCOORD0;    //RoundMask  
  float2 texCoord1 : TEXCOORD1;    //Mask
  float2 texCoord2 : TEXCOORD2;    //Land
  float2 texCoord3 : TEXCOORD3;    //Grass
};

cbuffer GrassFP_CB0 : register(b0)
{
float kBlend; //Additional blending factor for smooth turn off near to max vizible height
float4 Ka; //Ambient color
float4 Kd; //Diffuse color
};
Texture2D RoundMaskTex : register(t0);
SamplerState RoundMaskTex_Sampler : register(s0);
Texture2D MaskMap : register(t1);
SamplerState MaskMap_Sampler : register(s1);
Texture2D LandMap : register(t2);
SamplerState LandMap_Sampler : register(s2);
Texture2D GrassMap : register(t3);
SamplerState GrassMap_Sampler : register(s3);

float4 main(VertexOut IN
			) : SV_Target0
{
  float4 RoundMask = RoundMaskTex.Sample(RoundMaskTex_Sampler, IN.texCoord0.xy);
  float4 Land = LandMap.Sample(LandMap_Sampler, IN.texCoord2.xy);
  float4 Grass = GrassMap.Sample(GrassMap_Sampler, IN.texCoord3.xy);  
  //---------------------
  //Attention: Use simple modulation: color.a = Grass.a * NewMask.a;  
  float4 NewMask = MaskMap.Sample(MaskMap_Sampler, IN.texCoord1.xy);  //without dependent read
  //---------------------

  float3 diffuse_light;
  diffuse_light.rgb = Land.a * Kd.rgb;   

  float4 color;
  color.rgb = (Grass.rgb * Land.rgb) * 2.0f;  
  //2-nd modulation step
  color.rgb = (color.rgb * NewMask.rgb) * 2.0f;  //!!!!!!

  //---Masking by TypeMap---
  color.a = Grass.a * NewMask.a;  

  //---Masking by RoundMap for smoothing---
  color.a *= RoundMask.a;

  //---Smooth turn of near to max vizible height---
  color.a *= kBlend;

#ifdef PROFILE_FP20
	color.rgb = saturate(Ka.rgb + diffuse_light.rgb) * color.rgb;
#else
	color.rgb = clamp(Ka.rgb + diffuse_light.rgb, 0.0, 1.0) * color.rgb;
#endif

  return color;
}






