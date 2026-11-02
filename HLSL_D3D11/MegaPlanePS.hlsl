// D3D11 port of MegaPlanePS.hlsl. Generated from the legacy HLSL source; see README.md.
// defines
#define PSSM 1
//#define USE_FOG
//#define USE_FOG1
// From vertex shader
struct VertexOUT
{
#ifdef USE_FOG
	float4 FogColor: COLOR0;
#endif
	float4 coord : TEXCOORD0;
	float4 spos : TEXCOORD1;
	float4 screen_pos : TEXCOORD2;
#ifdef USE_FOG
	float3 fogCoord : TEXCOORD3;
#endif
};

Texture2D IndirTex : register(t0);
SamplerState IndirTex_Sampler : register(s0); // Base texture
Texture2D MegaCacheTex : register(t1);
SamplerState MegaCacheTex_Sampler : register(s1); // Base texture
cbuffer MegaPlanePS_CB0 : register(b0)
{
float3 MGT_TILE_SIZE; // MegaTexSize + TileSize + (MegaTexSize / TileSize)
};
Texture2D GBufferTex : register(t2);
SamplerState GBufferTex_Sampler : register(s2);           //shadow map
Texture2D typeMap : register(t3);
SamplerState typeMap_Sampler : register(s3); 
Texture2D megaNoise : register(t4);
SamplerState megaNoise_Sampler : register(s4);
Texture2D maskDSDT : register(t5);
SamplerState maskDSDT_Sampler : register(s5);
#ifdef USE_FOG
TextureCube SkyMap : register(t6);
SamplerState SkyMap_Sampler : register(s6); // Fog texture
#endif
Texture2D NormalMap : register(t7);
SamplerState NormalMap_Sampler : register(s7); // bump texture
cbuffer MegaPlanePS_CB1 : register(b1)
{
float3 SunDir;
};
Texture2D CommonNoise : register(t8);
SamplerState CommonNoise_Sampler : register(s8); // bump texture
Texture2D FarMainTex : register(t9);
SamplerState FarMainTex_Sampler : register(s9); // old method nearmaintex
cbuffer MegaPlanePS_CB2 : register(b2)
{
float commonNoiseTile;
float3 koeffNdotL;
float fSkyMultiplier;

float3 SunDiffuse;
float3 SunAmbient;
};
#ifdef CLIPPING
cbuffer MegaPlanePS_CB3 : register(b3)
{
	float fClipPlaneZ;
};
#endif

cbuffer MegaPlanePS_CB4 : register(b4)
{
float2 gRTSize;

};
float4 getMegaNumberPixel(float2 coord)
{
	float mgSize = 256*256;//MGT_TILE_SIZE.x;
	float tileSize = 256;//MGT_TILE_SIZE.y;
	float scaleDSDT = 4.0f/mgSize;
	float tablesize = 8;
	float4 DsDtLookup = 2*maskDSDT.Sample(maskDSDT_Sampler, 128*coord.xy)-1;
	float2 newst = float2(coord.x + scaleDSDT * DsDtLookup.x, coord.y + scaleDSDT * DsDtLookup.y);
	//float2 newst = coord.xy;
	float4 col = typeMap.Sample(typeMap_Sampler, newst);
	float noise_idx = round(col.r*255);
	float tileY = floor(noise_idx/tablesize);
	float tileX = noise_idx - tileY*tablesize;
	float2 tileUV = float2(tileX, tileY);
	float2 offsetUV = frac(coord * (mgSize / tileSize));
	float2 megaUV = (tileUV+offsetUV)/tablesize;
	col = megaNoise.Sample(megaNoise_Sampler, megaUV);
	//col = tex2Dlod(megaNoise, float4(megaUV,0,land_lod) );
	//col = tex2D(megaNoise, megaUV, ddx(coord*2048)*0, ddy(coord*2048)*0);
	//col = tex2D(megaNoise, megaUV, ddx(megaUV), ddy(megaUV));
	//col = float4(clamp(ddx(megaUV), float2(0,0), float2(0.01, 0.01)), ddy(megaUV));
	//float MAX_DD = 1.1;
	//float2 nddx = clamp(ddx(megaUV), float2(0,0), float2(MAX_DD, MAX_DD)); 
	//float2 nddy = clamp(ddy(megaUV), float2(0,0), float2(MAX_DD, MAX_DD));
	//float2 nddx = ddx(megaUV);
	//float2 nddy = ddy(coord*256);
	//col = tex2D(megaNoise, megaUV, nddx, nddy);
	//col = float4(nddy, 0, 1);
	return col;
}

