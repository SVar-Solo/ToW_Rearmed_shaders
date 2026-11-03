#ifndef SPEEDTREE_DEFAULTS_HLSLI
#define SPEEDTREE_DEFAULTS_HLSLI

// Default SpeedTree configuration.
// Only compile-time constants and always-on material/layer flags live here.
// Feature variants (USE_FOG, SUPPORT_360_BILLBOARDS, INTERMEDIATE_FRONDBRANCH_FADING,
// HORZ_BILLBOARDS, BRANCH_DETAIL_LAYER, UPVECTOR_POS_Y, ...) must come from the
// engine define set for the particular shader variant; do not enable them here.
// Define SPEEDTREE_CUSTOM_CONFIG before including this file to supply your own set.
#ifndef SPEEDTREE_CUSTOM_CONFIG
#ifndef NUM_WIND_MATRICES
#define NUM_WIND_MATRICES 7
#endif
#ifndef MAX_NUM_LEAF_ANGLES
#define MAX_NUM_LEAF_ANGLES 20
#endif
#ifndef NUM_360_IMAGES
#define NUM_360_IMAGES 32
#endif
#ifndef BRANCH_NORMAL_MAPPING
#define BRANCH_NORMAL_MAPPING
#endif
#ifndef FROND_NORMAL_MAPPING
#define FROND_NORMAL_MAPPING
#endif
#ifndef LEAF_NORMAL_MAPPING
#define LEAF_NORMAL_MAPPING
#endif
#ifndef SELF_SHADOW_LAYER
#define SELF_SHADOW_LAYER
#endif
#ifndef BILLBOARD_NORMAL_MAPPING
#define BILLBOARD_NORMAL_MAPPING
#endif
#ifndef USE_SHADOWS
#define USE_SHADOWS
#endif
#endif // SPEEDTREE_CUSTOM_CONFIG

#endif // SPEEDTREE_DEFAULTS_HLSLI
