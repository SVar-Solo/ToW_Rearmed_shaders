// From vertex shader
struct VertexOUT
{
	float2 TEX0 : TEXCOORD0;
	float2 TEX1 : TEXCOORD1;
	float4 Data : TEXCOORD2; // x - border alpha
};

uniform float fCloudsMultiplier;
uniform sampler2D HighCloudsMap: register(s0); // Base texture
uniform sampler2D CloudsNoiseMap: register(s1); // Base texture
uniform float3 CloudAmbientColor;
uniform float3 CloudDiffuseColor;

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float4 CloudsColor = tex2D(HighCloudsMap, IN.TEX0);
	float4 NoiseClouds = tex2D(CloudsNoiseMap, IN.TEX1);
	//return float4(((1-CloudsColor.rgb)*1.5+1.0), CloudsColor.g*NoiseClouds.g*IN.Data.x);
	float niz = CloudsColor.x*NoiseClouds.x;
	//float3 cloud = lerp(float3(97/255.0f,102/255.0f,102/255.0f), 0.6*float3(173/255.0f,186/255.0f,206/255.0f), cloudDepth*cloudDepth);
	//float3 cloud = CloudDiffuseColor * (1-(niz * niz)) + CloudAmbientColor;
	float3 cloud = float3(1.0,1.0,1.0)*fCloudsMultiplier;//CloudDiffuseColor + CloudAmbientColor;
	return float4( cloud, clamp(IN.Data.x*niz,0,1));
}