float4 getBilinearFilteredMegaNoise(float2 uv)
{

  //float4 col = tex2D(IndirTex, uv);
  //float lod = floor(col.a*255);
  //float mgs = MGT_TILE_SIZE.x/pow(2,lod);
  float mgs = 256*256;

  uv.x *= mgs;
  uv.y *= mgs;
  float x = floor(uv.x);
  float y = floor(uv.y);
  float u_ratio = uv.x - x;
  float v_ratio = uv.y - y;
  float u_opposite = 1 - u_ratio;
  float v_opposite = 1 - v_ratio;
  float4 result = (getMegaNumberPixel(float2(x,y)/mgs) * u_opposite  + getMegaNumberPixel(float2(x+1,y)/mgs) * u_ratio) * v_opposite + 
                  (getMegaNumberPixel(float2(x,y+1)/mgs) * u_opposite  + getMegaNumberPixel(float2(x+1,y+1)/mgs) * u_ratio) * v_ratio;
  return result;
}

float4 getMegaPixel(float2 coord)
{
	float mgSize = MGT_TILE_SIZE.x;
	float tileSize = MGT_TILE_SIZE.y;
	float tileCount = MGT_TILE_SIZE.z;
	float cache_sidesize = 64;
	float4 col = IndirTex.Sample(IndirTex_Sampler, float2(coord.x, coord.y));
	float lod = (col.a*255);
//	land_lod = lod;
	float tileY = (col.g*255);
	float tileX = (col.r*255);
	float2 tileUV = float2(round(tileX), round(tileY));
	float2 offsetUV = frac(coord * tileCount / pow(2,lod) );
	float2 megaUV = (tileUV+offsetUV)/cache_sidesize;
	float4 pix = MegaCacheTex.Sample(MegaCacheTex_Sampler, megaUV);
	return pix;
}

float4 getBilinearFilteredMegaPixel(float2 uv)
{
  float mgs = MGT_TILE_SIZE.x;
   
  uv *= (MGT_TILE_SIZE.x/(1.0f+MGT_TILE_SIZE.x));
  //uv -= (1.0f/MGT_TILE_SIZE.x).xx;

  uv.x *= mgs;
  uv.y *= mgs;
  float x = floor(uv.x);
  float y = floor(uv.y);
  float u_ratio = uv.x - x;
  float v_ratio = uv.y - y;
  float u_opposite = 1 - u_ratio;
  float v_opposite = 1 - v_ratio;

  float4 result = (getMegaPixel(float2(x,y)/mgs) * u_opposite  + getMegaPixel(float2(x+1,y)/mgs) * u_ratio) * v_opposite + 
                  (getMegaPixel(float2(x,y+1)/mgs) * u_opposite  + getMegaPixel(float2(x+1,y+1)/mgs) * u_ratio) * v_ratio;
  return result;
}

/// This function evaluates the mipmap LOD level for a 2D texture using the given texture coordinates
/// and texture size (in pixels)
float mipmapLevel(float2 uv, float2 textureSize)
{
    float2 dx = ddx(uv * textureSize.x);
    float2 dy = ddy(uv * textureSize.y);
    float d = max(dot(dx, dx), dot(dy, dy));
    return 0.5 * log2(d);
}

