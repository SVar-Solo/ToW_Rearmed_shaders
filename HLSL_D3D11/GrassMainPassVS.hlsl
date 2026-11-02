// D3D11 port of GrassMainPassVS.hlsl. Generated from the legacy HLSL source; see README.md.
//****************************************************
//Vertex shader for Light+Shadow calculation for Grass.
//Define FULL - for full shader with shadow map
//****************************************************

struct VertexIN
{
    float4 position	: POSITION;
    float2 TEX0		: TEXCOORD0;
    float4 slope	: TEXCOORD1;
    float4 coordw	: TEXCOORD2;
    float4 gencoord	: TEXCOORD3;
};

struct VertexOut
{
    float4 COL0		 : COLOR0;
    float4 COL1		 : COLOR1;
    float2 TEX0		 : TEXCOORD0;
    float2 TEX1		 : TEXCOORD1;
    float4 ScreenPos : TEXCOORD2;
    float4 coordw	 : TEXCOORD3;
    float4 HPOS		 : SV_Position;
};

// redirection of uniform parameters to OpenGLStates
cbuffer GrassMainPassVS_CB0 : register(b0)
{
column_major float4x4 ModelViewProj;
//uniform float4x4 SlopeMatrix;
//uniform float4 S_TexGenVec;  //tex gen vector for main land texture
//uniform float4 T_TexGenVec;  //tex gen vector for main land texture
//uniform float4 Color0;
//uniform float4 Color1;
//uniform float4 TexCoordShift;  //to select texture type - really used only 1 float

//-----------------------------------------------------------------------------
//	main
//-----------------------------------------------------------------------------

};
VertexOut main(in VertexIN IN)                
{
    VertexOut OUT;
    float4x4 SlopeMatrix;
//    SlopeMatrix[0] = float4(1,           0,           IN.slope.x,  0);
//    SlopeMatrix[1] = float4(0,           1,           IN.slope.y,  0);
//    SlopeMatrix[2] = float4(IN.slope.z,  IN.slope.w,  1,           0);
//    SlopeMatrix[3] = float4(IN.coordw.x, IN.coordw.y, IN.coordw.z, 1);

    SlopeMatrix[0] = float4(1,          0,          IN.slope.z, IN.coordw.x);
    SlopeMatrix[1] = float4(0,          1,          IN.slope.w, IN.coordw.y);
    SlopeMatrix[2] = float4(IN.slope.x, IN.slope.y, 1,          IN.coordw.z);
    SlopeMatrix[3] = float4(0,          0,          0,          1);


    float4 S_TexGenVec = float4(IN.gencoord.x, 0.0, 0.0, IN.coordw.x*IN.gencoord.x + 0.5 - IN.gencoord.y * IN.gencoord.x);  //tex gen vector for main land texture
    float4 T_TexGenVec = float4(0.0,  IN.gencoord.x, 0.0, IN.coordw.y*IN.gencoord.x + 0.5 - IN.gencoord.z * IN.gencoord.x);  //tex gen vector for main land texture

	// transform vertex to camera space
    // Attention: here 2 matrix-vector multiplication

    float4 new_position = mul(SlopeMatrix, IN.position);
    OUT.HPOS = mul(ModelViewProj, new_position);

    OUT.TEX0 = IN.TEX0 + float2(0.0, IN.coordw.w);

	float s = dot(S_TexGenVec, IN.position);  
	float t = dot(T_TexGenVec, IN.position);
    OUT.TEX1 = float2(s, t);

    //float occ=clamp(IN.position.z*IN.position.z, 0.5, 1);
    OUT.COL0 = float4(1,1,1,1);//float4(occ,occ,occ,1);//Color0;   
    OUT.COL1 = float4(1,1,1,1);//Color1;
	//------------------------------------------
	
	// screen coord
    OUT.ScreenPos = OUT.HPOS;
	OUT.coordw = IN.coordw;
    OUT.COL0 = saturate(OUT.COL0); // D3D9 COLOR interpolator clamp
    OUT.COL1 = saturate(OUT.COL1); // D3D9 COLOR interpolator clamp
    return OUT;
} 
