// D3D11 port of GrassFP_Shadows.hlsl. Generated from the legacy HLSL source; see README.md.
//********* Options for Custom Build step ************
//for vertex program
//"E:\Program Files\NVIDIA Corporation\Cg\bin\cgc.exe"  -profile vp20 -posinv -o $(InputName).txt $(InputPath)
//for fragment program
//"E:\Program Files\NVIDIA Corporation\Cg\bin\cgc.exe"  -profile fp20 -o $(InputName).txt $(InputPath)
//****************************************************

//****************************************************
//Fragment shader for Far grass: pass2 - shadows 
//calc only ambient light
//****************************************************

//#define COMPAREZ
#define PSSM



//-----------------FP20----------------------
struct VertexOut {
  float4 texCoord0 : TEXCOORD0;    //ShadowMap  
  float2 texCoord1 : TEXCOORD1;    //Mask     
  float2 texCoord2 : TEXCOORD2;    //Land
  float2 texCoord3 : TEXCOORD3;    //Grass
};

Texture2D ShadowMap : register(t0);
SamplerState ShadowMap_Sampler : register(s0);

#ifdef PSSM
// PSSM implemetation
// matrix array
cbuffer GrassFP_Shadows_CB0 : register(b0)
{
column_major float4x4 PSSMProjTexMatrix0;
column_major float4x4 PSSMProjTexMatrix1;
column_major float4x4 PSSMProjTexMatrix2;
column_major float4x4 PSSMProjTexMatrix3;

float PSSMSplit0;
float PSSMSplit1;
float PSSMSplit2;
float PSSMSplit3;

float PSSMWidth;

};
float getPSSMPixel3 (float4 world_coords)
{
    float4 shad_coord;
	float4 shadow_sample;

	// 0 level	
	float4 shad_coord0 = mul(PSSMProjTexMatrix0, float4(world_coords.xyz, 1));
	float4 shad_coord1 = mul(PSSMProjTexMatrix1, float4(world_coords.xyz, 1));
	float4 shad_coord2 = mul(PSSMProjTexMatrix2, float4(world_coords.xyz, 1));
	float4 shad_coord3 = mul(PSSMProjTexMatrix3, float4(world_coords.xyz, 1));

	float4 sm_k = float4(0,0,0,0);
	
	if (shad_coord0.x > 0.0 && shad_coord0.x < 1.0 && shad_coord0.y > 0.0 && shad_coord0.y < 1.0)
	{
		sm_k.x = 1.0; // float4 (1.0, 0.0, 0.0, 0.0);
	}
	else
	{
		sm_k.x = 0.0;
		if (shad_coord1.x > 0.0 && shad_coord1.x < 1.0 && shad_coord1.y > 0.0 && shad_coord1.y < 1.0)
		{
			sm_k.y = 1.0;
		}
		else
		{
			sm_k.y = 0.0;
			if (shad_coord2.x > 0.0 && shad_coord2.x < 1.0 && shad_coord2.y > 0.0 && shad_coord2.y < 1.0)
			{
				sm_k.z = 1.0;
			}
			else
			{
				// sm_k.w = 1.0;
				if (shad_coord3.x > 0.0 && shad_coord3.x < 1.0 && shad_coord3.y > 0.0 && shad_coord3.y < 1.0)
				{
					sm_k.w = 1.0;
				}
				else
				{
					sm_k.w = 0.0;//return 1;
				}
			}
		}
		
	}

	//float sm_k_none = 1 - (dot(sm_k, sm_k));
	
	shad_coord = 
		sm_k.x*shad_coord0 + 
		sm_k.y*shad_coord1 + 
		sm_k.z*shad_coord2 + 
		sm_k.w*shad_coord3;

	//shad_coord = mul(sh_m, float4(world_coords.xyz, 1));

	shad_coord.xyz /= shad_coord.w;

	float2 sm_offs = sm_k.x*float2(0, 0.5) +
		sm_k.y*float2(0.5, 0.5) + 
		sm_k.z*float2(0, 0) + 
		sm_k.w*float2(0.5, 0);

	//float2 sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));

	float shadow_factor = 1.0;

#ifndef COMPAREZ  
	shadow_factor = shadow_sample.r;   // 0 or 1
#else  //COMPAREZ
	shadow_factor = (shad_coord.z > shadow_sample.r) ? 0 : 1;
	shadow_factor = shadow_sample.r > 0 ? shadow_factor : 1;
#endif //COMPAREZ
	
	//return sm_scale*shadow_factor;
	return shadow_factor; //  + sm_k_none;
}

