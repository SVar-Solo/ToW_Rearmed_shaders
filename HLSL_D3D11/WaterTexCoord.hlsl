// D3D11 port of WaterTexCoord.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for water pass2 - radial grid.
//1.Map reflection texture and dsdt perturbation on radial grid.
//2.Modulate reflection with Fresnel reflection coeff. calculated for radial grid on CPU.
//See function prototype - void TLandscapeWater::CPU_FillTextureCoord(wtVerts& v, float fTextureScale, float* Mtx)
//****************************************************

struct VertexIn
{
    float4 position : POSITION;
    float4 COL0 : COLOR0;  //??????
};

struct VertexOut
{
    float4 COL0 : COLOR0;
    float2 TEX0 : TEXCOORD0;  //dsdt texture coord.
    float2 TEX1 : TEXCOORD1;  //reflection texture coord.
    float4 HPOS : SV_Position;
};


cbuffer WaterTexCoord_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
column_major float4x4 CustomProjMatrix;
float TextureScale;
column_major float4x4 TexMtx;

};
VertexOut main(VertexIn IN)
{
    VertexOut OUT;

	//---transform vertex to camera space---
    OUT.HPOS = mul(ModelViewProj, IN.position);
    OUT.COL0 = IN.COL0;

	//calc dsdt texture coord
	float4 Coord0 = TextureScale*IN.position;
	OUT.TEX0 = mul(TexMtx, Coord0).xy;

	//
	//so, manually calc 2D tex coord for projective mapping, since in pixel shader 
    float4 Coord1 = mul(CustomProjMatrix, IN.position);
	Coord1 = Coord1/Coord1.w;
	OUT.TEX1 = Coord1.xy;

    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    return OUT;
} 
