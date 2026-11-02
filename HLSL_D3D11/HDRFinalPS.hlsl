// D3D11 port of HDRFinalPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float2	texCoord		: TEXCOORD0;
	float2	texCoord2		: TEXCOORD1;	
};

//-----------------------------------------------------------------------------
//	uniforms
//-----------------------------------------------------------------------------

Texture2D TexMap1 : register(t0);
SamplerState TexMap1_Sampler : register(s0);	// Render buffer texture
Texture2D TexMap2 : register(t1);
SamplerState TexMap2_Sampler : register(s1);	// Luminance texture
Texture2D BloomMap : register(t2);
SamplerState BloomMap_Sampler : register(s2);	// Bloomed texture
Texture2D DepthMap : register(t3);
SamplerState DepthMap_Sampler : register(s3);	// depth texture
TextureCube SkyCube : register(t4);
SamplerState SkyCube_Sampler : register(s4);	// sky cube texture

// fog uniforms
//#ifdef USE_FOG

cbuffer HDRFinalPS_CB0 : register(b0)
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
cbuffer HDRFinalPS_CB1 : register(b1)
{
	float cSimpleDensity;
};
#endif //SIMPLE_FOG_OLD

///#endif // USE_FOG


cbuffer HDRFinalPS_CB2 : register(b2)
{
float4 dataHDR;
float4 bloomTexSize;

//static const float fExposure = 1.0f;
//static const float fGaussianScalar = 0.0;
};
static const float3 LUMINANCE_WEIGHT = float3( 0.299f, 0.587f, 0.114f );

//-----------------------------------------------------------------------------
//	getBloomPixel
float3 getBloomPixel(float2 t)
{
	return BloomMap.Sample(BloomMap_Sampler, t).rgb;
}

//-----------------------------------------------------------------------------
//	getBloomFilteredPixel
float3 getBloomFilteredPixel(float2 t)
{
	float g_rcp_bloom_tex_w = bloomTexSize.x;//1.f/(1024/8);
	float g_rcp_bloom_tex_h = bloomTexSize.y;//1.f/(768/8);
    // Compute the blur value using a bilinear filter
    // It is worth noting that if the hardware supports linear filtering of a
    // floating point render target that this step can probably be skipped.
        float xWeight = frac( t.x * g_rcp_bloom_tex_w ) - 0.5;
        float xDir = xWeight;
        xWeight = abs( xWeight );
        xDir /= xWeight;
        xDir /= g_rcp_bloom_tex_w;

        float yWeight = frac( t.y * g_rcp_bloom_tex_h ) - 0.5;
        float yDir = yWeight;
        yWeight = abs( yWeight );
        yDir /= yWeight;
        yDir /= g_rcp_bloom_tex_h;

    // sample the blur texture for the 4 relevant pixels, weighted accordingly
        float4 b = ((1.0f - xWeight) * (1.0f - yWeight))    * BloomMap.Sample(BloomMap_Sampler, t);        
        b +=       (xWeight * (1.0f - yWeight))             * BloomMap.Sample(BloomMap_Sampler, t + float2( xDir, 0.0f ));
        b +=       (yWeight * (1.0f - xWeight))             * BloomMap.Sample(BloomMap_Sampler, t + float2( 0.0f, yDir ));
        b +=       (xWeight * yWeight)                      * BloomMap.Sample(BloomMap_Sampler, t + float2( xDir, yDir ));
	return b.rgb;
}

//-----------------------------------------------------------------------------
//	calcTonemap
float3 calcTonemap(float4 l, float3 final)
{
	float fExposure = dataHDR.x;
	float fGaussianScalar = dataHDR.y;
	float Lp = (fExposure / l.r) * max( final.r, max( final.g, final.b ) );
	//float Lp = (fExposure / l.r) * dot(final, LUMINANCE_WEIGHT);
	float LmSqr = (l.g + fGaussianScalar * l.g) * (l.g + fGaussianScalar * l.g);
	float toneScalar = ( Lp * ( 1.0f + ( Lp / ( LmSqr ) ) ) ) / ( 1.0f + Lp );
	return final * toneScalar;
}

