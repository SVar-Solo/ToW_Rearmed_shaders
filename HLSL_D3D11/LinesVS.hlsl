// D3D11 port of LinesVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float4 color : COLOR0;
};

struct VertexOUT
{
	float4 HPOS : SV_Position;
	float4 color : TEXCOORD0;
};

cbuffer LinesVS_CB0 : register(b0)
{
column_major float4x4 Proj;

};
VertexOUT main(VertexIN IN
			) 
{
	VertexOUT OUT;
	float3 pos = IN.position.xyz;
	OUT.HPOS = mul(Proj, float4(pos, 1.0));
	OUT.color = IN.color;	
	return OUT;
} 
