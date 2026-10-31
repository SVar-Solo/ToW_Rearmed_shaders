struct vfconn {
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;
};

uniform sampler2D TexMap : register(s0);

 // main procedure, the original name was main
float4 main(in vfconn IN) : COLOR0
{

    float4 decalColor;

    decalColor = tex2D(TexMap, IN.TEX0.xy);
    return decalColor*IN.COL0;
} // main end
