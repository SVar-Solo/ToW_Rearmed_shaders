// From vertex shader
struct VertexOUT
{
	float3 TEX0 : TEXCOORD0;
};

static const float3 LUMINANCE_WEIGHT = float3( 0.299f, 0.587f, 0.114f );
uniform samplerCUBE SkyMap: register(s0); // Base texture
uniform float fSkyMultiplier;

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float3 texcoord = normalize(IN.TEX0.xyz);
	float4 decalColor = texCUBE(SkyMap, texcoord);
	//float lum = dot(decalColor, LUMINANCE_WEIGHT);
	//decalColor.rgb *= 1+lum;
	//return float4(1,0,0,1);//decalColor;
	//decalColor.rgb = decalColor.rgb * lerp(1.0, fSkyMultiplier, decalColor.a);
	//decalColor.rgb = decalColor.aaa;
	return float4(decalColor.rgb * fSkyMultiplier, 1.0);
}


