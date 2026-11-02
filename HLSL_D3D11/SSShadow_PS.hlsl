// D3D11 port of SSShadow_PS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2 TexCoord : TEXCOORD0;
	float2 TexCoord2 : TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	uniforms
//-----------------------------------------------------------------------------

Texture2D DepthMap : register(t0);
SamplerState DepthMap_Sampler : register(s0); // Base texture
Texture2D ShadowMap : register(t1);
SamplerState ShadowMap_Sampler : register(s1); // Shadow map texture

cbuffer SSShadow_PS_CB0 : register(b0)
{
column_major float4x4 CamModelViewInv;
float2 Unproject;
//uniform sampler2D	RandSample: register(s1); // Base texture
/*
column_major float4x4 ModelView;
column_major float4x4 CamModelView;
column_major float4x4 CamProj;
column_major float4x4 CamModelViewInv;
column_major float4x4 CamProjInv;

float3 FrustumV0;
float3 FrustumV1;
float3 FrustumV2;
float3 FrustumV3;
*/

// matrix array
column_major float4x4 PSSMProjTexMatrix0;
column_major float4x4 PSSMProjTexMatrix1;
column_major float4x4 PSSMProjTexMatrix2;
column_major float4x4 PSSMProjTexMatrix3;

/*
column_major float4x4 PSSMModelTexMatrix0;
column_major float4x4 PSSMModelTexMatrix1;
column_major float4x4 PSSMModelTexMatrix2;
column_major float4x4 PSSMModelTexMatrix3;
*/
float4 PSSMModelTexMatrix0o;
float4 PSSMModelTexMatrix1o;
float4 PSSMModelTexMatrix2o;
float4 PSSMModelTexMatrix3o;

/*
float PSSMSplit0;
float PSSMSplit1;
float PSSMSplit2;
float PSSMSplit3;
*/
float4 PSSMSplitN;

// fade distance
/*
float PSSMFadeDist;
float PSSMWidth;
*/
float2 PSSMFadeDist_PSSMWidth;


//-----------------------------------------------------------------------------
//	getShadow_ZLod
};
float
getShadow_ZLod(float4 world_coords)
{
    float4 shad_coord = float4(0, 0, 0, 0);
	float4 shadow_sample = float4(0, 0, 0, 0);

	float4 sm_k = float4(0, 0, 0, 0);
	

	//sm_k.x = step(0, world_coords.w) - step(PSSMSplit0, world_coords.w);
	//sm_k.y = step(PSSMSplit0, world_coords.w) - step(PSSMSplit1, world_coords.w);
	//sm_k.z = step(PSSMSplit1, world_coords.w) - step(PSSMSplit2, world_coords.w);
	//sm_k.w = step(PSSMSplit2, world_coords.w) - step(PSSMSplit3, world_coords.w);
/*
	sm_k.x = world_coords.w > 0 ? (world_coords.w < PSSMSplit0 ? 1.0 : 0.0) : 0.0;
	sm_k.y = world_coords.w > PSSMSplit0 ? (world_coords.w < PSSMSplit1 ? 1.0 : 0.0) : 0.0;
	sm_k.z = world_coords.w > PSSMSplit1 ? (world_coords.w < PSSMSplit2 ? 1.0 : 0.0) : 0.0;
	sm_k.w = world_coords.w > PSSMSplit2 ? (world_coords.w < PSSMSplit3 ? 1.0 : 0.0) : 0.0;
*/
	sm_k.x = world_coords.w > 0 ? (world_coords.w < PSSMSplitN.x ? 1.0 : 0.0) : 0.0;
	sm_k.y = world_coords.w > PSSMSplitN.x ? (world_coords.w < PSSMSplitN.y ? 1.0 : 0.0) : 0.0;
	sm_k.z = world_coords.w > PSSMSplitN.y ? (world_coords.w < PSSMSplitN.z ? 1.0 : 0.0) : 0.0;
	sm_k.w = world_coords.w > PSSMSplitN.z ? (world_coords.w < PSSMSplitN.w ? 1.0 : 0.0) : 0.0;

	float sm_k_none = 1 - (dot(sm_k, sm_k)); // step(PSSMSplit3, world_coords.w); //  ? 1 : 0;
	


// 	sm_k.x = 1;
// 	sm_k.y = 0;
// 	sm_k.z = 0;
// 	sm_k.w = 0;
// 	sm_k_none = 0;


	float4x4 sh_m = sm_k.x*PSSMProjTexMatrix0 +
					sm_k.y*PSSMProjTexMatrix1 + 
					sm_k.z*PSSMProjTexMatrix2 + 
					sm_k.w*PSSMProjTexMatrix3;
					
/*					
	float4x4 sh_mv = sm_k.x*PSSMModelTexMatrix0 +
					 sm_k.y*PSSMModelTexMatrix1 + 
					 sm_k.z*PSSMModelTexMatrix2 + 
					 sm_k.w*PSSMModelTexMatrix3;
*/	
	float4 sh_mv_z = sm_k.x*PSSMModelTexMatrix0o +
					 sm_k.y*PSSMModelTexMatrix1o + 
					 sm_k.z*PSSMModelTexMatrix2o + 
					 sm_k.w*PSSMModelTexMatrix3o;

	//shad_coord = sm_k.x*shad_coord0 + sm_k.y*shad_coord1 + sm_k.z*shad_coord2 + 
	//	sm_k.w*shad_coord3;
	
	shad_coord = mul(sh_m, float4(world_coords.xyz, 1));
	shad_coord.xyz /= shad_coord.w;
	
	
	float z_eps =	sm_k.x*0.0001 + 
					sm_k.y*0.00025 + 
					sm_k.z*0.0006 + 
					sm_k.w*0.0008;
	
	if (0)	z_eps = 0.0001;

	float3 sm_offs =	sm_k.x * float3(0.0, 0.5, 0.0) +
						sm_k.y * float3(0.5, 0.5, 0.0) + 
						sm_k.z * float3(0.0, 0.0, 0.0) + 
						sm_k.w * float3(0.5, 0.0, 0.0);

	float sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	float shadow_factor = 1.0;
	float dist = 0.0;

	if (0)
	{
		return 1;
	}
	else if (0)
	{		
		// changed shadow_factor		
		shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
		shadow_factor = (shad_coord.z - z_eps > shadow_sample.r) ? 1 : 0;
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;	
				
		// change sign
		//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
		//shadow_factor = 1 - shadow_factor; // negated after call
	}
	else if (1)
	{
	
		//dist = -0.001f * mul(sh_mv, float4(world_coords.xyz, 1)).z;
		dist = -0.001f * dot(sh_mv_z, float4(world_coords.xyz, 1));
		
		// changed shadow_factor		
		shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
		shadow_factor = (dist  - z_eps > shadow_sample.r) ? 1 : 0;
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;
		
		// change sign
		shadow_factor = shadow_factor * saturate(1 - saturate((world_coords.w - PSSMSplitN.w + PSSMFadeDist_PSSMWidth.x)/PSSMFadeDist_PSSMWidth.x));
		shadow_factor = 1 - shadow_factor;
	}
	else if (0)	// variance
	{
		//dist = -0.001 * mul(sh_mv, float4(world_coords.xyz, 1)).z;
		dist = -0.001f * dot(sh_mv_z, float4(world_coords.xyz, 1));
		
		// changed shadow_factor		
		shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
				
		if (dist < shadow_sample.r)
		{
			shadow_factor = 0;
		}
		else
		{
			float sigma2 = shadow_sample.g - shadow_sample.r * shadow_sample.r;
			shadow_factor = 1 - sigma2 / (sigma2 + (dist - shadow_sample.r)	* (dist -  shadow_sample.r));
		}
	
		shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;	
				
		// change sign
		//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
		shadow_factor = 1 - shadow_factor;
	}
	
	//return sm_scale;
	//return sm_scale*shadow_factor;
	return shadow_factor; //  + sm_k_none;
	//return sm_k_none;
}

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

	float4x4 sh_m = sm_k.x*PSSMProjTexMatrix0 +
					sm_k.y*PSSMProjTexMatrix1 + 
					sm_k.z*PSSMProjTexMatrix2 + 
					sm_k.w*PSSMProjTexMatrix3;
					
