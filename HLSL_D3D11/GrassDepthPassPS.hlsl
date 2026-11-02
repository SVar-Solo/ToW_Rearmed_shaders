// D3D11 port of GrassDepthPassPS.hlsl. Generated from the legacy HLSL source; see README.md.
//-----------------------------------------------------------------------------
//	Grass depth pass shader
//-----------------------------------------------------------------------------

struct VertexOut
{
	float2 TEX0 : TEXCOORD0;    
    float4 zCoord : TEXCOORD1;
};

Texture2D VGrassTex : register(t0);
SamplerState VGrassTex_Sampler : register(s0);


//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

float4 main(VertexOut IN) :	SV_Target0
{	
	float4 decalColor = VGrassTex.Sample(VGrassTex_Sampler, IN.TEX0.xy);
	
	float rz = -IN.zCoord.z;
	decalColor.rgb = rz.xxx;
	
	if ((decalColor.a - 0.5) <= 0.001)	
	{
		discard;
	}
	
	return decalColor;
}

