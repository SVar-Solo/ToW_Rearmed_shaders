// D3D11 port of HFLandFP.hlsl. Generated from the legacy HLSL source; see README.md.
//Land pixel shader.
//This shader: 1. calc land luminance (ambient + diffuse)
//             2. modulate result with common noise
//             3. apply shadows
//Attention: ??? land noises are rendered after shadow applying (may be inconsistent to some extent) ???

//Have 3 modifications:
// - normal shader for land (noise modulation + lighting + shadow) - define macros FULL
// - shader for 3 lod (lighting)
// - shader for land reflection (lighting)  

//#define FULL
//#define SHADOW //internal to FULL
//#define COMPAREZ  //used for Radeon
#define PSSM


struct VertexOut
{	
  float2 TexCoord0 : TEXCOORD0;  //Land base texture
  float2 TexCoord3 : TEXCOORD3;  //Координаты для прозрачности на границах ландшафта
#ifdef FULL
  float2 TexCoord1 : TEXCOORD1;  //Land common noise texture
#ifdef SHADOW_OLD
  float4 TexCoord2 : TEXCOORD2;  //Shadow map
#endif  //SHADOW
#endif //FULL
};

cbuffer HFLandFP_CB0 : register(b0)
{
float4 Ka; //Ambient color
float4 Kd; //Diffuse color
};
Texture2D LandTex : register(t0);
SamplerState LandTex_Sampler : register(s0);              //Land base texture
#ifdef FULL
	Texture2D LandCommonNoiseTex : register(t1);
	SamplerState LandCommonNoiseTex_Sampler : register(s1);  //Land common noise texture
#endif  //FULL
cbuffer HFLandFP_CB1 : register(b1)
{
float3 koeffNdotL;

};
#ifdef SHADOW_OLD
	Texture2D ShadowMap : register(t2);
	SamplerState ShadowMap_Sampler : register(s2);           //shadow map

#ifdef PSSM
// PSSM implemetation
// matrix array
cbuffer HFLandFP_CB2 : register(b2)
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
#ifdef SHADOW_OLD
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

float getPSSMPixel2 (float4 world_coords)
{
    float4 shad_coord;
	float4 shadow_sample;

	// 0 level	
	//float4 shad_coord0 = mul(PSSMProjTexMatrix0, float4(world_coords.xyz, 1));
	//float4 shad_coord1 = mul(PSSMProjTexMatrix1, float4(world_coords.xyz, 1));
	//float4 shad_coord2 = mul(PSSMProjTexMatrix2, float4(world_coords.xyz, 1));
	//float4 shad_coord3 = mul(PSSMProjTexMatrix3, float4(world_coords.xyz, 1));

	float4 sm_k;
	

	//sm_k.x = step(0, world_coords.w) - step(10, world_coords.w);
	//sm_k.y = step(10, world_coords.w) - step(50, world_coords.w);
	//sm_k.z = step(50, world_coords.w) - step(220, world_coords.w);
	//sm_k.w = step(220, world_coords.w) - step(1200, world_coords.w);

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

	float3 sm_offs =	sm_k.x * float3(0.0, 0.5, 0.0) +
						sm_k.y * float3(0.5, 0.5, 0.0) + 
						sm_k.z * float3(0.0, 0.0, 0.0) + 
						sm_k.w * float3(0.5, 0.0, 0.0);

	//float2 sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	float shadow_factor = 1.0;

	//if (0)
	//{
	//	return 1;
	//}
	//else if (0)
	//{
	//	//shadow_sample = tex2D(ShadowMap, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
	//	shadow_factor = getShadowPixel(sm_offs + float3(0.5*shad_coord.xy, shad_coord.z));
	//}
	//else
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

	float2 sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

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

#endif  //SHADOW

float4 main(in VertexOut IN
			) : SV_Target0
{
//    Ka = float4(0.2, 0.2, 0.2, 0.0);  //???????????? - test only

	float4 Land = LandTex.Sample(LandTex_Sampler, IN.TexCoord0);
	float3 LandNormal = Land.rgb;
	float4 diffuse_light;
    diffuse_light.rgb = (Kd).rgb;
    float ndl = Land.a;
	float LandLight = Land.a;

#ifdef FULL
	//--modulate with common noise--
	float4 Noise = LandCommonNoiseTex.Sample(LandCommonNoiseTex_Sampler, IN.TexCoord1);
    Land.rgb *= Noise.rgb * 2.0f;

#ifdef SHADOW_OLD
	float ShadowFactor = 1;

#ifdef PSSM
	ShadowFactor = getPSSMPixel3(IN.TexCoord2);

#else
    //---shadows---
	float4 Shadow = float4(1,0,0,1);
    Shadow = ShadowMap.Sample(ShadowMap_Sampler, (IN.TexCoord2.xyzw).xy / (IN.TexCoord2.xyzw).w);

#ifndef COMPAREZ  
	ShadowFactor = Shadow.r;   //0 or 1
#else  //COMPAREZ
	float zProj = IN.TexCoord2.z/IN.TexCoord2.w;
	ShadowFactor = (zProj > Shadow.r)?0:1;
	ShadowFactor = (Shadow.r>0)?ShadowFactor:1;
#endif //COMPAREZ
#endif // PSSM

	//ndl *= ShadowFactor;
	//-------------
#endif  //SHADOW

#endif //FULL

	//Land.rgb = clamp(Ka.rgb + diffuse_light.rgb, 0.0, 1.0) * Land.rgb;
	ndl = clamp(ndl*koeffNdotL.x+koeffNdotL.y, 0, 1);
	Land.rgb *= lerp(Ka.rgb, diffuse_light.rgb*koeffNdotL.z, ndl);

	float fogBorder1 = 1.0f/8.0f;
	float fogBorder2 = 1.0f - fogBorder1;
	
	if (IN.TexCoord3.x > fogBorder1 && IN.TexCoord3.x < fogBorder2 && IN.TexCoord3.y > fogBorder1 && IN.TexCoord3.y < fogBorder2)
	{
		Land.a = 1.0f;
	}
	else
	{	
		float alphaX = smoothstep(0.0f, fogBorder1, IN.TexCoord3.x) * (1.0f - smoothstep(fogBorder2, 1.0f, IN.TexCoord3.x));
		float alphaY = smoothstep(0.0f, fogBorder1, IN.TexCoord3.y) * (1.0f - smoothstep(fogBorder2, 1.0f, IN.TexCoord3.y));

		Land.a = alphaX * alphaY;
	}
	
	return Land; 
	//return float4(normalize(2.f*LandNormal-1.f), 1.0f);
	//LandLight = (LandLight-50.f/128.f)*2;
	//return LandLight.xxxx;
	//return float4(LandNormal, 1.0f);
}


