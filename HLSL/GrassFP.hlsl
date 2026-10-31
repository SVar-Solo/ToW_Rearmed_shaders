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

uniform half kBlend; //Additional blending factor for smooth turn off near to max vizible height
uniform half4 Ka; //Ambient color
uniform half4 Kd; //Diffuse color
uniform sampler2D RoundMaskTex : register(s0);
uniform sampler2D MaskMap : register(s1);
uniform sampler2D LandMap : register(s2);
uniform sampler2D GrassMap : register(s3);

float4 main(VertexOut IN
			) : COLOR
{
  float4 RoundMask = tex2D(RoundMaskTex, IN.texCoord0.xy);
  float4 Land = tex2D(LandMap, IN.texCoord2.xy);
  float4 Grass = tex2D(GrassMap, IN.texCoord3.xy);  
  //---------------------
  //Attention: Use simple modulation: color.a = Grass.a * NewMask.a;  
  float4 NewMask = tex2D(MaskMap, IN.texCoord1.xy);  //without dependent read
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






