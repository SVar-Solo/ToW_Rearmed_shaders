// D3D11 port of GrassDepthPassVS.hlsl. Generated from the legacy HLSL source; see README.md.
//-----------------------------------------------------------------------------
//	Grass depth pass shader
//-----------------------------------------------------------------------------


struct VertexIN
{
    float4 position		: POSITION;
    float2 TEX0			: TEXCOORD0;
    float4 slope		: TEXCOORD1;
    float4 coordw		: TEXCOORD2;
    float4 gencoord		: TEXCOORD3;
};

struct VertexOut
{
    float2 TEX0 : TEXCOORD0;
    float4 zCoord : TEXCOORD1;
    float4 HPOS : SV_Position;
};

cbuffer GrassDepthPassVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 ModelView;

};
VertexOut 
main(in VertexIN IN)                
{
    VertexOut OUT;
    float4x4 SlopeMatrix;

    SlopeMatrix[0] = float4(1,          0,          IN.slope.z, IN.coordw.x);
    SlopeMatrix[1] = float4(0,          1,          IN.slope.w, IN.coordw.y);
    SlopeMatrix[2] = float4(IN.slope.x, IN.slope.y, 1,          IN.coordw.z);
    SlopeMatrix[3] = float4(0,          0,          0,          1);


    float4 new_position = mul(SlopeMatrix, IN.position);

    OUT.HPOS	= mul(ModelViewProj, new_position);
    OUT.TEX0	= IN.TEX0 + float2(0.0, IN.coordw.w);
	OUT.zCoord	= mul(ModelView, float4(new_position.xyz, 1));; 

    return OUT;
} 
