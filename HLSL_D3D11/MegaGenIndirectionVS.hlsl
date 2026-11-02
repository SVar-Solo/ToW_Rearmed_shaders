// D3D11 port of MegaGenIndirectionVS.hlsl. Generated from the legacy HLSL source; see README.md.
struct VertexIN
{
    float4 position : POSITION;
    float2 coord : TEXCOORD0;
};         

struct VertexOUT
{
	float4 HPOS : SV_Position;
	float4 screenpos : TEXCOORD0;
	float4 coord : TEXCOORD1;
};

cbuffer MegaGenIndirectionVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
//uniform float4x4 World2CameraMtx;
//uniform float3 cameraPosition;
float4 texGenData;

};
VertexOUT main(VertexIN IN
			) 
{
	VertexOUT OUT;
	//float2 texcoord = float2(1,1)-(IN.position.xy/2048);
	float2 texcoord = float2(texGenData.x + texGenData.y *IN.position.x, texGenData.z + texGenData.w *IN.position.y);
	//texcoord.y = 1-texcoord.y;
	float z = 0;//dot( float3(0,0,1), normalize(cameraPosition.xyz-IN.position.xyz) ) - 1;
	float3 pos = float3(texcoord.x*2-1, (texcoord.y*2-1), z);
	OUT.HPOS = float4(pos, 1.0);
	float4 wpos = float4(IN.position.x,IN.position.y,IN.position.z,1);
	OUT.screenpos = mul(ModelViewProj, wpos);
	//OUT.HPOS = OUT.screenpos;
	OUT.coord = float4(texcoord.xy, 0, 0);
	return OUT;
}
