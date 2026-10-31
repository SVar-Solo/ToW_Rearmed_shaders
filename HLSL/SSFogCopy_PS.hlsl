
struct VertexOUT 
{
    float2 texCoord : TEXCOORD0;
};

uniform sampler2D TexMap: register(s0);
uniform float		fSkyMultiplier;

float4 main(in VertexOUT IN) : COLOR
{
	float4 fog_color = tex2D(TexMap, IN.texCoord);
	if (fog_color.a <= 0.0001) discard;
    return float4(fog_color.rgb*fSkyMultiplier, fog_color.a);
} 
