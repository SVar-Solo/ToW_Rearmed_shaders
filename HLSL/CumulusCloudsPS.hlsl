// From vertex shader
struct VertexOUT
{
	float4 TEX0 : TEXCOORD0;
	float3 Dist : TEXCOORD1;
	float3 UpDir : TEXCOORD2;
	float3 SunDir : TEXCOORD3;
};

uniform sampler2D CulumusCloudsMap: register(s0); // Base texture
uniform sampler2D SphereNormalMap: register(s1); // Bump texture
uniform float3 CloudAmbientColor;
uniform float3 CloudDiffuseColor;
uniform float3 SunColor;
uniform float2 CloudsTransparentRange;

float4 main(in VertexOUT IN // From vertex shader
			//,out float depth : DEPTH
			) : COLOR
{
	float4 CloudsTex = tex2D(CulumusCloudsMap, IN.TEX0.xy);
	float3 NormTex = tex2D(SphereNormalMap, IN.TEX0.xy).rgb*2-1;

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


