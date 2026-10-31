// From vertex shader
struct VertexOUT
{
	float4 HPOS : POSITION;
#ifndef ZPASS
	float4 color : COLOR0;
	float2 texcoord : TEXCOORD0;
#ifdef FOG
	float4 fogCoord : TEXCOORD1;
#endif
#else
	float4 zcoord : TEXCOORD2;
#endif // ZPASS
};

uniform float fSkyMultiplier;

uniform sampler2D TexMap: register(s0); // Base texture
#ifdef FOG
	uniform samplerCUBE SkyMap: register(s1); // Fog texture
#endif


float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float4 result;
#ifndef ZPASS
	result = tex2D(TexMap, IN.texcoord.xy) * IN.color;
	//float4 result = float4(result2.b, result2.g, result2.r, result2.a);
#ifdef FOG
	float4 fogColor = texCUBE(SkyMap, IN.fogCoord.xyz);
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


