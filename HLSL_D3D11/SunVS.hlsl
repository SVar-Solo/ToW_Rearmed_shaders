// D3D11 port of SunVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT
{
	float2 TEX0 : TEXCOORD0;
	float4 color : TEXCOORD1;
	float4 HPOS : SV_Position;
};

cbuffer SunVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
float4 realPosition; // pos + size
float4 rescale;
float4 realColor;

};
VertexOUT main(in VertexIN IN
			) 
{
	VertexOUT OUT;
	OUT.HPOS = mul(ModelViewProj, float4(realPosition.xyz, 1.0));
	OUT.HPOS.xy *= realPosition.w;
	float len = clamp(length(OUT.HPOS.xy/OUT.HPOS.w), 0, 1);	
	float scale = lerp(rescale.z, rescale.w, len);
	OUT.HPOS.xy += IN.position.xy*rescale.xy*OUT.HPOS.w * scale;
	OUT.TEX0 = IN.texcoord;
	OUT.color = realColor;

	return OUT;
} 