/// This function samples a texture with tiling and mipmapping from within a texture pack of the given
/// attributes
/// - tex is the texture pack from which to sample a tile
/// - uv are the texture coordinates of the pixel *inside the tile*
/// - tile are the coordinates of the tile within the pack (ex.: 2, 1)
/// - packTexFactors are some constants to perform the mipmapping and tiling
/// Texture pack factors:
/// - inverse of the number of horizontal tiles (ex.: 4 tiles -> 0.25)
/// - inverse of the number of vertical tiles (ex.: 2 tiles -> 0.5)
/// - size of a tile in pixels (ex.: 1024)
/// - amount of bits representing the power-of-2 of the size of a tile (ex.: a 1024 tile is 10 bits).
float4 sampleTexturePackMipWrapped(in Texture2D tex, in SamplerState tex_Sampler, in float2 uv, in float2 tile, in float4 packTexFactors)
{
	/// estimate mipmap/LOD level
	float lod = mipmapLevel(uv, float2(packTexFactors.zz));
	lod = clamp(lod, 0.0, packTexFactors.w);

	/// get width/height of the whole pack texture for the current lod level
	float size = pow(2.0, packTexFactors.w - lod);
	float sizex = size / packTexFactors.x; // width in pixels
	float sizey = size / packTexFactors.y; // height in pixels

	/// perform tiling
	uv = frac(uv);

	/// tweak pixels for correct bilinear filtering, and add offset for the wanted tile
	uv.x = uv.x * ((sizex * packTexFactors.x - 1.0) / sizex) + 0.5 / sizex + packTexFactors.x * tile.x;
	uv.y = uv.y * ((sizey * packTexFactors.y - 1.0) / sizey) + 0.5 / sizey + packTexFactors.y * tile.y;

    return tex.SampleLevel(tex_Sampler, (float4(uv, 0, lod)).xy, (float4(uv, 0, lod)).w);
}

float4 getNoisePS30(float2 coord)
{
	float tile_tiling = 256.f; // how many times tiles are tiling across landscape
	float side_tile = 4.f; // texture atlas 8x8 tiles
	float tile_pixel_size = 512.f; // size in pixel of tile in atlas
	float tile_bits_size = 9.f; // 256->8bit, 512->9bit, 1024->10bit ...
	float4 packTexFactors = float4(1.f/side_tile, 1.f/side_tile, tile_pixel_size, tile_bits_size);
	float2 diffusing = float2(16.0f, 128.f); // raduis, tiling of DSDT
	
	//float2 coord = IN.coord.xy;
	
	float mgSize = tile_tiling*tile_pixel_size;
	float tileSize = tile_pixel_size;
	float scaleDSDT = diffusing.x/mgSize;
	float tablesize = side_tile;
	float4 DsDtLookup = 2*maskDSDT.Sample(maskDSDT_Sampler, diffusing.y*coord.xy)-1;
	float2 newst = float2(coord.x + scaleDSDT * DsDtLookup.x, coord.y + scaleDSDT * DsDtLookup.y);
	//float2 newst = float2(coord.x, coord.y);
	float4 col = typeMap.Sample(typeMap_Sampler, newst);
	float4 col2 = typeMap.Sample(typeMap_Sampler, coord);
	if (col.a<1.0f)
		col = col2;
	float noise_idx = round(col.r*255);
	float tileY = floor(noise_idx/tablesize);
	float tileX = noise_idx - tileY*tablesize;
	//float2 tileUV = float2(tileX, tileY);
	//float2 offsetUV = frac(coord * (mgSize / tileSize));
	//float2 megaUV = (tileUV+offsetUV)/tablesize;
	
	float2 tile = float2(tileX,tileY);
	
	return sampleTexturePackMipWrapped(megaNoise, megaNoise_Sampler, coord.xy*tile_tiling, tile, packTexFactors);
}

