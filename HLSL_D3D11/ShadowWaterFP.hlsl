// D3D11 port of ShadowWaterFP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Fragment shader for support Shadow map in Water 
//****************************************************

//#define COMPAREZ  //used for Radeon
#define PSSM

struct VertexOut
{
    //Attention: below is output from vertex shader
//    float4 HPOS : SV_Position;
    float4 TEX0 : TEXCOORD0;   //PSM
};

Texture2D ShadowMap : register(t0);
SamplerState ShadowMap_Sampler : register(s0);


//-----------------------------------------------------------------------------
//	PSSM shadows
//-----------------------------------------------------------------------------

#ifdef PSSM
// PSSM implemetation
// matrix array
cbuffer ShadowWaterFP_CB0 : register(b0)
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

// sample shadow map
};
float getShadowPixel(float3 projcoord)
{
    float ShadowFactor = 1;
#ifdef SHADOW
	float4 Shadow = ShadowMap.Sample(ShadowMap_Sampler, projcoord.xy);
#ifndef COMPAREZ  
	ShadowFactor = Shadow.r;   //0 or 1
#else  //COMPAREZ
	float zProj = projcoord.z;
	ShadowFactor = (zProj > Shadow.r)?0:1;
	ShadowFactor = Shadow.r>0?ShadowFactor:1;
#endif //COMPAREZ
#endif  //SHADOW
	return ShadowFactor;
}

//-----------------------------------------------------------------------------
//	getShadow_ZLod
//-----------------------------------------------------------------------------

float getShadow_ZLod(float4 world_coords)
{
    float4 shad_coord = float4(0, 0, 0, 0);
	float4 shadow_sample = float4(0, 0, 0, 0);

	float4 sm_k = float4(0, 0, 0, 0);
	

	//sm_k.x = step(0, world_coords.w) - step(PSSMSplit0, world_coords.w);
	//sm_k.y = step(PSSMSplit0, world_coords.w) - step(PSSMSplit1, world_coords.w);
	//sm_k.z = step(PSSMSplit1, world_coords.w) - step(PSSMSplit2, world_coords.w);
	//sm_k.w = step(PSSMSplit2, world_coords.w) - step(PSSMSplit3, world_coords.w);

	sm_k.x = world_coords.w > 0 ? (world_coords.w < PSSMSplit0 ? 1.0 : 0.0) : 0.0;
	sm_k.y = world_coords.w > PSSMSplit0 ? (world_coords.w < PSSMSplit1 ? 1.0 : 0.0) : 0.0;
	sm_k.z = world_coords.w > PSSMSplit1 ? (world_coords.w < PSSMSplit2 ? 1.0 : 0.0) : 0.0;
	sm_k.w = world_coords.w > PSSMSplit2 ? (world_coords.w < PSSMSplit3 ? 1.0 : 0.0) : 0.0;

	float sm_k_none = 1 - (dot(sm_k, sm_k)); // step(PSSMSplit3, world_coords.w); //  ? 1 : 0;

	float4x4 sh_m = sm_k.x*PSSMProjTexMatrix0 +
					sm_k.y*PSSMProjTexMatrix1 + 
					sm_k.z*PSSMProjTexMatrix2 + 
					sm_k.w*PSSMProjTexMatrix3;

	//shad_coord = sm_k.x*shad_coord0 + sm_k.y*shad_coord1 + sm_k.z*shad_coord2 + 
	//	sm_k.w*shad_coord3;
	
	shad_coord = mul(sh_m, float4(world_coords.xyz, 1));
	shad_coord.xyz /= shad_coord.w;
	
	
	float z_eps =	sm_k.x*0.00001 + 
					sm_k.y*0.00004 + 
					sm_k.z*0.00016 + 
					sm_k.w*0.00064;
	
	

	float3 sm_offs =	sm_k.x * float3(0.0, 0.5, 0.0) +
						sm_k.y * float3(0.5, 0.5, 0.0) + 
						sm_k.z * float3(0.0, 0.0, 0.0) + 
						sm_k.w * float3(0.5, 0.0, 0.0);

	float sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	float shadow_factor = 1.0;

	if (0)
	{
		return 1;
	}
	else if (1)
	{		
		// changed shadow_factor		
		shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
		shadow_factor = (shad_coord.z - z_eps > shadow_sample.r) ? 1 : 0;
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;	
				
		// change sign
		//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
		shadow_factor = 1 - shadow_factor; // negated after call
	}
	else
	{
		float3 uvz = shad_coord.xyz; // clamp(shad_coord.xy, 0.0, 1.0);
		uvz.xy = clamp(shad_coord.xy, 0.0, 1.0); 
		float mgs = PSSMWidth;
		uvz.x *= 0.5*PSSMWidth;
		uvz.y *= 0.5*PSSMWidth;
		float x = floor(uvz.x);
		float y = floor(uvz.y);
		float z = uvz.z * mgs;
		float u_ratio = uvz.x - x;
		float v_ratio = uvz.y - y;
		float u_opposite = 1 - u_ratio;
		float v_opposite = 1 - v_ratio;

		//shadow_factor = getShadowPixel(sm_offs + float3(x, y, z)/mgs);
		
		//shadow_sample = tex2D(ShadowMap, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));

		shadow_factor =
			(getShadowPixel(sm_offs + float3(x, y, z)/mgs)*u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y,z)/mgs)*u_ratio) * v_opposite + 

			(getShadowPixel(sm_offs + float3(x,y+1,z)/mgs) * u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y+1,z)/mgs)*u_ratio) * v_ratio;
	}
	
	//return sm_scale*shadow_factor;
	return shadow_factor; //  + sm_k_none;
}

