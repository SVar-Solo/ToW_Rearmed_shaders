struct appdata
{
    float4 position : POSITION;
	float4 Color0 : COLOR0;
	float4 Color1 : COLOR1;
	float4 Tex0 : TEXCOORD0;
};

struct vfconn
{
    float4 HPOS : POSITION;
    float4 COL0 : COLOR0;
    float4 TEX0 : TEXCOORD0;
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float4x4 halTextureMatrix0;

vfconn main(in appdata IN
			)
{
    vfconn OUT;

	OUT.HPOS = mul(ModelViewProj, float4(IN.position.xyz, 1.0));

	OUT.COL0 = IN.Color0;//;float4(1.0, 0.0, 1.0, 1.0);
	OUT.TEX0 = mul( halTextureMatrix0, IN.Tex0);
    return OUT;
} 
