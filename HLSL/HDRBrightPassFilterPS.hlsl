// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

uniform sampler2D TexMap: register(s0); // Base texture
uniform sampler2D TexMap2: register(s1); // Base texture

uniform float4 dataHDR;

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
	//final.rgb = lerp(0.5 * fLum * float3(0.8,0.8,1.4)*2.0, final.rgb, clamp(6.5*fLum, 0.0, 1.0));

	//float3 shiftColor = float3(0.5, 0.5, 0.5);
	//final.rgb = lerp((shiftColor) * fLum * float3(0.8f,0.8f,1.4f)*2.0f, final.rgb, saturate(5.0f*fLum));

	float Ls = fTargetAvgLum * fLum / fAdaptedLumDest;
	float Ld = Ls * (1.0+Ls*fInvWhitePoint2) / (1.0+Ls);
	  	
	final.rgb *= Ld/fLum;
	return final;
}

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float3 vSample = tex2D(TexMap, IN.texCoord).rgb;
	float4 l = tex2D(TexMap2, float2(0.5,0.5));
	float3 LUMINANCE_WEIGHT = float3( 0.299f, 0.587f, 0.114f );
	float fBrightMIN = dataHDR.w;

	//vSample = calcTonemap2(l, vSample);
	//vSample = saturate(vSample-float3(fBrightMIN,fBrightMIN,fBrightMIN));
	vSample = (vSample-float3(fBrightMIN,fBrightMIN,fBrightMIN));
	vSample = max(vSample, float4(0,0,0,0));
	//vSample *= fBrightMIN/(1+fBrightMIN);

	//float sample_lum = max( vSample.r, max( vSample.g, vSample.b ) );
	//if (sample_lum < fBrightMIN)
	//	vSample = float4(0,0,0,1);

	float lum = dot(vSample, LUMINANCE_WEIGHT);
	vSample = lerp(vSample, lum.xxx, dataHDR.z);
	
	return float4(vSample,1.0);
}