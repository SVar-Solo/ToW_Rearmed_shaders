// D3D11 port of CumulusCloudsPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float4 TEX0 : TEXCOORD0;
	float3 Dist : TEXCOORD1;
	float3 UpDir : TEXCOORD2;
	float3 SunDir : TEXCOORD3;
};

Texture2D CulumusCloudsMap : register(t0);
SamplerState CulumusCloudsMap_Sampler : register(s0); // Base texture
Texture2D SphereNormalMap : register(t1);
SamplerState SphereNormalMap_Sampler : register(s1); // Bump texture
cbuffer CumulusCloudsPS_CB0 : register(b0)
{
float3 CloudAmbientColor;
float3 CloudDiffuseColor;
float3 SunColor;
float2 CloudsTransparentRange;

};
float4 main(in VertexOUT IN // From vertex shader
			//,out float depth : DEPTH
			) : SV_Target0
{
	float4 CloudsTex = CulumusCloudsMap.Sample(CulumusCloudsMap_Sampler, IN.TEX0.xy);
	float3 NormTex = SphereNormalMap.Sample(SphereNormalMap_Sampler, IN.TEX0.xy).rgb*2-1;

	float sunL = saturate(dot(NormTex.rgb, normalize(IN.SunDir+NormTex.rgb*(0.4))));
	float niz = saturate(dot(NormTex.rgb, normalize(IN.UpDir+NormTex.rgb*(0.4))));

	//float3 cloud = CloudDiffuseColor * (SunColor * sunL + niz.xxx + CloudAmbientColor);
	float3 cloud = lerp(CloudAmbientColor, CloudDiffuseColor, sunL);
	
	float D1 = CloudsTransparentRange.x;
	float D2 = CloudsTransparentRange.y;
	
	// linear fade
	float factor = 1-clamp((IN.Dist.x-D1)/(D2-D1), 0, 1);

	// exponent fade
	//float FogDensity = 0.0001f * IN.Dist.x;
	//float factor = clamp(0.f, exp(-FogDensity*FogDensity), 1.f);
	//cloud = lerp(float3(1,0,0), float3(1,1,1), clamp(0.f, factor*factor*factor*factor);

	//float sx = IN.TEX0.x*2-1;
	//float sy = IN.TEX0.y*2-1;
	//float zOffset = sqrt(sx*sx+sy*sy);
	//if (zOffset>1 || CloudsTex.g==0) discard;
	//depth = (IN.Dist.x + IN.Dist.z*(zOffset))/IN.Dist.y;
	//depth = (IN.Dist.x -(1-zOffset))/IN.Dist.y;
	//depth = (IN.Dist.x)/IN.Dist.y;
//	return float4( (1-zOffset).xxx , 0.5);

	return float4( cloud , CloudsTex.g*factor);
}


