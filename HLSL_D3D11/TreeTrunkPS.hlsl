// D3D11 port of TreeTrunkPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	#ifndef ZPASS
	float4 color : COLOR0;
	float2 texcoord : TEXCOORD0;
	#ifdef FOG
	float4 fogCoord : TEXCOORD1;
	#endif
#else
	float4 zcoord : TEXCOORD2;
	#endif // ZPASS
	float4 HPOS : SV_Position;
};

cbuffer TreeTrunkPS_CB0 : register(b0)
{
float fSkyMultiplier;

};
Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture
#ifdef FOG
	TextureCube SkyMap : register(t1);
	SamplerState SkyMap_Sampler : register(s1); // Fog texture
#endif


float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	float4 result;
#ifndef ZPASS
	result = TexMap.Sample(TexMap_Sampler, IN.texcoord.xy) * IN.color;
	//float4 result = float4(result2.b, result2.g, result2.r, result2.a);
#ifdef FOG
	float4 fogColor = SkyMap.Sample(SkyMap_Sampler, IN.fogCoord.xyz);
	fogColor.rgb = lerp(fogColor.rgb, fogColor.rgb*fSkyMultiplier, fogColor.a);
	// compute final color
	result.rgb = lerp(result.rgb, fogColor.rgb, IN.fogCoord.w);
#endif
#else // ZPASS
	float rz = 0.5*(IN.zcoord.z/IN.zcoord.w)+(0.5).xxx;
	result = float4(rz,rz,rz,rz);
#endif
	  return result;
}


