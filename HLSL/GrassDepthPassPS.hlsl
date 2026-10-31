//-----------------------------------------------------------------------------
//	Grass depth pass shader
//-----------------------------------------------------------------------------

struct VertexOut
{
	float2 TEX0 : TEXCOORD0;    
    float4 zCoord : TEXCOORD1;
};

uniform sampler2D VGrassTex : register(s0);


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) :	COLOR
{	
	float4 decalColor = tex2D(VGrassTex, IN.TEX0.xy);
	
	float rz = -IN.zCoord.z;
	decalColor.rgb = rz.xxx;
	
	if ((decalColor.a - 0.5) <= 0.001)	
	{
		discard;
	}
	
	return decalColor;
}

