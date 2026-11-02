// D3D11 port of RainVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float4 color : COLOR0;
};

struct VertexOUT
{
	float4 color : COLOR0; //TEXCOORD0;
	float4 HPOS : SV_Position;
};

cbuffer RainVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;

};
VertexOUT main(VertexIN IN
			) 
{
	VertexOUT OUT;
	float3 pos = IN.position.xyz;
	OUT.HPOS = mul(ModelViewProj, float4(pos, 1.0));
	OUT.color = IN.color;	
    OUT.color = saturate(OUT.color); // D3D9 COLOR interpolator clamp
	return OUT;
} 
