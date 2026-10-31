// From vertex shader
struct VertexOUT
{
	float2 texCoord : TEXCOORD0;
};

uniform sampler2D DepthMap: register(s0); // Base texture
uniform sampler2D RandSample: register(s1); // Base texture

uniform float4 g_vScreenData; // w, h, w/4, h/4

float3 mirror( float3 vDir, float3 vPlane ) 
{
  return vDir - 2 * vPlane * dot(vPlane,vDir);
}

float4 computeSSAO_Crysis(float2 UV)
{
	float2 psize = float2(1.f/g_vScreenData.x, 1.f/g_vScreenData.y);
	float4 ScreenTC = float4(UV /** (float2(1,1)+2*psize.xy)*/ + 0.5f * float2(psize.x,psize.y), UV * float2(g_vScreenData.z, g_vScreenData.w) * (float2(1,1)+1*psize.xy) + 0.5f * psize);
	//float4 ScreenTC = float4(UV, UV * float2(1280/2, 800/2));
	float4 PS_NearFarClipDist = float4(1.f, 16000.f, 1.f, 1.f);
	//float4 SSAO_params = float4(1.0f,0.075f,5,5);
	float4 SSAO_params = float4(1.0f, 0.0f, 1.0f , 1.0f);
	float4 Color;
  
	// define kernel
	const float step = 1.f/16.f;//1.f - 1.f/2.f;
	float n = 0.0f;//1.0f-8*step;
	const float fScale = 1.0f;//0.025f; 
	//const float step = 1.f/2.f;//1.f - 1.f/2.f;
	//float n = 1.0f-16*step;
	//const float fScale = 0.2f;//0.025f; 
/*
	float3 arrKernel[8] =
	{
		normalize(float3( 1, 1, 1))*fScale*(n+=step),
		normalize(float3(-1,-1,-1))*fScale*(n+=step),
		normalize(float3(-1,-1, 1))*fScale*(n+=step),
		normalize(float3(-1, 1,-1))*fScale*(n+=step),
		normalize(float3(-1, 1 ,1))*fScale*(n+=step),
		normalize(float3( 1,-1,-1))*fScale*(n+=step),
		normalize(float3( 1,-1, 1))*fScale*(n+=step),
		normalize(float3( 1, 1,-1))*fScale*(n+=step),
	};
*/
        float4 arrKernel[16] =
        {
                float4(0.355512,   -0.709318, 	-0.102371,  0.0 )*fScale*(n+=step),
                float4(-0.207641,   0.414286, 	 0.187755,  0.0 )*fScale*(n+=step),
                float4(0.534186,    0.71511, 	-0.115167,  0.0 )*fScale*(n+=step),
                float4(-0.277332,  -0.371262, 	 0.187755,  0.0 )*fScale*(n+=step),
                float4(-0.87866,    0.157139, 	-0.115167,  0.0 )*fScale*(n+=step),
                float4(0.63864,    -0.114214, 	 0.262857,  0.0 )*fScale*(n+=step),
                float4(0.140679,   -0.475516, 	-0.0639818, 0.0 )*fScale*(n+=step),
                float4(-0.184051,   0.622119, 	 0.262857,  0.0 )*fScale*(n+=step),
                float4(-0.0796121,  0.158842, 	-0.677075,  0.0 )*fScale*(n+=step),
                float4(0.110007,   -0.219486, 	 0.435574,  0.0 )*fScale*(n+=step),
                float4(-0.0759516, -0.101676, 	-0.483625,  0.0 )*fScale*(n+=step),
                float4(0.235085,    0.314707,    0.696918,  0.0 )*fScale*(n+=step),
                float4(0.12493,    -0.0223423,	-0.483625,  0.0 )*fScale*(n+=step),
                float4(-0.290012,   0.0518654,   0.522688,  0.0 )*fScale*(n+=step),
                float4(-0.0720074,  0.243395, 	-0.967251,  0.0 )*fScale*(n+=step),
                float4(0.0975089,  -0.329594,    0.609803,  0.0 )*fScale*(n+=step)
        };

	// create random rot matrix
	float3 rotSample = tex2D(RandSample, ScreenTC.zw).rgb;
	rotSample = ((2.0 * rotSample - 1.0));
	//rotSample.z = abs(rotSample.z);
	//rotSample = float3(0,0,1);

  float fSceneDepth = tex2D( DepthMap, ScreenTC.xy ).r / PS_NearFarClipDist.y;
	// range conversions
  float fSceneDepthM = fSceneDepth * PS_NearFarClipDist.y;  

	float3 vSampleScale = SSAO_params.zzw
		* saturate(fSceneDepthM / 6.0f) // make area smaller if distance less than 5 meters
    * (1.f + fSceneDepthM / 32.f ); // make area bigger if distance more than 32 meters

  float fDepthRangeScale = PS_NearFarClipDist.y / vSampleScale.z * 0.85f;
	
	// convert from meters into SS units
	vSampleScale.xy *= 1.0f / fSceneDepthM;
	vSampleScale.z  *= 2.0f / (PS_NearFarClipDist.y);

  float fDepthTestSoftness = 64.f/vSampleScale.z;

	// sample
  float4 vSkyAccess = 0.f;
  float4 arrSceneDepth2[2];      
  float3 vIrrSample;
  float4 vDistance;
  float4 fRangeIsInvalid;

  const float bHQ = 1;//(GetShaderQuality()==QUALITY_HIGH);

  float fHQScale = 1;//0.5f;
  
  for(int i=0; i<2; i++)
  {    
    vIrrSample = mirror(arrKernel[i*4+0], rotSample) * vSampleScale;		
    arrSceneDepth2[0].x = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    if (bHQ)
    {
      //vIrrSample.xyz *= fHQScale;
      vIrrSample = mirror(arrKernel[8+i*4+0], rotSample) * vSampleScale;
      arrSceneDepth2[1].x = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    }

    vIrrSample = mirror(arrKernel[i*4+1], rotSample) * vSampleScale;		
    arrSceneDepth2[0].y = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    if (bHQ)
    {
      //vIrrSample.xyz *= fHQScale;
      vIrrSample = mirror(arrKernel[8+i*4+1], rotSample) * vSampleScale;
      arrSceneDepth2[1].y = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    }

    vIrrSample = mirror(arrKernel[i*4+2], rotSample) * vSampleScale;		
    arrSceneDepth2[0].z = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    if (bHQ)
    {
      //vIrrSample.xyz *= fHQScale;
      vIrrSample = mirror(arrKernel[8+i*4+2], rotSample) * vSampleScale;
      arrSceneDepth2[1].z = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    }

    vIrrSample = mirror(arrKernel[i*4+3], rotSample) * vSampleScale;		
    arrSceneDepth2[0].w = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    if (bHQ)
    {
      //vIrrSample.xyz *= fHQScale;
      vIrrSample = mirror(arrKernel[8+i*4+3], rotSample) * vSampleScale;
      arrSceneDepth2[1].w = tex2D( DepthMap, ScreenTC.xy + vIrrSample.xy ).r / PS_NearFarClipDist.y + vIrrSample.z;  
    }

    float fDefVal = 0.055f;

    for(int s=0; s<(bHQ ? 2 : 1); s++)
    {
      vDistance = fSceneDepth.xxxx - arrSceneDepth2[s]; 
      float4 vDistanceScaled = vDistance * fDepthRangeScale;// * (1.0f/PS_NearFarClipDist.y);
      fRangeIsInvalid = (saturate( abs(vDistanceScaled) ) + saturate( vDistanceScaled ))/2;  
      vSkyAccess += dot( lerp(saturate((-vDistance)*fDepthTestSoftness), fDefVal.xxxx, fRangeIsInvalid), (bHQ ? 1/16.0f : 1/8.0f).xxxx*2.0 );
    }
  }

  //Color = dot( vSkyAccess, (bHQ ? 1/16.0f : 1/8.0f).xxx*2.0 ) - SSAO_params.yyyy; // 0.075f
  Color = vSkyAccess - SSAO_params.yyyy; // 0.075f
  //Color = dot(vSkyAccess, (2.f/16.f).xxx);
  Color = saturate(lerp( 0.9f, Color, SSAO_params.x ));
  
  //Color.rgb = fSceneDepth.xxx/20.5f;
  //Color.rgb = 0.5f * rotSample+0.5f;
  //Color.rgb = float3(ScreenTC.xy, 0);
  
  if (fSceneDepth>10000)
	Color.rgb = float3(10,10,10);
  
  return Color;
}
/*
float4 computeSSAO(float2 UV, float3 Corner, float2 pixelsize)
{
		float	DeepM = 16000;
        float   SampleRadius  = 0.05 * DeepM;
        float   DistanceScale = 0.05 * DeepM;
        float   OccludeDist   = 0.5;

        float4 Samples[16] =
        {
                float4(0.355512,   -0.709318, 	-0.102371,  0.0 ),
                float4(0.534186,    0.71511, 	-0.115167,  0.0 ),
                float4(-0.87866,    0.157139, 	-0.115167,  0.0 ),
                float4(0.140679,   -0.475516, 	-0.0639818, 0.0 ),
                float4(-0.0796121,  0.158842, 	-0.677075,  0.0 ),
                float4(-0.0759516, -0.101676, 	-0.483625,  0.0 ),
                float4(0.12493,    -0.0223423,	-0.483625,  0.0 ),
                float4(-0.0720074,  0.243395, 	-0.967251,  0.0 ),
                float4(-0.207641,   0.414286, 	 0.187755,  0.0 ),
                float4(-0.277332,  -0.371262, 	 0.187755,  0.0 ),
                float4(0.63864,    -0.114214, 	 0.262857,  0.0 ),
                float4(-0.184051,   0.622119, 	 0.262857,  0.0 ),
                float4(0.110007,   -0.219486, 	 0.435574,  0.0 ),
                float4(0.235085,    0.314707,    0.696918,  0.0 ),
                float4(-0.290012,   0.0518654,   0.522688,  0.0 ),
                float4(0.0975089,  -0.329594,    0.609803,  0.0 )
        };
        
        float  fColour     = 0.0f;
        
        float2 nUV         = UV;

        float  Deep        = tex2D(DepthMap, nUV).r;
        
        float3 Norm        = normalize(2*tex2D(RandSample, nUV * float2(320,200)).rgb-1);

        float4 SE          = float4((normalize(Corner) * Deep * DeepM),1);
        SE = mul(ModelViewInv, SE);
        //SE = mul(ModelView, SE);
        //float3 SE = float3(Corner.xy, Deep  * DeepM);
        
        float3 Ray;
        float4 Sample;
        float4 SS;
        float sDeep = 0;
        float2 sUV;
        
        for(int i = 0; i < 16; i++)
        {
                Ray    = mirror(Samples[i].xyz, Norm) * SampleRadius;
                //Ray    = Samples[i].xyz * SampleRadius;
                
                Sample = float4(Ray + SE.xyz, SE.w);
                //SS     = mul(ModelViewProj, Sample);
                Sample = mul(ModelView, Sample);
                SS     = mul(Proj, Sample);
                
                sUV    = 0.5 * (SS.xy/SS.w) + float2(0.5, 0.5);
                sUV.y         = 1-sUV.y;
                sUV.x         = 1-sUV.x;
                
                //sUV    = 2 * (SS.xy/SS.w) - float2(1, 1);
                //sUV.y         = 1-sUV.y;
                
                //sUV    = (SS.xy/SS.w);///SS.w);
                
                //sUV = 0.5 * Sample.xy + float2(0.5, 0.5);
                //sUV.y         = 1-sUV.y;
                
                //sUV = nUV + Samples[i].xy * pixelsize * SampleRadius;
                
                sDeep   = tex2D(DepthMap, sUV).r;


                //this check is hacky, change it when you have time.
                if(length(Deep - sDeep) * DeepM > OccludeDist)
                {
                        fColour++;
                }
                else
                {
                        float Occlude = DistanceScale * max(Deep - sDeep, 0);
                        fColour      += 1 / (1 + (Occlude * Occlude) * 0.1);
                }
                

				float Occlude = DistanceScale * max(Deep - sDeep, 0);
				fColour += min(1.0f, Occlude);

        }

        fColour           = 1.f-fColour/16;
        return float4(fColour, fColour, fColour, 1);
        //return float4((sDeep/32).xxx, 1.f);
        //return float4(length(Deep - sDeep).xxx*100,1);
        //return tex2D(DepthMap, nUV)/2048;
        //return float4(sUV, 0, 1);
        //return Proj[3];
        //return SS;
        //return float4(SS, 1.f);
}
*/
float4 main(in VertexOUT IN // From vertex shader
			) : COLOR
{
	//return computeSSAO(IN.texCoord, IN.Corner, IN.texCoord2);
	return computeSSAO_Crysis(IN.texCoord);
}