#endif // PSSM

cbuffer GrassFP_Shadows_CB1 : register(b1)
{
float4 Ka; //Ambient color
//uniform float4 Kd; //Diffuse color
};
Texture2D MaskMap : register(t1);
SamplerState MaskMap_Sampler : register(s1);
Texture2D LandMap : register(t2);
SamplerState LandMap_Sampler : register(s2);
Texture2D GrassMap : register(t3);
SamplerState GrassMap_Sampler : register(s3);

float4 main(VertexOut IN
			) : SV_Target0
{
  float4 Land = LandMap.Sample(LandMap_Sampler, IN.texCoord2.xy);
  float4 Grass = GrassMap.Sample(GrassMap_Sampler, IN.texCoord3.xy);  
  //---------------------
  //Attention: Use simple modulation: color.a = Grass.a * NewMask.a;  
  float4 NewMask = MaskMap.Sample(MaskMap_Sampler, IN.texCoord1.xy);  //without dependent read
  //---------------------

  float4 color;

//----------------------------
//Attention: This is right logic for calculation far grass color in shadow region.
//           But we have interpolation problem in texture NewMask on boundary of grass.
//           So simply use for shadows Land.rgb. More over in this case shadows on far grass and
//           shadows on land will have the same color.

/*
  color.rgb = (Grass.rgb * Land.rgb) * 2.0f;  
  //2-nd modulation step
  color.rgb = (color.rgb * NewMask.rgb) * 2.0f;  //!!!!!!
*/
  color.rgb = Land.rgb;  //??????????????????????????????
//----------------------------
   float ShadowFactor = 0;

#ifdef PSSM
  ShadowFactor = getPSSMPixel3(IN.texCoord0);
#else
  //shadow vizualization 
  float4 Shadow = ShadowMap.Sample(ShadowMap_Sampler, (IN.texCoord0.xyzw).xy / (IN.texCoord0.xyzw).w);
 

#ifndef COMPAREZ  
	ShadowFactor = Shadow.r;   //0 or 1
#else  //COMPAREZ
	float zProj = IN.texCoord0.z/IN.texCoord0.w;
	ShadowFactor = (zProj > Shadow.r)?0:1;
	ShadowFactor = (Shadow.r>0)?ShadowFactor:1;
#endif //COMPAREZ 

#endif // PSSM

	//---Masking by ShadowMap---
  ShadowFactor *= Land.a;  //here we must reguard shadow correction tech. using Land.a

//Attention: Here we use some porog value to distinct in land texture region with shadows from region with
//           low intensity. There are some situation where these region have similar values.
//           To separate these regions with some garantee correct light calculation in function which build
//           light map CastShadowsOnTextureNew(), so that slightly increase intensity for regions with small intensity. 
  color.a = (ShadowFactor < 0.006) ? 1.0: 0.0;
//  color.a = (ShadowFactor < 0.5) ? 1.0: 0.0;
//  color.a = (ShadowFactor < 0.1) ? 1.0: 0.0;

  //---Masking by TypeMap---
//Attention: There is no need to use Mask.a if stencil is used.
//           Use this mask only without stencil.
//  color.a *= NewMask.a;  

//  color.a *= Grass.a;                 //test only
//  color.a *= (Grass.a * NewMask.a);   //test only
  //-------------------------

  color.rgb = Ka.rgb * color.rgb;  //calc only ambient light 
//  color.rgb = 1;

  return color;
}






