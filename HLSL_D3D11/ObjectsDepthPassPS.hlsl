// D3D11 port of ObjectsDepthPassPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct vfconn
{
	// Texcoord for base texture
	float2 TexCoord0 : TEXCOORD0;
        float4 zCoord : TEXCOORD1;
};

Texture2D decal : register(t0);
SamplerState decal_Sampler : register(s0);
cbuffer ObjectsDepthPassPS_CB0 : register(b0)
{
float2 fAlphatest;

};
float4 main(in vfconn IN) : SV_Target0
{
	// Base
	float4 decalColor = decal.Sample(decal_Sampler, IN.TexCoord0.xy);
	//float rz = 0.5*((IN.zCoord.z)/IN.zCoord.w)+0.5;
	float rz = -IN.zCoord.z;
	decalColor.rgb = rz.xxx;
	//if ( (1.f-fAlphatest.x+decalColor.a - fAlphatest.y) <= 0.001f )
	//if ( (decalColor.a - fAlphatest.y) <= 0 )
	//if ( (1.f-fAlphatest.x) <= 0 )

	if (fAlphatest.x > 0.5f)
	{
		if ( (decalColor.a - fAlphatest.y) <= 0.001)
		//if (decalColor.a <= fAlphatest.y/255.0f)
		{
			discard;
		}
	}

	return decalColor;
}


