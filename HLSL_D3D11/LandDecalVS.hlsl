// D3D11 port of LandDecalVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
    float4 color: COLOR0;
};

struct VertexOUT
{
	float4 HPOS : SV_Position;
	float2 TEX0 : TEXCOORD0;
	float4 color: COLOR0;
};

cbuffer LandDecalVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;

};
VertexOUT main(in VertexIN IN) 
{
	VertexOUT OUT;
	OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz, 1.0));
	OUT.TEX0 = IN.texcoord;
	OUT.color = IN.color;
    OUT.color = saturate(OUT.color); // D3D9 COLOR interpolator clamp
	return OUT;
} 