/*					
	float4x4 sh_mv = sm_k.x*PSSMModelTexMatrix0 +
					 sm_k.y*PSSMModelTexMatrix1 + 
					 sm_k.z*PSSMModelTexMatrix2 + 
					 sm_k.w*PSSMModelTexMatrix3;
*/
	float4 sh_mv_z = sm_k.x*PSSMModelTexMatrix0o +
					 sm_k.y*PSSMModelTexMatrix1o + 
					 sm_k.z*PSSMModelTexMatrix2o + 
					 sm_k.w*PSSMModelTexMatrix3o;
	//shad_coord = sm_k.x*shad_coord0 + sm_k.y*shad_coord1 + sm_k.z*shad_coord2 + 
	//	sm_k.w*shad_coord3;
	
	shad_coord = mul(sh_m, float4(world_coords.xyz, 1));
	shad_coord.xyz /= shad_coord.w;
	
	
	float z_eps =	sm_k.x*0.0001 + 
					sm_k.y*0.0002 + 
					sm_k.z*0.0004 + 
					sm_k.w*0.0008;
	
	if (0)	z_eps = 0.0002;

	float3 sm_offs =	sm_k.x * float3(0.0, 0.5, 0.0) +
						sm_k.y * float3(0.5, 0.5, 0.0) + 
						sm_k.z * float3(0.0, 0.0, 0.0) + 
						sm_k.w * float3(0.5, 0.0, 0.0);

	float sm_scale = sm_k.x*0.8 + sm_k.y*0.6 + sm_k.z*0.4 + sm_k.w*0.2;

	float shadow_factor = 1.0;
	float dist = 0.0;
	
	//dist = -0.001f * mul(sh_mv, float4(world_coords.xyz, 1)).z;
	dist = -0.001f * dot(sh_mv_z, float4(world_coords.xyz, 1));
		
	// changed shadow_factor		
	shadow_sample = ShadowMap.Sample(ShadowMap_Sampler, float2(sm_offs.x + 0.5*shad_coord.x, sm_offs.y + 0.5*shad_coord.y));
	shadow_factor = (dist  - z_eps > shadow_sample.r) ? 1 : 0;
	shadow_factor = shadow_sample.r > 0 ? shadow_factor : 0;
	
	// change sign
	//shadow_factor = shadow_factor*saturate(1 - saturate((world_coords.w - PSSMSplit3 + 20)/20));
	shadow_factor = 1 - shadow_factor;
	
	return shadow_factor;
	//return sm_scale*shadow_factor;
		
}

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------
/*
float4 restoreWorldSpace(in VertexOUT IN, float depth)
{
	// restore world position	
	
	float2 PixelSize = float2(1.0f/1280.0f, 1.0f/960.0f);
	
	//convert from clip space to view space
	float x = (IN.TexCoord.x) * 2.0f - 1.0f;
	float y = (1.0f - IN.TexCoord.y) * 2.0f - 1.0f;
	float z = depth;
	
	// camera direction
	float3 dir = lerp(lerp(FrustumV2, FrustumV3, IN.TexCoord.x), lerp(FrustumV0, FrustumV1, IN.TexCoord.x), IN.TexCoord.y);
	dir = normalize(dir);
	
	//float3 dir = normalize(float3(x/CamProj[0].x, -y/CamProj[1].y, 1.0f)); 
	//float3 dir = normalize(float3(-x, y, -z));
	
	//x,y,z were set above for clarity
	float4 viewportPos = float4(dir.x*depth/dir.z, dir.y*depth/dir.z, -depth, 1 ); // w = 1
	
	//Transform the point into world space
	float4x4 temp_mat = CamModelViewInv;	
	float4 worldPosD = float4(0,0,0,1);
	
	float3x3 mat3x3 = float3x3 (CamModelView[0].xyz, CamModelView[1].xyz, CamModelView[2].xyz);
	//float3x3 mat3x3 = float3x3 (ModelViewProjInv[0].xyz, ModelViewProjInv[1].xyz, ModelViewProjInv[2].xyz);
	
	worldPosD.xyz = mul(viewportPos.xyz, mat3x3);
	//worldPosD.xyz = dot(CamModelView[0].xyz, CamModelView[3].xyz) + 
	//	dot(CamModelView[1].xyz, CamModelView[3].xyz) + 
	//	dot(CamModelView[2].xyz, CamModelView[3].xyz) ; 
	
	worldPosD.xyz += float3(CamModelViewInv[0].w, CamModelViewInv[1].w, CamModelViewInv[2].w);
		
	// float3(CamModelView[0].w, CamModelView[1].w, CamModelView[2].w);
	
	//float4 worldPosD2 = mul(CamModelView, worldPosD);
	// float4 worldPosD2 = mul(CamModelView, worldPosD);
	
	//worldPosD = mul(ModelViewProjInv, viewportPos);
	//worldPosD.z = 0;
	return worldPosD;
}
*/
float4 restoreWorldSpace_fast(in VertexOUT IN, float depth)
{
	// restore world position
	float4 worldPosD = float4(0,0,0,1);
	//convert from clip space to view space
	float x = (1.0f - IN.TexCoord.x) * 2.0f - 1.0f;
	float y = (IN.TexCoord.y) * 2.0f - 1.0f;
	float z = -depth;
	worldPosD = float4((float3(x/Unproject.x, y/Unproject.y, 1.f))*z, 1.f);
	worldPosD = mul(CamModelViewInv, worldPosD);

	return worldPosD;
}

float4 main(in VertexOUT IN) : SV_Target0
{
	float depth = DepthMap.Sample(DepthMap_Sampler, IN.TexCoord).r;   
	//float4 worldPosD = restoreWorldSpace(IN, depth);
	float4 worldPosD = restoreWorldSpace_fast(IN, depth);
	//float4 worldPosD = restoreWorldSpace(IN, depth)*0.5f + restoreWorldSpace_fast(IN, depth)*0.5f;
	float4 res;
	res = float4(getShadow_ZLod(float4(worldPosD.xyz, depth)).xxx, 1);
	
	// debug
	//res = worldPosD/2048.f;
	
	return res;
}