float4 main(in VertexOUT IN) : SV_Target0
{
	float4 result;
	
#ifdef CLIPPING
	if (IN.coord.z<fClipPlaneZ)
		discard;
#endif
	result =  getBilinearFilteredMegaPixel(IN.coord.xy);
	float4 LandLight = result;
	float4 CommonNoisePixel = CommonNoise.Sample(CommonNoise_Sampler, IN.coord.xy*commonNoiseTile);
	result.rgb *= CommonNoisePixel.rgb*2.f;
	
	float2 scaleCenter = float2(0.5f, 0.5f);
	float2 input = (IN.coord - scaleCenter) * 0.5f + scaleCenter;
	float4 simpleTex = FarMainTex.Sample(FarMainTex_Sampler, input);
	float ndlSimple = simpleTex.a; 
	
	float ndl = 1.f;
	float4 TMColor = typeMap.Sample(typeMap_Sampler, IN.coord.xy);
	result.a = TMColor.a;
	float3 normal = float3(0,0,1);

#ifdef USE_BUMP
	float4 normPixel = NormalMap.Sample(NormalMap_Sampler, float2(IN.coord.x, 1-IN.coord.y));
	normal = 2*float3(normPixel.a, 1-normPixel.g, 0)-1;
	float sx = normal.x;
	float sy = normal.y;
	float sz = sqrt(1.0f-(sx*sx+sy*sy));
	normal = normalize(float3(sx, sy, sz));
#endif

#ifdef USE_NOISE
	float R1 = 100.f;
	float R2 = 400.f;
	float factor = clamp((IN.spos.z-R1)/(R2-R1),0,1);

#ifdef SM30
	float4 noise_pixel = getNoisePS30(IN.coord.xy);
	float3 noise_normal = normalize(2*noise_pixel.rgb-1);
	float3 Nx = float3(noise_normal.z, 0, -noise_normal.x);
	float3 Ny = float3(0, noise_normal.z, -noise_normal.y);
	normal.xyz = lerp(normalize(normal.z * noise_normal.xyz + normal.x * Nx + normal.y * Ny), normal, factor);
#else
	float4 noise_pixel = getMegaNumberPixel(IN.coord.xy);
#endif
	result.rgb = lerp(result.rgb*noise_pixel.a*2, result.rgb, factor);
#endif
#ifdef USE_BUMP
	ndl *= saturate(dot(SunDir, normal));
#else
#ifdef USE_NOISE
	ndl *= saturate(dot(SunDir, normal));
#endif //USE_NOISE
#endif //USE_BUMP

	// read GBuffer
	float2 screen_uv = IN.screen_pos.xy/IN.screen_pos.w;
	screen_uv.x = 0.5f * (1.0f + screen_uv.x) + 0.5f/gRTSize.x;
	screen_uv.y = 0.5f * (1.0f - screen_uv.y) + 0.5f/gRTSize.y;
	float4 gbuffer = GBufferTex.Sample(GBufferTex_Sampler, screen_uv.xy);
	
#ifdef SHADOW
	float shadow_factor = gbuffer.r;
	ndl *= shadow_factor;
#endif  //SHADOW

	float smoothBorder1 = 1.0f/32.0f; // 32/2048 = 64 метра от края HF
	float smoothBorder2 = 1.0f - smoothBorder1;

	ndl = clamp(ndl*koeffNdotL.x + koeffNdotL.y, 0, 1);
	result.rgb *= lerp(SunAmbient*gbuffer.g, (SunDiffuse*koeffNdotL.z), ndl);
		
	if (!(IN.coord.x > smoothBorder1 && IN.coord.x < smoothBorder2 && IN.coord.y > smoothBorder1 && IN.coord.y < smoothBorder2))
	{
		float factorX = smoothstep(0.0f, smoothBorder1, IN.coord.x) * (1.0f - smoothstep(smoothBorder2, 1.0f, IN.coord.x));
		float factorY = smoothstep(0.0f, smoothBorder1, IN.coord.y) * (1.0f - smoothstep(smoothBorder2, 1.0f, IN.coord.y));
		ndlSimple = clamp(ndlSimple*koeffNdotL.x + koeffNdotL.y, 0, 1);
		simpleTex.a = 1.f;
		result.a = 1.f;
		simpleTex.rgb *= CommonNoisePixel.rgb * 2.f;
		simpleTex.rgb *= lerp(SunAmbient, (SunDiffuse*koeffNdotL.z), ndlSimple);
		result.rgb = lerp(simpleTex.rgb, result.rgb, factorX * factorY);
	}


	//result.rgb *= lerp(SunAmbient*gbuffer.g, (SunDiffuse*koeffNdotL.z), ndl);

	return result;			
}