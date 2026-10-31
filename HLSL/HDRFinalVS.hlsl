struct VertexIN {
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT 
{
    float4	HPOS			: POSITION;
    float2	TEX0			: TEXCOORD0;
    float2	TEX1			: TEXCOORD1;
	float4	FogTexCoords	: TEXCOORD2;
};

uniform float2 pixelSize;

 // main procedure, the original name was main
VertexOUT main(in VertexIN IN)
{

    VertexOUT OUT;

    OUT.HPOS = IN.position;
    OUT.TEX0 = IN.texcoord.xy +  0.5f*pixelSize;
    OUT.TEX1 = IN.texcoord.xy + ( 0.5f*pixelSize)/8.f;
    return OUT;
} // main end
