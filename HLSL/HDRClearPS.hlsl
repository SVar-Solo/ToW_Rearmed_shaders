struct VertexOUT {
    float2 TEX0 : TEXCOORD0;
};

uniform float4 color;

 // main procedure, the original name was main
float4 main() : COLOR0
{
    return color;
} // main end
