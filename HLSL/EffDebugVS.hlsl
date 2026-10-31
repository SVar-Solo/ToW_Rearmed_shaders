struct VertexIN
{
    float4 position : POSITION;
    float4 color : COLOR0;
};

struct VertexOUT
{
	float4 HPOS : POSITION;
	float4 color : TEXCOORD0;
};

uniform float4x4 ModelViewProj : _GL_MVP;

VertexOUT main(VertexIN IN
			) 
{
	VertexOUT OUT;
	float3 pos = IN.position.xyz;
	OUT.HPOS = mul(ModelViewProj, float4(pos, 1.0));
	OUT.color = IN.color;	
	return OUT;
} 
