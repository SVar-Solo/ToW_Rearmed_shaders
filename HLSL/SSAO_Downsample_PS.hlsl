// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
	float2 pixelsize : TEXCOORD1;
};

uniform sampler2D sceneDepthBuffer: register(s0); // Base texture

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	float2 tc0 = IN.texCoord.xy;
	float2 offset = IN.pixelsize;
   float sum = tex2D(sceneDepthBuffer, tc0).r/5.f;
   sum += tex2D(sceneDepthBuffer, tc0 + offset).r/5.f;
   sum += tex2D(sceneDepthBuffer, tc0 + float2(offset.x, -offset.y)).r/5.f;
   sum += tex2D(sceneDepthBuffer, tc0 + float2(-offset.x, offset.y)).r/5.f;
   sum += tex2D(sceneDepthBuffer, tc0 - offset).r/5.f;
   
   return sum;
   //return IN.texCoord.x;
}