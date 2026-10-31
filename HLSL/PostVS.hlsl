
struct VertexIN 
{
    float4 position : POSITION;
    float3 texcoord : TEXCOORD0;
};

struct VertexOUT 
{
    float4 HPOS : POSITION;
    float2 TexCoord[8] : TEXCOORD0;
    //float2 TEX1 : TEXCOORD1;
};

uniform float2 PixelSize;

VertexOUT main(in VertexIN IN)
{
    VertexOUT OUT;
    OUT.HPOS = IN.position;
    int taps = 7;
    
    if (true)
    {    
		OUT.TexCoord[0] = IN.texcoord.xy +  0.5f / PixelSize;
		OUT.TexCoord[1] = IN.texcoord.xy + ( 0.5f * PixelSize)/8.f;		
	}
	else
	{
		float2 uv_step = float2(0.0f, 0.0f);
		uv_step.x = PixelSize.x > 0 ? 1.0f/PixelSize.x : 0.0f;
		uv_step.y = PixelSize.y > 0 ? 1.0f/PixelSize.y : 0.0f;
		
		float2 base = IN.texcoord - ((((float)taps - 1)*0.5f) * uv_step);
	      
		for (int i = 0; i < taps; i++)
		{
			OUT.TexCoord[i] = base;
			base += uv_step;
		}
	}
	return OUT;
}
