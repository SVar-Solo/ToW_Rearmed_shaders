struct VertexIN {
    float4 position : POSITION;
    float2 texcoord : TEXCOORD0;
};

struct VertexOUT {
    float4 HPOS : POSITION;
    float2 TEX0 : TEXCOORD0;
};

uniform float2 pixelSize;
uniform float4x4 Proj;

 // main procedure, the original name was main
VertexOUT main(in VertexIN IN)
{
    VertexOUT OUT;

    OUT.HPOS = IN.position;
    OUT.TEX0 = IN.texcoord.xy;// + 0.5f*pixelSize;
    //OUT.TEX0 = 0.5*(IN.position)+0.5;// +  0.5f*float2(4.f/1280.f, 4.f/800.f);
    return OUT;
} // main end
