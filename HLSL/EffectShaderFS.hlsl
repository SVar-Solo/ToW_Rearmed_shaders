// From vertex shader
struct vfconn
{
	float4 COL0 : COLOR0;
	float4 TEX0 : TEXCOORD0;
};

uniform sampler2D TexMap: register(s0); // Base texture

float4 main(in vfconn IN // From vertex shader
			) : COLOR
{
	float4 decalColor = tex2D(TexMap, IN.TEX0.xy);	
	return decalColor* IN.COL0;

	//float4 decalColor = float4(1,1,1,1);
	//return decalColor;
}


