// D3D11 port of EffDebugPS.hlsl. Generated from the legacy HLSL source; see README.md.
// From vertex shader
struct VertexOUT
{
	float4 color : TEXCOORD0;
};

float4 main(in VertexOUT IN // From vertex shader
			) : SV_Target0
{
	return float4(IN.color.xyz, 1.0); // IN.color.a);
}


