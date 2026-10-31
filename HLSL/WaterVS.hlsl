//****************************************************
//Vertex shader for Water pass1
//****************************************************

struct VertexIn
{
    float4 position : POSITION;
};

struct VertexOut
{
    float4 pos			: POSITION;
    float4 NoiseUV		: TEXCOORD0;    // Noise bump texture
	float4 EyeDir_Depth : TEXCOORD1;    // eye dir plus screen depth
	float4 DSDT_Refl	: TEXCOORD2;    // dsdt uv plus reflective uv
	float4 WorldPos		: TEXCOORD3;	// world position
	float4 ScreenPos	: TEXCOORD4;    // reflection texture uv
	float2 absPos	 	: TEXCOORD5;    // Координаты для прозрачности на границах ландшафта
};


uniform float4x4	ModelViewProj : _GL_MVP;
uniform float4x4	ModelView : _GL_MV;
uniform float4		S_TexGenVec0;
uniform float4		T_TexGenVec0;
uniform float4		CamPosition;

uniform float4x4	ReflectMatrix;
uniform float		TextureScale;
uniform float4x4	TexMtx;


VertexOut main(in VertexIn IN)                
{
    VertexOut OUT;

	//---transform vertex to camera space---
    float4 opos = float4(IN.position.xyz,1);
    OUT.pos = mul(ModelViewProj, opos);

	float2 texc = float2( dot(opos, S_TexGenVec0),  dot(opos, T_TexGenVec0));
	OUT.NoiseUV.xy = texc;
	OUT.NoiseUV.zw = texc*3;
	
	// dsdt uv
	OUT.EyeDir_Depth.xyz = (IN.position.xyz - CamPosition.xyz );

	//calc dsdt texture coord
	OUT.DSDT_Refl.xy = mul(TexMtx, TextureScale * IN.position).xy;

	//so, manually calc 2D tex coord for projective mapping, since in pixel shader 
    float4 reflected_uv = mul(ReflectMatrix, IN.position);
	reflected_uv = reflected_uv/reflected_uv.w;
	OUT.DSDT_Refl.zw = reflected_uv.xy;

	OUT.WorldPos = IN.position/IN.position.w;

	OUT.ScreenPos = OUT.pos;
	OUT.EyeDir_Depth.w = -mul(ModelView, float4(IN.position.xyz, 1.0)).z;

	float minCoord = -3072.0f; //границы ландшафта
	float maxCoord = 5120.0f; //границы ландшафта
	float normalizedX = (IN.position.x - minCoord) / (maxCoord - minCoord);
	float normalizedY = (IN.position.y - minCoord) / (maxCoord - minCoord);
    OUT.absPos = float2(normalizedX, normalizedY);

    return OUT;
} 
