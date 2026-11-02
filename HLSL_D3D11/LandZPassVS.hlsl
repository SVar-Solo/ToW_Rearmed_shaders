// D3D11 port of LandZPassVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct vertexInputs
{
	float3 position     : POSITION;
	float3 normal		: NORMAL;
};

struct vfconn
{
    float4 zCoord : TEXCOORD0;
    float4 HPos : SV_Position;
};

cbuffer LandZPassVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
// vertex program
};
vfconn main(in vertexInputs IN
			)
{
	vfconn OUT;
	float4 objpos = float4(IN.position.xyz, 1);	
	float4 pos = mul(ModelViewProj, objpos);

	OUT.HPos = pos;
	OUT.zCoord = pos;

	//float2 NewTexCoord = mul(halTextureMatrix0, float4(IN.texcoords0,0,1)).xy;

	//OUT.Tex0 = NewTexCoord;
	

	return OUT;
}
