// D3D11 port of ShadowWaterVP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Shadow calculation for Water
//****************************************************

#define PSSM

struct appdata
{
    float4 position : POSITION;
};

struct vfconn
{
    //Attention: we assume that will be used hardware shadow map support, so Tex(s/q, t/q) will be compared with r/q
    float4 TEX0 : TEXCOORD0;    //shadow map texture - !!!NEW
    float4 HPOS : SV_Position;
};

cbuffer ShadowWaterVP_CB0 : register(b0)
{
column_major float4x4 ModelView;
column_major float4x4 ModelViewProj;
column_major float4x4 ShadowMapProjTexMatrix;

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

};
vfconn main(appdata IN)   //shadow map texture - !!!NEW
{
    vfconn OUT;

#ifdef PSSM
    OUT.TEX0 = IN.position; // world position
    OUT.TEX0.w = mul(ModelView, float4(IN.position.xyz, 1.0)).z; // camera space depth
#else
    OUT.TEX0 = mul(ShadowMapProjTexMatrix, IN.position);
#endif // PSSM

	//---transform vertex to camera space---
    OUT.HPOS = mul(ModelViewProj, IN.position);

/*
    float4 texcoord = mul(ShadowMapProjTexMatrix, IN.position);
    texcoord.xyz = texcoord.xyz/texcoord.w;
    texcoord.w = 1.0;
    OUT.TEX0 = texcoord;
*/
    return OUT;
} 
