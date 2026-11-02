// D3D11 port of TreeFP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Fragment shader for support Trees
//****************************************************

//#define SHADOW
//#define COMPAREZ
//#define ZPASS  
#define PSSM

struct VertexOut
{
//    float4 HPOS : SV_Position;

#ifndef ZPASS
    float4 COL0 : COLOR0;       //temp - tranzit from input
    float3 COL1 : COLOR1;       //temp - tranzit from input
    float2 TEX0 : TEXCOORD0;
    float2 TEX1 : TEXCOORD1;
#else
	float2 TEX1 : TEXCOORD0;
#endif //ZPASS
   

#ifndef ZPASS
#ifdef SHADOW
    float4 TEX2 : TEXCOORD2;  //Shadow map
#endif  //SHADOW
  #ifdef FOG
	float4 fogCoord : TEXCOORD3;
  #endif
#else
	float4 zcoord : TEXCOORD4;
#endif //ZPASS
	float3 ambient_dir : TEXCOORD5;
    float3 normal : TEXCOORD6;
};

#ifndef ZPASS
//#ifdef SHADOW
	Texture2D ShadowMap : register(t2);
	SamplerState ShadowMap_Sampler : register(s2);
//#endif  //SHADOW
#endif // ZPASS

#ifdef PSSM
// PSSM implemetation
// matrix array
cbuffer TreeFP_CB0 : register(b0)
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

float fSkyMultiplier;

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
		return 1.0;

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

#ifndef ZPASS
	Texture2D BumpTex : register(t0);
	SamplerState BumpTex_Sampler : register(s0);
cbuffer TreeFP_CB1 : register(b1)
{
	float3 SunAmbientColor;
	float3 SunDiffuseColor;
};
	Texture2D TreeTex : register(t1);
	SamplerState TreeTex_Sampler : register(s1);
#else
	Texture2D TreeTex : register(t0);
	SamplerState TreeTex_Sampler : register(s0);
#endif //ZPASS
            

#ifndef ZPASS
#ifdef FOG
	TextureCube SkyMap : register(t3);
	SamplerState SkyMap_Sampler : register(s3); // Fog texture
#endif

#endif //ZPASS

float4 main(in VertexOut IN
			) : SV_Target0
{

  float4 color;

#ifndef ZPASS

  float4 tex0 = BumpTex.Sample(BumpTex_Sampler, IN.TEX0.xy);
  float4 TextureColor = TreeTex.Sample(TreeTex_Sampler, IN.TEX1.xy);
  float3 N = (2*tex0.rgb - 1);
  float diffuse_light = saturate(dot(N, IN.normal.rgb));
 
    //---shadows---
#ifdef SHADOW
  float ShadowFactor; // = 1.0;

#ifdef PSSM

	ShadowFactor =  getPSSMPixel3(IN.TEX2);
#else	

	float3 projcoord = IN.TEX2.xyz/IN.TEX2.w;
	float4 Shadow = ShadowMap.Sample(ShadowMap_Sampler, projcoord.xy);
#ifndef COMPAREZ  
	ShadowFactor = Shadow.r;   //0 or 1
#else  //COMPAREZ
	float zProj = projcoord.z;
	ShadowFactor = (zProj > Shadow.r)?0:1;
	ShadowFactor = Shadow.r>0?ShadowFactor:1;
#endif //COMPAREZ
#endif  // PSSM

  diffuse_light *= ShadowFactor;

#endif  //SHADOW

   //---------------

  float3 adir = IN.ambient_dir;//normalize(IN.ambient_dir);
  //diffuse_light = diffuse_light*0.7 + saturate(dot(N, adir))*0.3;
  float ambient_light = saturate(dot(N, adir));//+IN.COL0.a;                     //IN.COL0.a already multiplyed by current Ka in vertex shader

//  float light = ambient_light + diffuse_light; 
  float3 light = (SunDiffuseColor)*diffuse_light+SunAmbientColor*(1+0.5*ambient_light);
  
//#ifdef SHADOW
//  light *= ShadowFactor; //modulate ambient also  //????????
//#endif  //SHADOW  

  //modulate with tree texture
  color.rgb = light.xxx * TextureColor.rgb;

  color.a = TextureColor.a;

  //fog (add secondary color)
  //color.rgb += IN.COL1.rgb;

#ifdef FOG
  float4 fogColor = SkyMap.Sample(SkyMap_Sampler, IN.fogCoord.xyz);
  fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
  // compute final color
  color.rgb = lerp(color.rgb, fogColor.rgb, IN.fogCoord.w);
#endif

//  color.rgb = diffuse_light.xxx;

#else //ZPASS

  float4 tex1 = TreeTex.Sample(TreeTex_Sampler, IN.TEX1.xy);
  color.a = tex1.a;
  float rz = 0.5 * (IN.zcoord.z)/IN.zcoord.w + (0.5).xxx;
  color.rgb = float3(rz,rz,rz);
  if (color.a < 0.3)
  {
	  discard;
  }
#endif //ZPASS

//color.a = 1.0;   //??????????????????
#ifdef SHADOW
//  color.rgb = Shadow.rrr;//float3(IN.TEX2.xy,0)/IN.TEX2.w;
#endif  //SHADOW  

  
  return color;
}

