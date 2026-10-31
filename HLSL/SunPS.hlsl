// From vertex shader
struct VertexOUT
{
	float2 TEX0 : TEXCOORD0;
	float4 color : TEXCOORD1;
};

uniform sampler2D DiffuseMap: register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float4 decalColor = tex2D(DiffuseMap, IN.TEX0) * IN.color;
	return float4(decalColor.rgb*decalColor.a, decalColor.a);
}


