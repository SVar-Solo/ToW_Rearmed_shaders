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
    float4 HPOS : POSITION;
    float2 TEX0 : TEXCOORD0;
    float2 TEX1 : TEXCOORD1;
};


uniform float2		PixelSize;
// uniform float4x4	Proj;

// main procedure, the original name was main
VertexOUT main(in VertexIN IN)
{
	VertexOUT OUT;

	OUT.HPOS = IN.position;
	OUT.TEX0 = IN.texcoord.xy + 0.5f*PixelSize;
	OUT.TEX1 = PixelSize;
	return OUT;
} // main end
