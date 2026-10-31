// From vertex shader
struct vfconn
{
	// Texcoord for base texture
	float2 TexCoord0 : TEXCOORD0;
        float4 zCoord : TEXCOORD1;
};

uniform sampler2D decal: register(s0);
uniform float2 fAlphatest;

float4 main(in vfconn IN // From vertex shader			
			) : COLOR
{
	// Base
	float4 decalColor = tex2D(decal, IN.TexCoord0.xy);
	//float rz = 0.5*((IN.zCoord.z)/IN.zCoord.w)+0.5;
	float rz = -0.001 * IN.zCoord.z;
	//decalColor.rgb = rz.xxx;
	if (fAlphatest.x > 0.5f)
	{
		if ( (decalColor.a - fAlphatest.y) <= 0 )
		{
			discard;
		}
	}
	//return decalColor;
	
	//float c = 40;
	//return float4(exp(c*rz), -exp(-c*rz), 0.0, 0.0);
		
	return float4(rz, 0.0, 0.0, 1.0);
}


