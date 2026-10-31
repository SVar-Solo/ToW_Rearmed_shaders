// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
	float2 pixelsize : TEXCOORD1;
};

uniform sampler2D BlurSrcSampler: register(s0); // Base texture
uniform sampler2D zMap: register(s1); // Base texture

float4 getBluredPixel(in VertexOUT IN)
{
  float fFarClipPlane = 16000;
  float2 BlurOffset = IN.pixelsize;
  float2 centerTC = IN.texCoord.xy + BlurOffset.xy;

  // low weight center sample - will be used on edges
   float fSumWeight = 0.0125f;
   float4 cColor = tex2D(BlurSrcSampler, centerTC) * fSumWeight;

   float centerDepth = tex2D(zMap, centerTC).r / fFarClipPlane;

   float2 arrOffsets[4] =
   {
     float2( 1,-1),
     float2(-1,-1),
     float2( 1, 1),
     float2(-1, 1)
   };

  for(int i=0; i<4; i++)
  {
     float2 sampleTC = centerTC + BlurOffset.xy * arrOffsets[i];

     float fDepth = tex2D(zMap, sampleTC).r / fFarClipPlane;

     float fDiff = 8.f*(1.f - fDepth/centerDepth);

     float fWeight = saturate(0.5f - 0.75f*abs(fDiff) - 0.25f*(fDiff));

    cColor += tex2D(BlurSrcSampler, sampleTC) * fWeight;

     fSumWeight += fWeight;
  }

   cColor /= fSumWeight;   

   return cColor;
   
}

float4 getBluredPixel2(in VertexOUT IN)
{
  float fFarClipPlane = 16000;
  float2 BlurOffset = IN.pixelsize;
  float2 centerTC = IN.texCoord.xy + BlurOffset.xy;

   float2 arrOffsets[4] =
   {
     float2( 1,-1),
     float2(-1,-1),
     float2( 1, 1),
     float2(-1, 1)
   };

    float fSumWeight = 0.f;

    float4 cColor = float4(0,0,0,1);
	//for(int x=-1;x<2;x++)
	//for(int y=-1;y<2;y++)
	for(int i=0; i<4; i++)
	{
		//float2 sampleTC = centerTC + BlurOffset.xy * float2(x,y);
		float2 sampleTC = centerTC + BlurOffset.xy * arrOffsets[i];
		cColor += tex2D(BlurSrcSampler, sampleTC);
		fSumWeight++;
	}

   return cColor/fSumWeight;
   
}

float4 getPixel(in VertexOUT IN)
{
  float2 BlurOffset = IN.pixelsize;
  float2 centerTC = IN.texCoord.xy + BlurOffset.xy;
  float4 cColor = tex2D(BlurSrcSampler, centerTC);
  return cColor;
}

float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	//return getPixel(IN);
	return getBluredPixel(IN);
	//return getBluredPixel2(IN);
}