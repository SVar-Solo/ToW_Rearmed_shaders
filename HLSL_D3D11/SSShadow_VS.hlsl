// D3D11 port of SSShadow_VS.hlsl. Generated from the legacy HLSL source; see README.md.
//-----------------------------------------------------------------------------
//	FILE: SSShadow_PS.hlsl
//	INFO: Screen space shadows pass
//-----------------------------------------------------------------------------

// input
struct VertexIN 
{
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

// output
struct VertexOUT 
{
    float4 HPOS : SV_Position;
    float2 TEX0 : TEXCOORD0;
    float2 TEX1 : TEXCOORD1;
};


cbuffer SSShadow_VS_CB0 : register(b0)
{
float2 PixelSize;
// uniform float4x4	Proj;

// main procedure, the original name was main
};
VertexOUT main(in VertexIN IN)
{
	VertexOUT OUT;

	OUT.HPOS = IN.position;
	OUT.TEX0 = IN.texcoord.xy +  0.5f*PixelSize;
	OUT.TEX1 = PixelSize;
	return OUT;
} // main end