//-----------------------------------------------------------------------------
//	calcTonemap2
float3 calcTonemap2(float4 l, float3 final)
{
  // Reinhard with White Point
  // todo: combine fTargetAvgLum into fAdaptedLumDest

	float fWhitePoint = dataHDR.x;
	float g_fMiddleGray = dataHDR.y;	

	float fTargetAvgLum = g_fMiddleGray;

	float fInvWhitePoint2 = 1.0/(fWhitePoint*fWhitePoint);
	//float fInvWhitePoint2 = 1.0/(l.y*l.y);

	float fAdaptedLumDest = l.x;//EyeAdaption(fAdaptedLum);		// RangeReducedAdaptedLum
	  
	//float fLum = dot(final,LUMINANCE_WEIGHT);		// add small value to avoid division by 0
	float fLum = max(final.x, max(final.y, final.z));

  	// lerp between night adaption (desaturated, blue shifted but same brightness level) and colored scene (can be put in texture)
	// to have same brightness the noise is multiplied by 2(average 0.5)
	//vSample.rgb = lerp((tex2D(noiseMap,IN.baseTCRnd.xy).xyz) * fLum * float3(0.8f,0.8f,1.4f)*2.0f, vSample.rgb, saturate(5.0f*fLum));

	// hack to test without noise
	//final.rgb = lerp(0.5 * fLum * float3(1.4,0.8,0.8)*2.0, final.rgb, clamp(6.5*fLum, 0.0, 1.0));

	//float3 shiftColor = float3(0.5, 0.5, 0.5);
	//final.rgb = lerp((shiftColor) * fLum * float3(0.8f,0.8f,1.4f)*2.0f, final.rgb, saturate(5.0f*fLum));

	float Ls = fTargetAvgLum * fLum / fAdaptedLumDest;
	float Ld = Ls * (1.0+Ls*fInvWhitePoint2) / (1.0+Ls);
//gl_FragColor = vec4(fAdaptedLum, fAdaptedLum, fAdaptedLum, 1);
//gl_FragColor = vec4(vSample.rgb, 1);
//return;
	  	
	final.rgb *= Ld/fLum;
	return final;
}

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
//	restoreWorldSpace
float3	getFogedPixel(in VertexOUT IN, in float3 color )
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

	if (depth > 10000)
	{
		fog=0;
	}

#endif //SIMPLE_FOG_OLD
	
	// read sky cube	
	//float3 fog_uv = float3(dP.x, dP.y, -saturate(-dP.z));
	float3 fog_uv = float3(dP.x*CosSin.x+dP.y*CosSin.y, dP.x*CosSin.z+dP.y*CosSin.w, -saturate(-dP.z));
	fog_uv = float3(cTexScale*fog_uv.xy, -1);


	// shade pixel
	float4 fog_color = SkyCube.Sample(SkyCube_Sampler, fog_uv);
	//fog_color.rgb = lerp(fog_color.rgb, fog_color.rgb*fSkyMultiplier, fog_color.a);
	fog_color.rgb = lerp(fog_color.rgb, fog_color.rgb, fog_color.a);
	// compute final color
	float3 res_color;
	res_color = lerp(color.rgb, fog_color.rgb, fog);

	return res_color;
}


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(in VertexOUT IN) : SV_Target0
{
 	float3 c = TexMap1.Sample(TexMap1_Sampler, IN.texCoord).rgb;

	// c = getFogedPixel(IN, c);

// hdr --------------------------------------------------
	float4 l = TexMap2.Sample(TexMap2_Sampler, float2(0.5, 0.5));

	float3 bloom = getBloomFilteredPixel(IN.texCoord);
	//float3 bloom = getBloomPixel(IN.texCoord);

	bloom *= dataHDR.z;
	float3 final = bloom+c;
	float3 result = calcTonemap2(l, final);

// end hdr --------------------------------------------------


	//float4 ssao = tex2D(SSAOMap, IN.texCoord);
	//result.rgb *= ssao.rgb;// * ssao.r * ssao.r * ssao.r * ssao.r * ssao.r;	
	//result.rgb *= clamp(0.3f + tex2D(SSShadowMap, IN.texCoord).rgb, 0.0, 10.0);
	//result.rgb = tex2D(SSShadowMap, IN.texCoord).rgb;
	//result.rgb = 0.0001*tex2D(DepthMap, IN.texCoord).rrr;
	//return float4(getFogedPixel(IN, float3(0.5, 0.5, 0.5)), 1);
	
	return float4(result, 1.0);
}