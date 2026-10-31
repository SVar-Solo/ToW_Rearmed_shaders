// From vertex shader
struct VertexOUT
{
	float2 TEX0 : TEXCOORD0;
	float4 color: COLOR0;
};

uniform sampler2D DiffuseMap: register(s0); // Base texture

float4 main(in VertexOUT IN) : COLOR
{
	float4 decalColor = tex2D(DiffuseMap, IN.TEX0) * IN.color;
	return decalColor;//*float4(0.47f, 0, 0, 0.2f);
	//return IN.color;
	//return float4(decalColor.rgb*decalColor.a, decalColor.a);
	//return float4(IN.TEX0.xy, 0, 1);
}