//-----------------------------------------------------------------------------
//	getShadow_ProjLod
//-----------------------------------------------------------------------------

float getShadow_ProjLod (float4 world_coords)
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

	float z_eps =	sm_k.x*0.000001 + 
					sm_k.y*0.00004 + 
					sm_k.z*0.00016 + 
					sm_k.w*0.00064;

	//shad_coord = mul(sh_m, float4(world_coords.xyz, 1));

	shad_coord.xyz /= shad_coord.w;


	float3 sm_offs = sm_k.x*float3(0, 0.5, 0) +
		sm_k.y*float3(0.5, 0.5, 0) + 
		sm_k.z*float3(0, 0, 0) + 
		sm_k.w*float3(0.5, 0, 0);

	//float2 sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;
	float shadow_factor = 1.0;

	if (0)
	{
		return 1;
	}
	else if (1)
	{		
		// changed shadow_factor		
		shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
		shadow_factor = (shad_coord.z - z_eps > shadow_sample.r) ? 1 : 0;
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;	
				
		// change sign
		//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
		shadow_factor = 1 - shadow_factor; // negated after call
	}
	else
	{
		// smooth
		float3 uvz = shad_coord.xyz; // clamp(shad_coord.xy, 0.0, 1.0);
		uvz.xy = clamp(shad_coord.xy, 0.0, 1.0); 
		float mgs = PSSMWidth;
		uvz.x *= 0.5*PSSMWidth;
		uvz.y *= 0.5*PSSMWidth;
		float x = floor(uvz.x);
		float y = floor(uvz.y);
		float z = uvz.z * mgs;
		float u_ratio = uvz.x - x;
		float v_ratio = uvz.y - y;
		float u_opposite = 1 - u_ratio;
		float v_opposite = 1 - v_ratio;

		shadow_factor =
			(getShadowPixel(sm_offs + float3(x, y, z)/mgs)*u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y,z)/mgs)*u_ratio) * v_opposite + 

			(getShadowPixel(sm_offs + float3(x,y+1,z)/mgs) * u_opposite + 
			 getShadowPixel(sm_offs + float3(x+1,y+1,z)/mgs)*u_ratio) * v_ratio;
	}
}

#endif // PSSM


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) : SV_Target0
{

  float4 color;
  float ShadowFactor = 0;

#ifdef PSSM
  ShadowFactor = getShadow_ZLod(IN.TEX0.xyzw);
#else
	float4 Shadow = ShadowMap.Sample(ShadowMap_Sampler, (IN.TEX0.xyzw).xy / (IN.TEX0.xyzw).w);

	#ifndef COMPAREZ  
		ShadowFactor = Shadow.r;   //0 or 1
	#else  //COMPAREZ
		float zProj = IN.TEX0.z/IN.TEX0.w;
		ShadowFactor = (zProj > Shadow.r)?0:1;
		ShadowFactor = (Shadow.r>0)?ShadowFactor:1;
	#endif //COMPAREZ
#endif // PSSM

  //modulate
  float ShadowAtt = 0.2; //0.6; //0.5;
  ShadowFactor = lerp(ShadowFactor,1.0,ShadowAtt);   //ShadowFactor = ShadowFactor*(1.0-ShadowAtt) + ShadowAtt;  

  color.a = 1.0 - ShadowFactor;
  color.rgb = 0.0;

  return color;
}



