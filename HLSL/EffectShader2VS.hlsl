
struct vertex_in
{
    float4 Position		: POSITION;
    float4 Color0		: COLOR0;
    float4 Tex0			: TEXCOORD0;
};

struct vertex_out
{
    float4 HPOS			: POSITION;
    float4 TEX0			: TEXCOORD0;
    float4 COL0			: TEXCOORD1;
    float4 ScreenPos	: TEXCOORD2; // screen coords
    float  CameraDepth  : TEXCOORD3; 
};

uniform float4x4 ModelViewProj : _GL_MVP;
uniform float4x4 ModelView : _GL_MV;
uniform float4x4 halTextureMatrix0;
uniform float    SunColorScale;

vertex_out main(in vertex_in IN) 
{
    vertex_out OUT;

	OUT.HPOS = mul(ModelViewProj, float4(IN.Position.xyz, 1.0));
	OUT.COL0 = IN.Color0;
	OUT.COL0.rgb *= SunColorScale;
	OUT.TEX0 = IN.Tex0; // mul( halTextureMatrix0, IN.Tex0);  // mul( halTextureMatrix0, IN.Tex0);
	OUT.ScreenPos = OUT.HPOS;
	OUT.CameraDepth = -mul(ModelView, float4(IN.Position.xyz, 1.0)).z;
	
    return OUT;
} 
