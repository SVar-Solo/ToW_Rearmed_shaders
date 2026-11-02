// D3D11 port of HFLandVP.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Land.
//1.make texture coordinate generation for land, common noise and shadow map texture.

//Have 4 modifications:
// - normal shader for land (noise modulation + lighting + shadow) - define macros FULL and SHADOW
// - normal shader for land without shadows(noise modulation + lighting) - define macros FULL
// - shader for 3 lod (lighting)
// - shader for land reflection (lighting)  

//****************************************************

//#define FULL
//#define SHADOW  //internal to FULL
#define PSSM

struct VertexIn
{
    float4 position : POSITION;
};

struct VertexOut
{
    float2 tex0 : TEXCOORD0;    // Main texture
    float2 tex3 : TEXCOORD3;    // Координаты для прозрачности на границах ландшафта
    #ifdef FULL
    float2 tex1 : TEXCOORD1;    // Common Noise texture
    #ifdef SHADOW
	//Attention: we assume that will be used hardware shadow map support, so Tex(s/q, t/q) will be compared with r/q
    float4 tex2 : TEXCOORD2;    //shadow map texture - !!!NEW
    #endif  //SHADOW
#endif  //FULL
    float4 pos : SV_Position;
};

cbuffer HFLandVP_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
float4 S_TexGenVecMain;                 //tex gen vector for main land texture 
float4 T_TexGenVecMain;                 //tex gen vector for main land texture 
};
#ifdef FULL
	//uniform float4 S_TexGenVecNoise;                //tex gen vector for main land texture 
	//uniform float4 T_TexGenVecNoise;                 //tex gen vector for main land texture 
cbuffer HFLandVP_CB1 : register(b1)
{
	float commonNoiseTile;
};
#ifdef SHADOW
cbuffer HFLandVP_CB2 : register(b2)
{
	column_major float4x4 ShadowMapProjTexMatrix;         //shadow map texture - !!!NEW
};
#endif  //SHADOW
#endif //FULL

VertexOut main(VertexIn IN            )
{
    VertexOut OUT;
 
	//---transform vertex to camera space---
    OUT.pos = mul(ModelViewProj, IN.position);

	OUT.tex0 = float2( dot(IN.position, S_TexGenVecMain),  dot(IN.position, T_TexGenVecMain));
//????
//  OUT.tex0 = float2( frac(IN.position.x/256.0), frac(IN.position.y/256.0) );
//????

#ifdef FULL
	//OUT.tex1 = float2( dot(IN.position, S_TexGenVecNoise),  dot(IN.position, T_TexGenVecNoise));
	OUT.tex1 = OUT.tex0 * commonNoiseTile*2;
#ifdef SHADOW
	//shadows	
#ifdef PSSM
    OUT.tex2 = IN.position;
#else
	OUT.tex2 = mul(ShadowMapProjTexMatrix, IN.position);
#endif // PSSM
#endif  //SHADOW
#endif  //FULL

	float minCoord = -3072.0f; //границы ландшафта
	float maxCoord = 5120.0f; //границы ландшафта
	float normalizedX = (IN.position.x - minCoord) / (maxCoord - minCoord);
	float normalizedY = (IN.position.y - minCoord) / (maxCoord - minCoord);
    OUT.tex3 = float2(normalizedX, normalizedY);
	
    return OUT;
} 
