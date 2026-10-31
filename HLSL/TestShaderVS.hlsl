struct appdata {
    float4 position : POSITION;
    float4 Color0 : COLOR0;
    float4 Color1 : COLOR1;
    float2 Tex0 : TEXCOORD0;
};

struct vfconn {
    float4 HPOS : POSITION;
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float4x4 halTextureMatrix0;
//uniform float2 gRTSize;

 // main procedure, the original name was main
vfconn main(in appdata IN)
{
	vfconn OUT;

	OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz, 1.0));
	OUT.COL0 = IN.Color0;
	OUT.TEX0 = IN.Tex0;//+float2(0.5f/gRTSize.x, 0.5f/gRTSize.y);//mul( halTextureMatrix0, IN.Tex0);
	return OUT;
} // main end
