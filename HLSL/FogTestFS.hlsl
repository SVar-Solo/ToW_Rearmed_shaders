// From vertex shader
struct vfconn
{
	float4 Color0    : COLOR0;
	float3 fogCoord : TEXCOORD0;
};

uniform float fSkyMultiplier;
uniform samplerCUBE SkyMap: register(s0); // Base texture

float4 main(in vfconn IN // From vertex shader
			) : COLOR
{
	// Base
	float4 decalColor = texCUBE(SkyMap, IN.fogCoord);
	decalColor.rgb = lerp(decalColor.rgb, decalColor.rgb*fSkyMultiplier, decalColor.a);	
	return float4(decalColor.xyz,IN.Color0.a);
}


