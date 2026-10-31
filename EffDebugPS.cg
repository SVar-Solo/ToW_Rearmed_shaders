// From vertex shader
struct VertexOUT
{
	float4 color : TEXCOORD0;
};

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	return float4(IN.color.xyz, 1.0); // IN.color.a);
}


