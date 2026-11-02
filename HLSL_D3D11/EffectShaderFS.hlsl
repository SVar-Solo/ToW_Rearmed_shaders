// D3D11 port of EffectShaderFS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct vfconn
{
	float4 COL0 : COLOR0;
	float4 TEX0 : TEXCOORD0;
};

Texture2D TexMap : register(t0);
SamplerState TexMap_Sampler : register(s0); // Base texture

float4 main(in vfconn IN // From vertex shader
			) : SV_Target0
{
	float4 decalColor = TexMap.Sample(TexMap_Sampler, IN.TEX0.xy);	
	return decalColor* IN.COL0;

	//float4 decalColor = float4(1,1,1,1);
	//return decalColor;
}


