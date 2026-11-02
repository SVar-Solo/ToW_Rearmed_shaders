// D3D11 port of SSFog_PS.hlsl. Generated from the legacy HLSL source; see README.md.
//#define SIMPLE_FOG_OLD

// From vertex shader
struct VertexOUT
{
	float2	texCoord		: TEXCOORD0;
	float2	texCoord2		: TEXCOORD1;
};

//-----------------------------------------------------------------------------
//	uniforms
//-----------------------------------------------------------------------------

Texture2D DepthMap : register(t0);
SamplerState DepthMap_Sampler : register(s0); // Scene depth texture
TextureCube SkyCube : register(t1);
SamplerState SkyCube_Sampler : register(s1);	// sky cube texture

cbuffer SSFog_PS_CB0 : register(b0)
{
column_major float4x4 CamModelViewInv;
float2 Unproject;

float3 CamPos;
float cTexScale;			// for calc texture coordinate in texture with fog RGB color
float4 cFogHBounds;		// cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
float4 cFogABAB;			// A1,B1,A2,B2
float4 CosSin;
float fSkyMultiplier;


};
#ifdef SIMPLE_FOG_OLD
cbuffer SSFog_PS_CB1 : register(b1)
{
	float cSimpleDensity;
};
#endif //SIMPLE_FOG_OLD


//-----------------------------------------------------------------------------
//Calculate integral fog density throw 2 fog layers
//Attention: Note!!! A*=0.5
float IntegralHDense2(in float4 cFogHBounds,       //cMinFogH1 cMaxFogH1 cMinFogH2 cMaxFogH2
					  in float4 cFogABAB,          //xy=A1B1, zw=A2B2
					  in float H0, in float H1)    //height for camera and vertex				 
{
	float4 HH = float4(H0, H1, H0, H1);
	HH = clamp(HH, cFogHBounds.xxzz, cFogHBounds.yyww);   //here HH=(hMin1,hMax1,hMin2,hMax2)
	float4 ff = HH*(HH*cFogABAB.xxzz + cFogABAB.yyww);
	return dot(ff, float4(-1.0f, 1.0f, -1.0f, 1.0f)); 
}

//-----------------------------------------------------------------------------
//	restoreWorldSpace
float4 restoreWorldSpace(in VertexOUT IN, float depth)
{
	// restore world position
	float4 worldPosD = float4(0, 0, 0,1);

	//convert from clip space to view space
	float x = (1.0f - IN.texCoord.x) * 2.0f - 1.0f;
	float y = (IN.texCoord.y) * 2.0f - 1.0f;
	float z = -depth;
	worldPosD = float4((float3(x/Unproject.x, y/Unproject.y, 1.f))*z, 1.f);
	worldPosD = mul(CamModelViewInv, worldPosD);

	return worldPosD;
}

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(in VertexOUT IN) : SV_Target0
{
	float depth = DepthMap.Sample(DepthMap_Sampler, IN.texCoord).r;   
	
	float4 world_pos = restoreWorldSpace(IN, depth);

	float3 dP = world_pos.xyz - CamPos;
	float dist = length(dP);

#ifdef SIMPLE_FOG_OLD

	float II = cSimpleDensity*dist;
	float fog = 1.0-exp(-II);

#else //SIMPLE_FOG_OLD

	//--main fog calculation--
	float H0 = CamPos.z;
	float H1 = world_pos.z;
	float DH = H1-H0;

	//--work around singularity - (devizion by 0)--
	//!!! correct slightly H1 !!!
	const float eps = 1.0E-1;   //[m]
	if(abs(DH) < eps) 
	{
		H1 += 2.0*eps;
		DH = H1-H0;
	}

	float InvSinAlfa = dist/DH;
	float II = InvSinAlfa*IntegralHDense2(cFogHBounds, cFogABAB, H0, H1);  
	float fog = 1.0 - exp(-abs(II));

#endif //SIMPLE_FOG_OLD

	// read sky cube	
	//float3 fog_uv = float3(dP.x, dP.y, -saturate(-dP.z));
	float3 fog_uv = float3(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z));
	fog_uv = float3(cTexScale*fog_uv.xy, -1);

	// shade pixel
	float4 fog_color = SkyCube.Sample(SkyCube_Sampler, fog_uv);
	//fog_color.rgb = lerp(fog_color.rgb, fog_color.rgb*fSkyMultiplier, fog_color.a);
	fog_color.rgb = lerp(fog_color.rgb, fog_color.rgb, fog_color.a);

	if (depth > 10000)
	{
		return float4(fog_color.rgb, 0);
	}
	else
	{
		//отсечение на дальней границе ландшафта. Хак для реализации плавного перехода.
		float minCoord = -3072.0f; //границы ландшафта
		float maxCoord = 5120.0f; //границы ландшафта
		float normalizedX = (world_pos.x - minCoord) / (maxCoord - minCoord);
		float normalizedY = (world_pos.y - minCoord) / (maxCoord - minCoord);
		float2 normWP = float2(normalizedX, normalizedY);

		float fogBorder1 = 0.5f/8.0f;
		float fogBorder2 = 1.0f - fogBorder1;
		
		if (normWP.x > fogBorder1 && normWP.x < fogBorder2 && normWP.y > fogBorder1 && normWP.y < fogBorder2)
		{
			fog = fog * 1.0f;
		}
		else
		{	
			float alphaX = smoothstep(0.0f, fogBorder1, normWP.x) * (1.0f - smoothstep(fogBorder2, 1.0f, normWP.x));
			float alphaY = smoothstep(0.0f, fogBorder1, normWP.y) * (1.0f - smoothstep(fogBorder2, 1.0f, normWP.y));

			fog = fog * alphaX * alphaY;
		}
		
		return float4(fog_color.rgb, fog);
		//return float4(1, 0, 0, fog);
	}
}

