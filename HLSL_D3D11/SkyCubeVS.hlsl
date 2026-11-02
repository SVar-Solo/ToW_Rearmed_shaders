// D3D11 port of SkyCubeVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
};

struct VertexOUT
{
	float3 TEX0 : TEXCOORD0;
	float4 HPOS : SV_Position;
};

cbuffer SkyCubeVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
float3 cameraPosition;
float4 CosSin;

};
VertexOUT main(in VertexIN IN) 
{
	VertexOUT OUT;
	OUT.HPOS = mul(ModelViewProj, float4(cameraPosition+IN.position.xyz, 1.0));
	float3 pos = float3(IN.position.x, IN.position.y, IN.position.z);
	OUT.TEX0 = float3(pos.x*CosSin.x+pos.y*CosSin.y, pos.x*CosSin.z+pos.y*CosSin.w, pos.z);

	return OUT;
} 
