// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

#define MAX_SAMPLES 15

uniform float2 avSampleOffsets[MAX_SAMPLES];
uniform float4 avSampleWeights[MAX_SAMPLES];
uniform sampler2D TexMap: register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float4 sample = avSampleWeights[0] * tex2D(TexMap, IN.texCoord + avSampleOffsets[0]);
	for( int i=1; i < MAX_SAMPLES; i++ )
	{
		sample += avSampleWeights[i] * tex2D(TexMap, IN.texCoord + avSampleOffsets[i]);
	}
	return float4(sample.rgb,1.0);
}