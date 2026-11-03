// D3D11 port of WaterVP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Water pass1
//****************************************************

struct VertexIn
{
    float4 position : POSITION;
};

struct VertexOut
{
    float2 tex0 : TEXCOORD0;    //Noise bump texture
    float2 tex1 : TEXCOORD1;    //Noise bump texture
    float3 tex2 : TEXCOORD2;    //normalization cube map texture
    float3 tex3 : TEXCOORD3;    //normalization cube map texture (legacy duplicate TEXCOORD2 fixed for D3D11)
    float4 pos : SV_Position;
};


cbuffer WaterVP_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
float4 S_TexGenVec0;
float4 T_TexGenVec0;
float4 CamPosition;

};
VertexOut main(in VertexIn IN )                
{
    VertexOut OUT;

	// transform vertex to camera space
    float4 opos = float4(IN.position.xyz,1);
    OUT.pos = mul(ModelViewProj, opos);

	float2 texc = float2( dot(opos, S_TexGenVec0),  dot(opos, T_TexGenVec0));
	OUT.tex0.xy = texc;
	OUT.tex1.xy = texc*3; //3.33;

	OUT.tex2.xyz = (IN.position.xyz - CamPosition.xyz );
	OUT.tex3 = float3(0, 0, 0); // unused legacy output; keep deterministic

    return OUT;
} 
