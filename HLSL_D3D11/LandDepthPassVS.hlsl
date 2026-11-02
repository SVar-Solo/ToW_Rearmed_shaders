// D3D11 port of LandDepthPassVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct vertexInputs
{
	float3 position     : POSITION;
	float3 normal		: NORMAL;
};

struct vfconn
{
    float4 HPos : SV_Position;
    float4 zCoord : TEXCOORD0;
};

cbuffer LandDepthPassVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 ModelView;
// vertex program
};
vfconn main(in vertexInputs IN
			)
{
	vfconn OUT;
	float4 objpos = float4(IN.position.xyz, 1);	
	float4 pos = mul(ModelViewProj, objpos);

	OUT.HPos = pos;
	OUT.zCoord = mul(ModelView, objpos);
	float2 texcoord = (IN.position.xy/2048.f);
	OUT.zCoord.xy = float2(texcoord.x, texcoord.y);
	return OUT;
}
