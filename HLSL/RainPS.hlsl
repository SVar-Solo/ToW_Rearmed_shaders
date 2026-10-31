// From vertex shader
struct VertexOUT
{
	float4 color :COLOR0; //TEXCOORD0;
};

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	return float4(IN.color.xyz, IN.color.a);
}


