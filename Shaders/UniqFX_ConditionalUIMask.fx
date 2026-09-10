/*===================================================================================================
    UniqFX : ConditionalUIMask
    Version: 2026.09.15
    Author : Dominik Wojtasik
    License: MIT
    Source : https://github.com/dwojtasik/UniqFX

    Allows to setup multiple backbuffer checkpoints and restore them on given UI boxes
    using conditional comparisons of colors and depths at given samples.

    Preprocessor resolution (UNIQ_UI_RES_WIDTH, UNIQ_UI_RES_HEIGHT) is used to determine the original
    dimensions of backbuffer used to create given preset. This allows to use same preset to be scaled
    regardless of current game resolution. Do note that sampling and debugging values are derived from
    preprocessor values rather than current resolution of the game.

    Setup preprocessor variables:
    UNIQ_UI_RES_WIDTH [num]          - width of original resolution that was used to setup UI.
    UNIQ_UI_RES_HEIGHT [num]         - height of original resolution that was used to setup UI.
    UNIQ_UI_CHECKPOINTS [1-3]        - number of backbuffer checkpoint passes to generate.
    CHECKPOINT_FRAME_SMOOTHING [0-3] - number of previous frames to additionaly store
                                       per checkpoint to average results for color sampling.
    UNIQ_UI_BOX_COUNT [1-15]         - number of UI boxes to configure.
    UNIQ_UI_CONDITIONS [1-5]         - max number of conditions to setup per UI box.
    ENABLE_SETUP_MODE [0-1]          - enables setup mode where user can setup UI boxes & samples
                                       for conditions and preview their position visually.
    ENABLE_DEBUG_STATS [0-1]         - enables debug stats window.

    NOTE: Shader can compile for a long time when set to high values of preprocessor variables.

    Read Help section in ReshadeUI for step-by-step setup instructions.
===================================================================================================*/

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

#if BUFFER_COLOR_BIT_DEPTH > 8
    #define UNIQ_UI_COLOR_FORMAT RGBA16F
#else
    #define UNIQ_UI_COLOR_FORMAT RGBA8
#endif

#define UNIQ_UI_SHADE_RGB    0
#define UNIQ_UI_SHADE_CHROMA 1
#define UNIQ_UI_SHADE_HUE    2
#define UNIQ_UI_SHADE_MIX    3

#define UNIQ_UI_SHADE_ITEMS \
    "Exact RGB\0Any Brightness (Same Color)\0Hue Only\0Transparent UI (EXPERIMENTAL)\0"

#define UNIQ_UI_DEPTH_EXACT 0
#define UNIQ_UI_DEPTH_GE    1
#define UNIQ_UI_DEPTH_LE    2
#define UNIQ_UI_DEPTH_EXACT_EPS 0.01

#define UNIQ_UI_DEPTH_ITEMS \
    "Exact\0Greater Than or Equal\0Less Than or Equal\0"

#ifndef UNIQ_UI_CHECKPOINTS
    #define UNIQ_UI_CHECKPOINTS 1
#endif
#if UNIQ_UI_CHECKPOINTS < 1
    #undef UNIQ_UI_CHECKPOINTS
    #define UNIQ_UI_CHECKPOINTS 1
#elif UNIQ_UI_CHECKPOINTS > 3
    #undef UNIQ_UI_CHECKPOINTS
    #define UNIQ_UI_CHECKPOINTS 3
#endif

#ifndef CHECKPOINT_FRAME_SMOOTHING
    #define CHECKPOINT_FRAME_SMOOTHING 0
#endif
#if CHECKPOINT_FRAME_SMOOTHING < 0
    #undef CHECKPOINT_FRAME_SMOOTHING
    #define CHECKPOINT_FRAME_SMOOTHING 0
#elif CHECKPOINT_FRAME_SMOOTHING > 3
    #undef CHECKPOINT_FRAME_SMOOTHING
    #define CHECKPOINT_FRAME_SMOOTHING 3
#endif

#ifndef UNIQ_UI_BOX_COUNT
    #define UNIQ_UI_BOX_COUNT 1
#endif
#if UNIQ_UI_BOX_COUNT < 1
    #undef UNIQ_UI_BOX_COUNT
    #define UNIQ_UI_BOX_COUNT 1
#elif UNIQ_UI_BOX_COUNT > 15
    #undef UNIQ_UI_BOX_COUNT
    #define UNIQ_UI_BOX_COUNT 15
#endif

#define UNIQ_UI_WHEN_BOX_1(M) M(1)
#if UNIQ_UI_BOX_COUNT >= 2
    #define UNIQ_UI_WHEN_BOX_2(M) M(2)
#else
    #define UNIQ_UI_WHEN_BOX_2(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 3
    #define UNIQ_UI_WHEN_BOX_3(M) M(3)
#else
    #define UNIQ_UI_WHEN_BOX_3(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 4
    #define UNIQ_UI_WHEN_BOX_4(M) M(4)
#else
    #define UNIQ_UI_WHEN_BOX_4(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 5
    #define UNIQ_UI_WHEN_BOX_5(M) M(5)
#else
    #define UNIQ_UI_WHEN_BOX_5(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 6
    #define UNIQ_UI_WHEN_BOX_6(M) M(6)
#else
    #define UNIQ_UI_WHEN_BOX_6(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 7
    #define UNIQ_UI_WHEN_BOX_7(M) M(7)
#else
    #define UNIQ_UI_WHEN_BOX_7(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 8
    #define UNIQ_UI_WHEN_BOX_8(M) M(8)
#else
    #define UNIQ_UI_WHEN_BOX_8(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 9
    #define UNIQ_UI_WHEN_BOX_9(M) M(9)
#else
    #define UNIQ_UI_WHEN_BOX_9(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 10
    #define UNIQ_UI_WHEN_BOX_10(M) M(10)
#else
    #define UNIQ_UI_WHEN_BOX_10(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 11
    #define UNIQ_UI_WHEN_BOX_11(M) M(11)
#else
    #define UNIQ_UI_WHEN_BOX_11(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 12
    #define UNIQ_UI_WHEN_BOX_12(M) M(12)
#else
    #define UNIQ_UI_WHEN_BOX_12(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 13
    #define UNIQ_UI_WHEN_BOX_13(M) M(13)
#else
    #define UNIQ_UI_WHEN_BOX_13(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 14
    #define UNIQ_UI_WHEN_BOX_14(M) M(14)
#else
    #define UNIQ_UI_WHEN_BOX_14(M)
#endif
#if UNIQ_UI_BOX_COUNT >= 15
    #define UNIQ_UI_WHEN_BOX_15(M) M(15)
#else
    #define UNIQ_UI_WHEN_BOX_15(M)
#endif
#define UNIQ_UI_EACH_BOX_A_TAIL(M) \
    UNIQ_UI_WHEN_BOX_2(M) \
    UNIQ_UI_WHEN_BOX_3(M) \
    UNIQ_UI_WHEN_BOX_4(M) \
    UNIQ_UI_WHEN_BOX_5(M)
#define UNIQ_UI_EACH_BOX_B_TAIL(M) \
    UNIQ_UI_WHEN_BOX_7(M) \
    UNIQ_UI_WHEN_BOX_8(M) \
    UNIQ_UI_WHEN_BOX_9(M) \
    UNIQ_UI_WHEN_BOX_10(M)
#define UNIQ_UI_EACH_BOX_C_TAIL(M) \
    UNIQ_UI_WHEN_BOX_12(M) \
    UNIQ_UI_WHEN_BOX_13(M) \
    UNIQ_UI_WHEN_BOX_14(M) \
    UNIQ_UI_WHEN_BOX_15(M)
#define UNIQ_UI_EACH_BOX_A(M) \
    UNIQ_UI_WHEN_BOX_1(M) \
    UNIQ_UI_EACH_BOX_A_TAIL(M)
#define UNIQ_UI_EACH_BOX_B(M) \
    UNIQ_UI_WHEN_BOX_6(M) \
    UNIQ_UI_EACH_BOX_B_TAIL(M)
#define UNIQ_UI_EACH_BOX_C(M) \
    UNIQ_UI_WHEN_BOX_11(M) \
    UNIQ_UI_EACH_BOX_C_TAIL(M)
#define UNIQ_UI_EACH_BOX_TAIL(M) \
    UNIQ_UI_EACH_BOX_A_TAIL(M) \
    UNIQ_UI_WHEN_BOX_6(M) \
    UNIQ_UI_EACH_BOX_B_TAIL(M) \
    UNIQ_UI_WHEN_BOX_11(M) \
    UNIQ_UI_EACH_BOX_C_TAIL(M)
#define UNIQ_UI_EACH_BOX(M) \
    UNIQ_UI_WHEN_BOX_1(M) \
    UNIQ_UI_EACH_BOX_TAIL(M)

#ifndef UNIQ_UI_CONDITIONS
    #define UNIQ_UI_CONDITIONS 3
#endif
#if UNIQ_UI_CONDITIONS < 1
    #undef UNIQ_UI_CONDITIONS
    #define UNIQ_UI_CONDITIONS 1
#elif UNIQ_UI_CONDITIONS > 5
    #undef UNIQ_UI_CONDITIONS
    #define UNIQ_UI_CONDITIONS 5
#endif

#ifndef UNIQ_UI_RES_WIDTH
    #define UNIQ_UI_RES_WIDTH 1920
#endif
#if UNIQ_UI_RES_WIDTH < 1
    #undef UNIQ_UI_RES_WIDTH
    #define UNIQ_UI_RES_WIDTH 1
#endif
#ifndef UNIQ_UI_RES_HEIGHT
    #define UNIQ_UI_RES_HEIGHT 1080
#endif
#if UNIQ_UI_RES_HEIGHT < 1
    #undef UNIQ_UI_RES_HEIGHT
    #define UNIQ_UI_RES_HEIGHT 1
#endif

#ifndef ENABLE_SETUP_MODE
    #define ENABLE_SETUP_MODE 1
#endif

#ifndef ENABLE_DEBUG_STATS
    #define ENABLE_DEBUG_STATS 1
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
    #include "DrawText.fxh"
    #pragma reshade skipoptimization
#endif

#if ENABLE_SETUP_MODE
    #define UNIQ_UI_PANEL_W 204.0
    #define UNIQ_UI_PANEL_H 176.0
    #define UNIQ_UI_ZOOM_TW 32
    #define UNIQ_UI_ZOOM_TH 18
    #define UNIQ_UI_ZOOM_SCALE 7
    #define UNIQ_UI_ZOOM_CX 15
    #define UNIQ_UI_ZOOM_CY 8
    #define UNIQ_UI_ZOOM_GAP 12
    #define UNIQ_UI_ZOOM_BORDER 2
    #define UNIQ_UI_ZOOM_W (UNIQ_UI_ZOOM_TW * UNIQ_UI_ZOOM_SCALE + UNIQ_UI_ZOOM_BORDER * 2)
    #define UNIQ_UI_ZOOM_H (UNIQ_UI_ZOOM_TH * UNIQ_UI_ZOOM_SCALE + UNIQ_UI_ZOOM_BORDER * 2)
    #define UNIQ_UI_STATE_STATS_BASE 4
    #define UNIQ_UI_STATE_MAGIC 0.8125
#elif ENABLE_DEBUG_STATS
    #define UNIQ_UI_STATE_STATS_BASE 0
#endif

#if ENABLE_SETUP_MODE && ENABLE_DEBUG_STATS
    #define UNIQ_UI_STATE_N 7
#elif ENABLE_SETUP_MODE
    #define UNIQ_UI_STATE_N 4
#elif ENABLE_DEBUG_STATS
    #define UNIQ_UI_STATE_N 3
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
    #define UNIQ_UI_DRAG_SLOP 6.0
#endif

#define UNIQ_UI_ORIG float2((float)UNIQ_UI_RES_WIDTH, (float)UNIQ_UI_RES_HEIGHT)

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
    #define UNIQ_UI_DT_SIZE 14.0
    #define UNIQ_UI_DT_RATIO 1.0
#endif

#if ENABLE_DEBUG_STATS
    #define UNIQ_UI_STATS_W 340.0
    #define UNIQ_UI_STATS_PAD 8.0
    #define UNIQ_UI_STATS_ROW 14.0
    #define UNIQ_UI_STATS_LINES (4 + UNIQ_UI_CONDITIONS * 2)
    #define UNIQ_UI_STATS_CONTENT_H (UNIQ_UI_STATS_PAD * 2.0 + UNIQ_UI_BOX_COUNT * UNIQ_UI_STATS_LINES * UNIQ_UI_STATS_ROW)
    #define UNIQ_UI_STATS_VIEW_BOXES 3.5
    #define UNIQ_UI_STATS_VIEW_MAX (UNIQ_UI_STATS_PAD * 2.0 + UNIQ_UI_STATS_VIEW_BOXES * UNIQ_UI_STATS_LINES * UNIQ_UI_STATS_ROW)
    #define UNIQ_UI_STATS_BAR_W 8.0
    #define UNIQ_UI_STATS_WHEEL (UNIQ_UI_STATS_ROW * 3.0)
    #define UNIQ_UI_STATS_MARGIN 16.0
    #define UNIQ_UI_STATE_STATS_SCROLL (UNIQ_UI_STATE_STATS_BASE + 2)
#endif

#if UNIQ_UI_CHECKPOINTS == 1
    #define UNIQ_UI_CKPT_ITEMS "Checkpoint 1\0"
#elif UNIQ_UI_CHECKPOINTS == 2
    #define UNIQ_UI_CKPT_ITEMS "Checkpoint 1\0Checkpoint 2\0"
#else
    #define UNIQ_UI_CKPT_ITEMS "Checkpoint 1\0Checkpoint 2\0Checkpoint 3\0"
#endif

#define UNIQ_UI_VIEW_ITEMS "None\0Setup (Boxes + Samples)\0Combined Mask (Displayed)\0Mask (For Checkpoint)\0Checkpoint Pass\0Depth\0Combined Debug Output\0"
#define UNIQ_UI_VIEW_NONE      0
#define UNIQ_UI_VIEW_SETUP     1
#define UNIQ_UI_VIEW_MASK      2
#define UNIQ_UI_VIEW_MASK_CKPT 3
#define UNIQ_UI_VIEW_CKPT      4
#define UNIQ_UI_VIEW_DEPTH     5
#define UNIQ_UI_VIEW_COMBINED  6

#define UNIQ_UI_LEGEND_ITEMS "Off\0Top-Left\0Top-Right\0Bottom-Left\0Bottom-Right\0"
#define UNIQ_UI_LEGEND_OFF 0
#define UNIQ_UI_LEGEND_TL  1
#define UNIQ_UI_LEGEND_TR  2
#define UNIQ_UI_LEGEND_BL  3
#define UNIQ_UI_LEGEND_BR  4
#define UNIQ_UI_LEGEND_W   154.0
#define UNIQ_UI_LEGEND_H   110.0

#define UNIQ_UI_COL_BOX_ON  float3(0.12, 0.90, 0.22)
#define UNIQ_UI_COL_BOX_OFF float3(0.85, 0.12, 0.12)
#define UNIQ_UI_COL_BOX_DIS float3(0.35, 0.35, 0.40)
#define UNIQ_UI_COL_PROBE   float3(1.00, 0.92, 0.20)
#define UNIQ_UI_COL_COND    float3(0.95, 0.38, 0.92)
#define UNIQ_UI_COL_CUR     float3(0.70, 0.70, 0.74)
#define UNIQ_UI_COL_FRZ     float3(0.20, 0.90, 0.80)

#if UNIQ_UI_CHECKPOINTS > 1
    #define UNIQ_UI_DECL_STORE(B, CAT) \
        uniform int UI_B##B##_STORE < ui_type = "combo"; ui_label = "Restore Checkpoint"; ui_items = UNIQ_UI_CKPT_ITEMS; ui_tooltip = "Which checkpoint this box restores."; ui_category = CAT; > = 0;
    #define UNIQ_UI_STORE_SEL(B) UI_B##B##_STORE
    #define UNIQ_UI_DECL_SAMP(B, N, CAT) \
        uniform int UI_B##B##_C##N##_SAMP < ui_type = "combo"; ui_label = "Sampling Checkpoint"; ui_items = UNIQ_UI_CKPT_ITEMS; ui_tooltip = \
            "Checkpoint used for color matching.\n" \
            "Depth always comes from the ReShade depth buffer."; ui_category = CAT; > = 0;
    #define UNIQ_UI_SAMP_SEL(B, N) UI_B##B##_C##N##_SAMP
#else
    #define UNIQ_UI_DECL_STORE(B, CAT)
    #define UNIQ_UI_STORE_SEL(B) 0
    #define UNIQ_UI_DECL_SAMP(B, N, CAT)
    #define UNIQ_UI_SAMP_SEL(B, N) 0
#endif

#if CHECKPOINT_FRAME_SMOOTHING >= 1
    #define UNIQ_UI_DECL_SMOOTH(B, N, CAT) \
        uniform int UI_B##B##_C##N##_SMOOTH < ui_type = "slider"; ui_label = "Frame Smoothing"; ui_tooltip = \
            "Averages color from given checkpoint using current and N previous frames.\n" \
            "Use only when sampled color is rapidly changing to reduce pixel flickering.\n" \
            "Restore still uses the current snapshot frame."; ui_min = 0; ui_max = CHECKPOINT_FRAME_SMOOTHING; ui_step = 1; ui_category = CAT; > = 0;
    #define UNIQ_UI_SMOOTH_SEL(B, N) UI_B##B##_C##N##_SMOOTH
#else
    #define UNIQ_UI_DECL_SMOOTH(B, N, CAT)
    #define UNIQ_UI_SMOOTH_SEL(B, N) 0
#endif

#if UNIQ_UI_CONDITIONS >= 2
    #define UNIQ_UI_DECL_NEED(B, CAT) \
        uniform int UI_B##B##_NEED < ui_type = "slider"; ui_label = "Conditions To Match"; ui_tooltip = \
            "Number of conditions to match TRUE value.\n" \
            "Conditions that are not enabled (OFF) count as FALSE."; ui_min = 1; ui_max = UNIQ_UI_CONDITIONS; ui_step = 1; ui_category = CAT; > = 1;
    #define UNIQ_UI_NEED(B) UI_B##B##_NEED
#else
    #define UNIQ_UI_DECL_NEED(B, CAT)
    #define UNIQ_UI_NEED(B) 1
#endif

#define UNIQ_UI_SKIP_ALL  1
#define UNIQ_UI_SKIP_BASE "None\0All\0"
#if UNIQ_UI_BOX_COUNT >= 15
    #define UNIQ_UI_T15 "To Box 15\0"
#else
    #define UNIQ_UI_T15
#endif
#if UNIQ_UI_BOX_COUNT >= 14
    #define UNIQ_UI_T14 "To Box 14\0" UNIQ_UI_T15
#else
    #define UNIQ_UI_T14 UNIQ_UI_T15
#endif
#if UNIQ_UI_BOX_COUNT >= 13
    #define UNIQ_UI_T13 "To Box 13\0" UNIQ_UI_T14
#else
    #define UNIQ_UI_T13 UNIQ_UI_T14
#endif
#if UNIQ_UI_BOX_COUNT >= 12
    #define UNIQ_UI_T12 "To Box 12\0" UNIQ_UI_T13
#else
    #define UNIQ_UI_T12 UNIQ_UI_T13
#endif
#if UNIQ_UI_BOX_COUNT >= 11
    #define UNIQ_UI_T11 "To Box 11\0" UNIQ_UI_T12
#else
    #define UNIQ_UI_T11 UNIQ_UI_T12
#endif
#if UNIQ_UI_BOX_COUNT >= 10
    #define UNIQ_UI_T10 "To Box 10\0" UNIQ_UI_T11
#else
    #define UNIQ_UI_T10 UNIQ_UI_T11
#endif
#if UNIQ_UI_BOX_COUNT >= 9
    #define UNIQ_UI_T9 "To Box 9\0" UNIQ_UI_T10
#else
    #define UNIQ_UI_T9 UNIQ_UI_T10
#endif
#if UNIQ_UI_BOX_COUNT >= 8
    #define UNIQ_UI_T8 "To Box 8\0" UNIQ_UI_T9
#else
    #define UNIQ_UI_T8 UNIQ_UI_T9
#endif
#if UNIQ_UI_BOX_COUNT >= 7
    #define UNIQ_UI_T7 "To Box 7\0" UNIQ_UI_T8
#else
    #define UNIQ_UI_T7 UNIQ_UI_T8
#endif
#if UNIQ_UI_BOX_COUNT >= 6
    #define UNIQ_UI_T6 "To Box 6\0" UNIQ_UI_T7
#else
    #define UNIQ_UI_T6 UNIQ_UI_T7
#endif
#if UNIQ_UI_BOX_COUNT >= 5
    #define UNIQ_UI_T5 "To Box 5\0" UNIQ_UI_T6
#else
    #define UNIQ_UI_T5 UNIQ_UI_T6
#endif
#if UNIQ_UI_BOX_COUNT >= 4
    #define UNIQ_UI_T4 "To Box 4\0" UNIQ_UI_T5
#else
    #define UNIQ_UI_T4 UNIQ_UI_T5
#endif
#if UNIQ_UI_BOX_COUNT >= 3
    #define UNIQ_UI_T3 "To Box 3\0" UNIQ_UI_T4
#else
    #define UNIQ_UI_T3 UNIQ_UI_T4
#endif
#define UNIQ_UI_SKIP_ITEMS_1 UNIQ_UI_SKIP_BASE UNIQ_UI_T3
#define UNIQ_UI_SKIP_ITEMS_2 UNIQ_UI_SKIP_BASE UNIQ_UI_T4
#define UNIQ_UI_SKIP_ITEMS_3 UNIQ_UI_SKIP_BASE UNIQ_UI_T5
#define UNIQ_UI_SKIP_ITEMS_4 UNIQ_UI_SKIP_BASE UNIQ_UI_T6
#define UNIQ_UI_SKIP_ITEMS_5 UNIQ_UI_SKIP_BASE UNIQ_UI_T7
#define UNIQ_UI_SKIP_ITEMS_6 UNIQ_UI_SKIP_BASE UNIQ_UI_T8
#define UNIQ_UI_SKIP_ITEMS_7 UNIQ_UI_SKIP_BASE UNIQ_UI_T9
#define UNIQ_UI_SKIP_ITEMS_8 UNIQ_UI_SKIP_BASE UNIQ_UI_T10
#define UNIQ_UI_SKIP_ITEMS_9 UNIQ_UI_SKIP_BASE UNIQ_UI_T11
#define UNIQ_UI_SKIP_ITEMS_10 UNIQ_UI_SKIP_BASE UNIQ_UI_T12
#define UNIQ_UI_SKIP_ITEMS_11 UNIQ_UI_SKIP_BASE UNIQ_UI_T13
#define UNIQ_UI_SKIP_ITEMS_12 UNIQ_UI_SKIP_BASE UNIQ_UI_T14
#define UNIQ_UI_SKIP_ITEMS_13 UNIQ_UI_SKIP_BASE UNIQ_UI_T15
#define UNIQ_UI_SKIP_ITEMS_14 UNIQ_UI_SKIP_BASE
#define UNIQ_UI_SKIP_TIP \
    "If this box is displayed, skip processing of next boxes based on selection.\n" \
    "None: do not skip & process all.\n" \
    "All: skip every later box.\n" \
    "To Box N: jump to box N. Boxes between this one and N are skipped. N is processed."
#define UNIQ_UI_MAKE_SKIP(B, CAT) \
    uniform int UI_B##B##_SKIP < ui_type = "combo"; ui_label = "If Displayed Skip Boxes"; ui_items = UNIQ_UI_SKIP_ITEMS_##B; ui_tooltip = UNIQ_UI_SKIP_TIP; ui_category = CAT; > = 0;
#if UNIQ_UI_BOX_COUNT > 1
    #define UNIQ_UI_SKIP_UNIFORM_1(CAT) UNIQ_UI_MAKE_SKIP(1, CAT)
    #define UNIQ_UI_SKIP_SEL_1 UI_B1_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_1(CAT)
    #define UNIQ_UI_SKIP_SEL_1 0
#endif
#if UNIQ_UI_BOX_COUNT > 2
    #define UNIQ_UI_SKIP_UNIFORM_2(CAT) UNIQ_UI_MAKE_SKIP(2, CAT)
    #define UNIQ_UI_SKIP_SEL_2 UI_B2_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_2(CAT)
    #define UNIQ_UI_SKIP_SEL_2 0
#endif
#if UNIQ_UI_BOX_COUNT > 3
    #define UNIQ_UI_SKIP_UNIFORM_3(CAT) UNIQ_UI_MAKE_SKIP(3, CAT)
    #define UNIQ_UI_SKIP_SEL_3 UI_B3_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_3(CAT)
    #define UNIQ_UI_SKIP_SEL_3 0
#endif
#if UNIQ_UI_BOX_COUNT > 4
    #define UNIQ_UI_SKIP_UNIFORM_4(CAT) UNIQ_UI_MAKE_SKIP(4, CAT)
    #define UNIQ_UI_SKIP_SEL_4 UI_B4_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_4(CAT)
    #define UNIQ_UI_SKIP_SEL_4 0
#endif
#if UNIQ_UI_BOX_COUNT > 5
    #define UNIQ_UI_SKIP_UNIFORM_5(CAT) UNIQ_UI_MAKE_SKIP(5, CAT)
    #define UNIQ_UI_SKIP_SEL_5 UI_B5_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_5(CAT)
    #define UNIQ_UI_SKIP_SEL_5 0
#endif
#if UNIQ_UI_BOX_COUNT > 6
    #define UNIQ_UI_SKIP_UNIFORM_6(CAT) UNIQ_UI_MAKE_SKIP(6, CAT)
    #define UNIQ_UI_SKIP_SEL_6 UI_B6_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_6(CAT)
    #define UNIQ_UI_SKIP_SEL_6 0
#endif
#if UNIQ_UI_BOX_COUNT > 7
    #define UNIQ_UI_SKIP_UNIFORM_7(CAT) UNIQ_UI_MAKE_SKIP(7, CAT)
    #define UNIQ_UI_SKIP_SEL_7 UI_B7_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_7(CAT)
    #define UNIQ_UI_SKIP_SEL_7 0
#endif
#if UNIQ_UI_BOX_COUNT > 8
    #define UNIQ_UI_SKIP_UNIFORM_8(CAT) UNIQ_UI_MAKE_SKIP(8, CAT)
    #define UNIQ_UI_SKIP_SEL_8 UI_B8_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_8(CAT)
    #define UNIQ_UI_SKIP_SEL_8 0
#endif
#if UNIQ_UI_BOX_COUNT > 9
    #define UNIQ_UI_SKIP_UNIFORM_9(CAT) UNIQ_UI_MAKE_SKIP(9, CAT)
    #define UNIQ_UI_SKIP_SEL_9 UI_B9_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_9(CAT)
    #define UNIQ_UI_SKIP_SEL_9 0
#endif
#if UNIQ_UI_BOX_COUNT > 10
    #define UNIQ_UI_SKIP_UNIFORM_10(CAT) UNIQ_UI_MAKE_SKIP(10, CAT)
    #define UNIQ_UI_SKIP_SEL_10 UI_B10_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_10(CAT)
    #define UNIQ_UI_SKIP_SEL_10 0
#endif
#if UNIQ_UI_BOX_COUNT > 11
    #define UNIQ_UI_SKIP_UNIFORM_11(CAT) UNIQ_UI_MAKE_SKIP(11, CAT)
    #define UNIQ_UI_SKIP_SEL_11 UI_B11_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_11(CAT)
    #define UNIQ_UI_SKIP_SEL_11 0
#endif
#if UNIQ_UI_BOX_COUNT > 12
    #define UNIQ_UI_SKIP_UNIFORM_12(CAT) UNIQ_UI_MAKE_SKIP(12, CAT)
    #define UNIQ_UI_SKIP_SEL_12 UI_B12_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_12(CAT)
    #define UNIQ_UI_SKIP_SEL_12 0
#endif
#if UNIQ_UI_BOX_COUNT > 13
    #define UNIQ_UI_SKIP_UNIFORM_13(CAT) UNIQ_UI_MAKE_SKIP(13, CAT)
    #define UNIQ_UI_SKIP_SEL_13 UI_B13_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_13(CAT)
    #define UNIQ_UI_SKIP_SEL_13 0
#endif
#if UNIQ_UI_BOX_COUNT > 14
    #define UNIQ_UI_SKIP_UNIFORM_14(CAT) UNIQ_UI_MAKE_SKIP(14, CAT)
    #define UNIQ_UI_SKIP_SEL_14 UI_B14_SKIP
#else
    #define UNIQ_UI_SKIP_UNIFORM_14(CAT)
    #define UNIQ_UI_SKIP_SEL_14 0
#endif
#if UNIQ_UI_BOX_COUNT >= 15
    #define UNIQ_UI_SKIP_UNIFORM_15(CAT)
    #define UNIQ_UI_SKIP_SEL_15 0
#endif
#define UNIQ_UI_SKIP_SEL(B) UNIQ_UI_SKIP_SEL_##B

#define UNIQ_UI_RECT(B) float4(UI_B##B##_X1, UI_B##B##_Y1, UI_B##B##_X2, UI_B##B##_Y2)
#define UNIQ_UI_BOX_I(B) ((B) - 1)

#define UNIQ_UI_DECL_BOX(B, CAT, MASKFILE) \
    uniform bool UI_B##B##_ON < ui_label = "Enable"; ui_tooltip = "Enables processing of this box."; ui_category = CAT; ui_category_closed = true; > = true; \
    uniform bool UI_B##B##_FS < ui_label = "Is Fullscreen"; ui_tooltip = "Treat this box as fullscreen overlay."; ui_category = CAT; > = false; \
    UNIQ_UI_SKIP_UNIFORM_##B(CAT) \
    uniform float UI_B##B##_X1 < ui_type = "drag"; ui_label = "Box X1 (px)"; ui_tooltip = \
        "Inclusive corner X position. Copy X from the sampling box.\n" \
        "Either corner order is OK. Clamped to UNIQ_UI_RES_WIDTH."; ui_min = 0.0; ui_max = UNIQ_UI_RES_WIDTH; ui_step = 1.0; ui_category = CAT; > = 0.0; \
    uniform float UI_B##B##_Y1 < ui_type = "drag"; ui_label = "Box Y1 (px)"; ui_tooltip = \
        "Inclusive corner Y position. Copy Y from the sampling box.\n" \
        "Either corner order is OK. Clamped to UNIQ_UI_RES_HEIGHT."; ui_min = 0.0; ui_max = UNIQ_UI_RES_HEIGHT; ui_step = 1.0; ui_category = CAT; > = 0.0; \
    uniform float UI_B##B##_X2 < ui_type = "drag"; ui_label = "Box X2 (px)"; ui_tooltip = \
        "Opposite inclusive corner X position. Copy X from the sampling box.\n" \
        "Either corner order is OK. Clamped to UNIQ_UI_RES_WIDTH."; ui_min = 0.0; ui_max = UNIQ_UI_RES_WIDTH; ui_step = 1.0; ui_category = CAT; > = 99.0; \
    uniform float UI_B##B##_Y2 < ui_type = "drag"; ui_label = "Box Y2 (px)"; ui_tooltip = \
        "Opposite inclusive corner Y position. Copy Y from the sampling box.\n" \
        "Either corner order is OK. Clamped to UNIQ_UI_RES_HEIGHT."; ui_min = 0.0; ui_max = UNIQ_UI_RES_HEIGHT; ui_step = 1.0; ui_category = CAT; > = 99.0; \
    uniform bool UI_B##B##_MASK_ON < ui_label = "Mask Texture"; ui_tooltip = \
        "When on, reads reshade-shaders/Textures/" MASKFILE "\n" \
        "and draws inside the box as mask.\n" \
        "White = UI, black = not UI. Any PNG size is mapped to the box size.\n" \
        "If the file is missing, the mask is full black (no UI)."; ui_category = CAT; ui_spacing = 3; > = false; \
    texture UNIQ_UI_MaskTex##B < source = MASKFILE; > { Width = UNIQ_UI_RES_WIDTH; Height = UNIQ_UI_RES_HEIGHT; Format = R8; }; \
    sampler UNIQ_UI_MaskSamp##B { Texture = UNIQ_UI_MaskTex##B; MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = LINEAR; AddressU = CLAMP; AddressV = CLAMP; }; \
    UNIQ_UI_DECL_STORE(B, CAT) \
    UNIQ_UI_DECL_NEED(B, CAT) \
    uniform bool UI_B##B##_FEATHER_ON < ui_label = "Override Global Feather"; ui_tooltip = \
        "Overrides global feather settings (Restore tab) and uses selected value instead."; ui_category = CAT; > = false; \
    uniform float UI_B##B##_FEATHER < ui_type = "drag"; ui_label = "Box Feather (px)"; ui_tooltip = \
        "Soft falloff around this box, in pixels."; ui_min = 0.0; ui_max = 200.0; ui_category = CAT; > = 30.0;

#define UNIQ_UI_DECL_COND(B, N, CAT, TITLE, DEF_ON) \
    uniform bool UI_B##B##_C##N##_ON < ui_text = TITLE; ui_label = "Enable"; ui_tooltip = "Turn this condition ON or OFF. OFF counts as FALSE."; ui_category = CAT; ui_spacing = 3; > = DEF_ON; \
    uniform bool UI_B##B##_C##N##_INV < ui_label = "Invert"; ui_category = CAT; > = false; \
    UNIQ_UI_DECL_SAMP(B, N, CAT) \
    UNIQ_UI_DECL_SMOOTH(B, N, CAT) \
    uniform float UI_B##B##_C##N##_PROBE_X < ui_type = "drag"; ui_label = "Sample X (px)"; ui_tooltip = \
        "Pixel X position to sample color & depth. Copy X value from the sampling box."; ui_min = 0.0; ui_max = UNIQ_UI_RES_WIDTH; ui_step = 1.0; ui_category = CAT; > = 0.0; \
    uniform float UI_B##B##_C##N##_PROBE_Y < ui_type = "drag"; ui_label = "Sample Y (px)"; ui_tooltip = \
        "Pixel Y position to sample color & depth. Copy Y value from the sampling box."; ui_min = 0.0; ui_max = UNIQ_UI_RES_HEIGHT; ui_step = 1.0; ui_category = CAT; > = 0.0; \
    uniform float3 UI_B##B##_C##N##_COLOR < ui_type = "color"; ui_label = "Match Color"; ui_tooltip = \
        "Color to match within this condition.\n" \
        "Copy RGB values from the sampling box into this widget.\n" \
        "For Transparent UI mode sample UI element with WHITE background behind."; ui_category = CAT; > = float3(1.0, 1.0, 1.0); \
    uniform float3 UI_B##B##_C##N##_COLOR_BLACK < ui_type = "color"; ui_label = "Transparent UI Match Color (Black BG)"; ui_tooltip = \
        "======= EXPERIMENTAL =======\n" \
        "For Transparent UI mode ONLY.\n" \
        "Sample the same UI element as for normal color but now with BLACK background behind.\n" \
        "Copy RGB values from the sampling box into this widget."; ui_category = CAT; > = float3(0.0, 0.0, 0.0); \
    uniform int UI_B##B##_C##N##_SHADE < ui_type = "combo"; ui_label = "Color Match"; ui_items = UNIQ_UI_SHADE_ITEMS; ui_tooltip = \
        "Exact RGB: red, green and blue channels must be a close match.\n" \
        "Any Brightness (Same Color): matches same color, that can be darker or lighter.\n" \
        "Hue Only: matches only hue of the color.\n" \
        "Transparent UI (EXPERIMENTAL):\n" \
        "- matches mixed color of transparent UI on some background.\n" \
        "- this requires to setup TWO samples over WHITE and BLACK background behind UI.\n" \
        "Color matching can be skipped when confidence is set to 0."; ui_category = CAT; > = 0; \
    uniform float UI_B##B##_C##N##_CONF < __UNIFORM_SLIDER_FLOAT1 ui_min = 0.0; ui_max = 1.0; ui_label = "Color Confidence"; ui_tooltip = \
        "How similar the sampled color must be (1 = exact).\n" \
        "0 = SKIP color matching and output TRUE."; ui_category = CAT; > = 0.0; \
    uniform int UI_B##B##_C##N##_DMODE < ui_type = "combo"; ui_label = "Depth Match"; ui_items = UNIQ_UI_DEPTH_ITEMS; ui_tooltip = \
        "Uses linearized ReShade depth [0-1] at the sample.\n" \
        "Exact: sampled depth must be within 0.01 of depth threshold.\n" \
        "Greater Than or Equal: sampled depth >= threshold.\n" \
        "Less Than or Equal: sampled depth <= threshold.\n" \
        "Depth matching can be skipped when threshold is set to 0."; ui_category = CAT; > = UNIQ_UI_DEPTH_EXACT; \
    uniform float UI_B##B##_C##N##_DEPTH < __UNIFORM_SLIDER_FLOAT1 ui_min = 0.0; ui_max = 1.0; ui_label = "Depth Threshold"; ui_tooltip = \
        "Threshold for depth value comparison.\n" \
        "0 = SKIP depth matching and output TRUE."; ui_step = 0.001; ui_category = CAT; > = 0.0;

#define UNIQ_UI_DECL_COND1(B, CAT) UNIQ_UI_DECL_COND(B, 1, CAT, "Condition 1", true)
#define UNIQ_UI_CUSE1(B) (UI_B##B##_C1_ON ? 1 : -1)
#define UNIQ_UI_CPROBE1(B) float2(UI_B##B##_C1_PROBE_X, UI_B##B##_C1_PROBE_Y)
#define UNIQ_UI_CSAMP1(B) UNIQ_UI_SAMP_SEL(B, 1)

#if UNIQ_UI_CONDITIONS >= 2
    #define UNIQ_UI_DECL_COND2(B, CAT) UNIQ_UI_DECL_COND(B, 2, CAT, "Condition 2", false)
    #define UNIQ_UI_CUSE2(B) (UI_B##B##_C2_ON ? 1 : -1)
    #define UNIQ_UI_CPROBE2(B) float2(UI_B##B##_C2_PROBE_X, UI_B##B##_C2_PROBE_Y)
    #define UNIQ_UI_CSAMP2(B) UNIQ_UI_SAMP_SEL(B, 2)
#else
    #define UNIQ_UI_DECL_COND2(B, CAT)
    #define UNIQ_UI_CUSE2(B) -1
    #define UNIQ_UI_CPROBE2(B) float2(0.0, 0.0)
    #define UNIQ_UI_CSAMP2(B) 0
#endif
#if UNIQ_UI_CONDITIONS >= 3
    #define UNIQ_UI_DECL_COND3(B, CAT) UNIQ_UI_DECL_COND(B, 3, CAT, "Condition 3", false)
    #define UNIQ_UI_CUSE3(B) (UI_B##B##_C3_ON ? 1 : -1)
    #define UNIQ_UI_CPROBE3(B) float2(UI_B##B##_C3_PROBE_X, UI_B##B##_C3_PROBE_Y)
    #define UNIQ_UI_CSAMP3(B) UNIQ_UI_SAMP_SEL(B, 3)
#else
    #define UNIQ_UI_DECL_COND3(B, CAT)
    #define UNIQ_UI_CUSE3(B) -1
    #define UNIQ_UI_CPROBE3(B) float2(0.0, 0.0)
    #define UNIQ_UI_CSAMP3(B) 0
#endif
#if UNIQ_UI_CONDITIONS >= 4
    #define UNIQ_UI_DECL_COND4(B, CAT) UNIQ_UI_DECL_COND(B, 4, CAT, "Condition 4", false)
    #define UNIQ_UI_CUSE4(B) (UI_B##B##_C4_ON ? 1 : -1)
    #define UNIQ_UI_CPROBE4(B) float2(UI_B##B##_C4_PROBE_X, UI_B##B##_C4_PROBE_Y)
    #define UNIQ_UI_CSAMP4(B) UNIQ_UI_SAMP_SEL(B, 4)
#else
    #define UNIQ_UI_DECL_COND4(B, CAT)
    #define UNIQ_UI_CUSE4(B) -1
    #define UNIQ_UI_CPROBE4(B) float2(0.0, 0.0)
    #define UNIQ_UI_CSAMP4(B) 0
#endif
#if UNIQ_UI_CONDITIONS >= 5
    #define UNIQ_UI_DECL_COND5(B, CAT) UNIQ_UI_DECL_COND(B, 5, CAT, "Condition 5", false)
    #define UNIQ_UI_CUSE5(B) (UI_B##B##_C5_ON ? 1 : -1)
    #define UNIQ_UI_CPROBE5(B) float2(UI_B##B##_C5_PROBE_X, UI_B##B##_C5_PROBE_Y)
    #define UNIQ_UI_CSAMP5(B) UNIQ_UI_SAMP_SEL(B, 5)
#else
    #define UNIQ_UI_DECL_COND5(B, CAT)
    #define UNIQ_UI_CUSE5(B) -1
    #define UNIQ_UI_CPROBE5(B) float2(0.0, 0.0)
    #define UNIQ_UI_CSAMP5(B) 0
#endif

#define UNIQ_UI_DECL_FULL(B, CAT, MASKFILE) \
    UNIQ_UI_DECL_BOX(B, CAT, MASKFILE) \
    UNIQ_UI_DECL_COND1(B, CAT) \
    UNIQ_UI_DECL_COND2(B, CAT) \
    UNIQ_UI_DECL_COND3(B, CAT) \
    UNIQ_UI_DECL_COND4(B, CAT) \
    UNIQ_UI_DECL_COND5(B, CAT)

#define UNIQ_UI_TEX_COV(B, UV, ER) ufx_mask_cov(UNIQ_UI_MaskSamp##B, (UV), (ER))
#define UNIQ_UI_TEX_INSIDE(B, UV, ER) ufx_mask_inside(UNIQ_UI_MaskSamp##B, (UV), (ER))

#define UNIQ_UI_BOX_COV_BEGIN(B, COND) \
    [branch] \
    if(COND) \
    { \
        boxst = ufx_eval_box(UNIQ_UI_BOX_I(B)); \
        [branch] \
        if(boxst.y < 0.5 && boxst.x > 0.5) \
        { \
            er = ufx_effective_rect(UNIQ_UI_RECT(B), UI_B##B##_FS); \
            ft = ufx_feather(UI_B##B##_FEATHER_ON, UI_B##B##_FEATHER); \
            cov = ufx_box_cov(uv, er, ft);

#define UNIQ_UI_BOX_APPLY_MASK(B) \
            [branch] \
            if(cov > 0.0) \
            { \
                [branch] \
                if(UI_B##B##_MASK_ON) \
                    cov *= UNIQ_UI_TEX_COV(B, uv, er);

#define UNIQ_UI_BOX_COV_END \
            } \
        } \
    }

#define UNIQ_UI_RESTORE(B) \
    UNIQ_UI_BOX_COV_BEGIN(B, UI_B##B##_ON) \
            cov *= UI_STRENGTH; \
    UNIQ_UI_BOX_APPLY_MASK(B) \
                if(cov > 0.0) \
                    o = lerp(o, ufx_store(uv, UNIQ_UI_STORE_SEL(B)), cov); \
    UNIQ_UI_BOX_COV_END

#define UNIQ_UI_MASK_ADD(B) \
    UNIQ_UI_BOX_COV_BEGIN(B, UI_B##B##_ON) \
    UNIQ_UI_BOX_APPLY_MASK(B) \
                m = max(m, cov); \
    UNIQ_UI_BOX_COV_END

#define UNIQ_UI_MASK_CKPT_ADD(B) \
    UNIQ_UI_BOX_COV_BEGIN(B, UI_B##B##_ON && (UNIQ_UI_STORE_SEL(B) == ckpt)) \
    UNIQ_UI_BOX_APPLY_MASK(B) \
                m = max(m, cov); \
    UNIQ_UI_BOX_COV_END

#if ENABLE_SETUP_MODE
#define UNIQ_UI_SETUP(B) \
    [branch] \
    if(UI_SHOW_B##B) \
    { \
        float uniq_tcov = 0.0; \
        float4 uniq_er = ufx_effective_rect(UNIQ_UI_RECT(B), UI_B##B##_FS); \
        float4 uniq_st = ufx_eval_box(UNIQ_UI_BOX_I(B)); \
        [branch] \
        if(UI_B##B##_MASK_ON) \
            uniq_tcov = UNIQ_UI_TEX_INSIDE(B, uv, uniq_er); \
        o = ufx_setup_tint(uv, uniq_er, UI_B##B##_ON, uniq_st.x, ufx_feather(UI_B##B##_FEATHER_ON, UI_B##B##_FEATHER), \
            UNIQ_UI_BOX_I(B), UNIQ_UI_STORE_SEL(B), UI_B##B##_MASK_ON, uniq_tcov, uniq_st.y, o); \
    }

#if UNIQ_UI_CONDITIONS >= 2
    #define UNIQ_UI_MARK_C2(B) , UNIQ_UI_CUSE2(B), UNIQ_UI_CPROBE2(B)
    #define UNIQ_UI_PROBE_C2(B) , UNIQ_UI_CUSE2(B), UNIQ_UI_CPROBE2(B), UNIQ_UI_CSAMP2(B)
#else
    #define UNIQ_UI_MARK_C2(B)
    #define UNIQ_UI_PROBE_C2(B)
#endif
#if UNIQ_UI_CONDITIONS >= 3
    #define UNIQ_UI_MARK_C3(B) , UNIQ_UI_CUSE3(B), UNIQ_UI_CPROBE3(B)
    #define UNIQ_UI_PROBE_C3(B) , UNIQ_UI_CUSE3(B), UNIQ_UI_CPROBE3(B), UNIQ_UI_CSAMP3(B)
#else
    #define UNIQ_UI_MARK_C3(B)
    #define UNIQ_UI_PROBE_C3(B)
#endif
#if UNIQ_UI_CONDITIONS >= 4
    #define UNIQ_UI_MARK_C4(B) , UNIQ_UI_CUSE4(B), UNIQ_UI_CPROBE4(B)
    #define UNIQ_UI_PROBE_C4(B) , UNIQ_UI_CUSE4(B), UNIQ_UI_CPROBE4(B), UNIQ_UI_CSAMP4(B)
#else
    #define UNIQ_UI_MARK_C4(B)
    #define UNIQ_UI_PROBE_C4(B)
#endif
#if UNIQ_UI_CONDITIONS >= 5
    #define UNIQ_UI_MARK_C5(B) , UNIQ_UI_CUSE5(B), UNIQ_UI_CPROBE5(B)
    #define UNIQ_UI_PROBE_C5(B) , UNIQ_UI_CUSE5(B), UNIQ_UI_CPROBE5(B), UNIQ_UI_CSAMP5(B)
#else
    #define UNIQ_UI_MARK_C5(B)
    #define UNIQ_UI_PROBE_C5(B)
#endif

#define UNIQ_UI_SETUP_MARKS(B) \
    [branch] \
    if(UI_SHOW_B##B) \
    { \
        o = ufx_setup_marks(uv, UNIQ_UI_RECT(B), UI_B##B##_FS, \
            UNIQ_UI_CUSE1(B), UNIQ_UI_CPROBE1(B) \
            UNIQ_UI_MARK_C2(B) \
            UNIQ_UI_MARK_C3(B) \
            UNIQ_UI_MARK_C4(B) \
            UNIQ_UI_MARK_C5(B), o); \
    }

#define UNIQ_UI_SETUP_PROBES(B) \
    [branch] \
    if(UI_SHOW_B##B) \
    { \
        o = ufx_setup_probes(uv, UNIQ_UI_RECT(B), UI_B##B##_FS, \
            UNIQ_UI_CUSE1(B), UNIQ_UI_CPROBE1(B), UNIQ_UI_CSAMP1(B) \
            UNIQ_UI_PROBE_C2(B) \
            UNIQ_UI_PROBE_C3(B) \
            UNIQ_UI_PROBE_C4(B) \
            UNIQ_UI_PROBE_C5(B), \
            UNIQ_UI_BOX_I(B), o); \
    }

#define UNIQ_UI_SETUP_LAYERS(EACH) \
    EACH(UNIQ_UI_SETUP) \
    EACH(UNIQ_UI_SETUP_MARKS) \
    EACH(UNIQ_UI_SETUP_PROBES)
#endif

#define UNIQ_UI_PACK_PAIR(B, N) \
    ufx_cond_pair(UI_B##B##_C##N##_ON, UNIQ_UI_RECT(B), UI_B##B##_FS, UI_B##B##_MASK_ON, UI_B##B##_C##N##_INV, UNIQ_UI_CPROBE##N(B), UI_B##B##_C##N##_COLOR, UI_B##B##_C##N##_COLOR_BLACK, UI_B##B##_C##N##_SHADE, UI_B##B##_C##N##_CONF, UI_B##B##_C##N##_DEPTH, UI_B##B##_C##N##_DMODE, UNIQ_UI_SAMP_SEL(B, N), UNIQ_UI_SMOOTH_SEL(B, N))

#if UNIQ_UI_CONDITIONS >= 2
    #define UNIQ_UI_PACK_C2(B) \
        else if(c == 1) \
            r = UNIQ_UI_PACK_PAIR(B, 2);
#else
    #define UNIQ_UI_PACK_C2(B)
#endif
#if UNIQ_UI_CONDITIONS >= 3
    #define UNIQ_UI_PACK_C3(B) \
        else if(c == 2) \
            r = UNIQ_UI_PACK_PAIR(B, 3);
#else
    #define UNIQ_UI_PACK_C3(B)
#endif
#if UNIQ_UI_CONDITIONS >= 4
    #define UNIQ_UI_PACK_C4(B) \
        else if(c == 3) \
            r = UNIQ_UI_PACK_PAIR(B, 4);
#else
    #define UNIQ_UI_PACK_C4(B)
#endif
#if UNIQ_UI_CONDITIONS >= 5
    #define UNIQ_UI_PACK_C5(B) \
        else if(c == 4) \
            r = UNIQ_UI_PACK_PAIR(B, 5);
#else
    #define UNIQ_UI_PACK_C5(B)
#endif

#define UNIQ_UI_FN_PACK(B) \
float4 ufx_pack_box##B(int c) \
{ \
    float4 r = float4(-1.0, 0.0, 0.0, 0.0); \
    [branch] \
    if(UI_B##B##_ON) \
    { \
        if(c == 0) \
            r = UNIQ_UI_PACK_PAIR(B, 1); \
        UNIQ_UI_PACK_C2(B) \
        UNIQ_UI_PACK_C3(B) \
        UNIQ_UI_PACK_C4(B) \
        UNIQ_UI_PACK_C5(B) \
    } \
    return r; \
}

#define UNIQ_UI_EVAL_CASE(B) \
    else if(b == UNIQ_UI_BOX_I(B)) \
        r = ufx_pack_box##B(c);

#define UNIQ_UI_NEED_CASE(B) \
    else if(b == UNIQ_UI_BOX_I(B)) \
        n = UNIQ_UI_NEED(B);

#define UNIQ_UI_SKIP_STEP(B) UNIQ_UI_SKIP_ACCUM(UNIQ_UI_BOX_I(B), B)

#if ENABLE_DEBUG_STATS
#define UNIQ_UI_STATS_LOAD(B) \
    box = UNIQ_UI_BOX_I(B); \
    enable = UI_B##B##_ON; \
    fs = UI_B##B##_FS; \
    skip_mode = UNIQ_UI_SKIP_SEL(B); \
    mask_on = UI_B##B##_MASK_ON; \
    rect = UNIQ_UI_RECT(B); \
    need = UNIQ_UI_NEED(B); \
    ckpt = UNIQ_UI_STORE_SEL(B); \
    col_t = float4(UI_B##B##_C1_CONF, UNIQ_UI_CONF2(B), UNIQ_UI_CONF3(B), UNIQ_UI_CONF4(B)); \
    dep_t = float4(UI_B##B##_C1_DEPTH, UNIQ_UI_DEPTH2(B), UNIQ_UI_DEPTH3(B), UNIQ_UI_DEPTH4(B)); \
    dmode_t = float4((float)UI_B##B##_C1_DMODE, UNIQ_UI_DMODE2(B), UNIQ_UI_DMODE3(B), UNIQ_UI_DMODE4(B)); \
    invt = float4(UI_B##B##_C1_INV ? 1.0 : 0.0, UNIQ_UI_INV2(B), UNIQ_UI_INV3(B), UNIQ_UI_INV4(B)); \
    cond_use = float4((float)UNIQ_UI_CUSE1(B), (float)UNIQ_UI_CUSE2(B), (float)UNIQ_UI_CUSE3(B), (float)UNIQ_UI_CUSE4(B)); \
    c5_conf = UNIQ_UI_CONF5(B); \
    c5_dep = UNIQ_UI_DEPTH5(B); \
    c5_dmode = UNIQ_UI_DMODE5(B); \
    c5_inv = UNIQ_UI_INV5(B); \
    c5_use = (float)UNIQ_UI_CUSE5(B); \
    hit = true

#define UNIQ_UI_STATS_CASE(B) \
    else if(bid == UNIQ_UI_BOX_I(B)) \
    { \
        UNIQ_UI_STATS_LOAD(B); \
    }

#define UNIQ_UI_STATS_APPLY \
    if(hit) \
        o = ufx_stats_block(uv, o, p0, box, enable, fs, skip_mode, mask_on, rect, need, ckpt, col_t, dep_t, dmode_t, invt, cond_use, c5_conf, c5_dep, c5_dmode, c5_inv, c5_use, scroll);

#define UNIQ_UI_STATS_HEAD \
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0)); \
    float3 o = processed.rgb; \
    float2 px = uv * BUFFER_SCREEN_SIZE; \
    float2 p0 = ufx_stats_origin_px(); \
    float2 p1 = p0 + float2(UNIQ_UI_STATS_W, ufx_stats_view_h()); \
    float scroll = 0.0; \
    float block_h = (float)UNIQ_UI_STATS_LINES * UNIQ_UI_STATS_ROW; \
    float c5_conf = 0.0; \
    float c5_dep = 0.0; \
    float c5_dmode = 0.0; \
    float c5_inv = 0.0; \
    float c5_use = 0.0; \
    int bid = 0; \
    int box = 0; \
    int need = 1; \
    int ckpt = 0; \
    bool hit = false; \
    bool enable = false; \
    bool fs = false; \
    int skip_mode = 0; \
    bool mask_on = false; \
    float4 rect = float4(0.0, 0.0, 0.0, 0.0); \
    float4 col_t = float4(0.0, 0.0, 0.0, 0.0); \
    float4 dep_t = float4(0.0, 0.0, 0.0, 0.0); \
    float4 dmode_t = float4(0.0, 0.0, 0.0, 0.0); \
    float4 invt = float4(0.0, 0.0, 0.0, 0.0); \
    float4 cond_use = float4(0.0, 0.0, 0.0, 0.0);
#if UNIQ_UI_CONDITIONS >= 2
    #define UNIQ_UI_CONF2(B) UI_B##B##_C2_CONF
    #define UNIQ_UI_DEPTH2(B) UI_B##B##_C2_DEPTH
    #define UNIQ_UI_DMODE2(B) (float)UI_B##B##_C2_DMODE
    #define UNIQ_UI_INV2(B) (UI_B##B##_C2_INV ? 1.0 : 0.0)
#else
    #define UNIQ_UI_CONF2(B) 0.0
    #define UNIQ_UI_DEPTH2(B) 0.0
    #define UNIQ_UI_DMODE2(B) (float)UNIQ_UI_DEPTH_GE
    #define UNIQ_UI_INV2(B) 0.0
#endif
#if UNIQ_UI_CONDITIONS >= 3
    #define UNIQ_UI_CONF3(B) UI_B##B##_C3_CONF
    #define UNIQ_UI_DEPTH3(B) UI_B##B##_C3_DEPTH
    #define UNIQ_UI_DMODE3(B) (float)UI_B##B##_C3_DMODE
    #define UNIQ_UI_INV3(B) (UI_B##B##_C3_INV ? 1.0 : 0.0)
#else
    #define UNIQ_UI_CONF3(B) 0.0
    #define UNIQ_UI_DEPTH3(B) 0.0
    #define UNIQ_UI_DMODE3(B) (float)UNIQ_UI_DEPTH_GE
    #define UNIQ_UI_INV3(B) 0.0
#endif
#if UNIQ_UI_CONDITIONS >= 4
    #define UNIQ_UI_CONF4(B) UI_B##B##_C4_CONF
    #define UNIQ_UI_DEPTH4(B) UI_B##B##_C4_DEPTH
    #define UNIQ_UI_DMODE4(B) (float)UI_B##B##_C4_DMODE
    #define UNIQ_UI_INV4(B) (UI_B##B##_C4_INV ? 1.0 : 0.0)
#else
    #define UNIQ_UI_CONF4(B) 0.0
    #define UNIQ_UI_DEPTH4(B) 0.0
    #define UNIQ_UI_DMODE4(B) (float)UNIQ_UI_DEPTH_GE
    #define UNIQ_UI_INV4(B) 0.0
#endif
#if UNIQ_UI_CONDITIONS >= 5
    #define UNIQ_UI_CONF5(B) UI_B##B##_C5_CONF
    #define UNIQ_UI_DEPTH5(B) UI_B##B##_C5_DEPTH
    #define UNIQ_UI_DMODE5(B) (float)UI_B##B##_C5_DMODE
    #define UNIQ_UI_INV5(B) (UI_B##B##_C5_INV ? 1.0 : 0.0)
#else
    #define UNIQ_UI_CONF5(B) 0.0
    #define UNIQ_UI_DEPTH5(B) 0.0
    #define UNIQ_UI_DMODE5(B) (float)UNIQ_UI_DEPTH_GE
    #define UNIQ_UI_INV5(B) 0.0
#endif
#endif

/*=============================================================================
	UI
=============================================================================*/

uniform int UI_HELP <
    ui_type = "radio";
    ui_label = " ";
    ui_text =
        "1. Setup preprocessor variables for this shader:\n"
        "  • UNIQ_UI_RES_WIDTH [num]\n"
        "      Width of original resolution that was used to setup UI.\n"
        "  • UNIQ_UI_RES_HEIGHT [num]\n"
        "      Height of original resolution that was used to setup UI.\n"
        "  • UNIQ_UI_CHECKPOINTS [1-3]\n"
        "      Number of backbuffer checkpoint passes to generate.\n"
        "  • CHECKPOINT_FRAME_SMOOTHING [0-3]\n"
        "      Number of previous frames to additionally store per checkpoint\n"
        "      to average results for color sampling.\n"
        "  • UNIQ_UI_BOX_COUNT [1-15]\n"
        "      Number of UI boxes to configure.\n"
        "  • UNIQ_UI_CONDITIONS [1-5]\n"
        "      Max number of conditions to setup per UI box.\n"
        "  • ENABLE_SETUP_MODE [0-1]\n"
        "      Enables setup mode where user can setup UI boxes & samples\n"
        "      for conditions and preview their position visually.\n"
        "  • ENABLE_DEBUG_STATS [0-1]\n"
        "      Enables debug stats window.\n"
        "\n"
        "2. Set ENABLE_SETUP_MODE and ENABLE_DEBUG_STATS to 1.\n"
        "\n"
        "3. Go into the Setup category of this shader and set\n"
        "   Debug View = Setup (Boxes + Samples).\n"
        "\n"
        "4. Ensure that Show BOX 1 is selected.\n"
        "\n"
        "5. Long-click (left mouse button) anywhere on the game screen.\n"
        "   A sampling cursor with zoom should be visible.\n"
        "\n"
        "6. Find a pixel that defines the UI box that you want to mask.\n"
        "\n"
        "7. Let the long-click freeze the values inside Sampling Box.\n"
        "\n"
        "8. Go into the BOX 1 category and copy sampled point values into\n"
        "   Box X1 and Box Y1.\n"
        "   Optionally you can use the already sampled color to create a condition.\n"
        "   Copy R, G, B values into Match Color and (if useful) the depth value\n"
        "   into Depth Threshold. Set the given mode for matching\n"
        "   (read tooltips for more details).\n"
        "\n"
        "9. Find the next pixel for the opposite corner of the UI and set it up\n"
        "   the same way for Box X2 and Box Y2.\n"
        "\n"
        "10. The box should be visible in mapped position on the Setup view.\n"
        "\n"
        "11. Now you can setup required conditions that have to be matched\n"
        "    to display this box. Use sampling as in step 5 to get values\n"
        "    for condition matching.\n"
        "\n"
        "12. Experiment with more complex rules.";
    ui_category = "Help";
    ui_category_closed = true;
>;

uniform float UI_STRENGTH <
    __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
    ui_label = "Restore Strength";
    ui_tooltip =
        "Strength of restoration (mix between checkpoint and current frames) for\n"
        "active boxes or inversed mask.";
    ui_category = "Restore";
    ui_category_closed = false;
> = 1.0;

uniform float UI_BOX_FEATHER <
    ui_type = "drag";
    ui_label = "HUD Feather (px)";
    ui_tooltip =
        "Soft falloff around every box, in pixels.\n"
        "Boxes can override this value individually.";
    ui_min = 0.0; ui_max = 200.0;
    ui_category = "Restore";
> = 30.0;

#if UNIQ_UI_CHECKPOINTS >= 2
uniform bool UI_CKPT2_RESTORE_CH1 <
    ui_label = "Restore Checkpoint 1 On Checkpoint 2 Pass";
    ui_tooltip =
        "After checkpoint 2 saves the current frame (with effects),\n"
        "replace the whole backbuffer with checkpoint 1 frame.";
    ui_category = "Restore";
    ui_spacing = 3;
> = false;
#endif
#if UNIQ_UI_CHECKPOINTS >= 3
uniform bool UI_CKPT3_RESTORE_CH2 <
    ui_label = "Restore Checkpoint 2 On Checkpoint 3 Pass";
    ui_tooltip =
        "After checkpoint 3 saves the current frame (with effects),\n"
        "replace the whole backbuffer with checkpoint 2 frame.";
    ui_category = "Restore";
> = false;
#endif

uniform bool UI_INV_MASK <
    ui_label = "Apply Inverted Mask";
    ui_tooltip =
        "Restore checkpoint frame everywhere except displayed UI boxes.\n"
        "Effects after checkpoint and before this pass stay on the UI only.\n"
        "Per-box restore is SKIPPED while this is on.";
    ui_category = "Restore";
    ui_spacing = 3;
> = false;

uniform int UI_INV_MASK_STORE <
    ui_type = "combo";
    ui_label = "Inverted Mask Checkpoint";
    ui_items = UNIQ_UI_CKPT_ITEMS;
    ui_tooltip =
        "Checkpoint restored outside the combined UI mask.\n"
        "Used when Apply Inverted Mask is ON.";
    ui_category = "Restore";
> = 0;

#if ENABLE_SETUP_MODE
uniform int UI_VIEW <
    ui_type = "combo";
    ui_label = "Debug View";
    ui_items = UNIQ_UI_VIEW_ITEMS;
    ui_tooltip =
        "None: normal output of this shader.\n"
        "Setup (Boxes + Samples): checkpoint frame with boxes and samples.\n"
        "Combined Mask (Displayed): combined & displayed UI mask.\n"
        "Mask (For Checkpoint): mask for the selected checkpoint only.\n"
        "Checkpoint Pass: frame stored in selected checkpoint.\n"
        "Depth: linearized depth from ReShade.\n"
        "Combined Debug Output: normal output + setup + combined mask + depth.";
    ui_category = "Setup";
    ui_category_closed = false;
> = UNIQ_UI_VIEW_NONE;

uniform int UI_PROBE_CKPT <
    ui_type = "combo";
    ui_label = "Checkpoint To Sample";
    ui_items = UNIQ_UI_CKPT_ITEMS;
    ui_tooltip = "Checkpoint used for sampling RGB color by setup widgets.";
    ui_category = "Setup";
> = 0;

uniform int UI_SHOW_LEGEND <
    ui_type = "combo";
    ui_label = "Setup Legend";
    ui_items = UNIQ_UI_LEGEND_ITEMS;
    ui_tooltip =
        "Displays legend with colors for setup view.\n"
        "Drawn in Setup and Combined Debug Output.";
    ui_category = "Setup";
> = UNIQ_UI_LEGEND_OFF;

#define UNIQ_UI_DECL_SHOW(B, LAB, SP) \
    uniform bool UI_SHOW_B##B < ui_label = LAB; ui_tooltip = \
        "Draw this box overlay in Setup and Combined Debug Output views.\n" \
        "Uncheck to hide overlapping boxes."; ui_category = "Setup"; ui_spacing = SP; > = true;
#if UNIQ_UI_BOX_COUNT >= 1
UNIQ_UI_DECL_SHOW(1, "Show BOX 1", 3)
#endif
#if UNIQ_UI_BOX_COUNT >= 2
UNIQ_UI_DECL_SHOW(2, "Show BOX 2", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 3
UNIQ_UI_DECL_SHOW(3, "Show BOX 3", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 4
UNIQ_UI_DECL_SHOW(4, "Show BOX 4", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 5
UNIQ_UI_DECL_SHOW(5, "Show BOX 5", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 6
UNIQ_UI_DECL_SHOW(6, "Show BOX 6", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 7
UNIQ_UI_DECL_SHOW(7, "Show BOX 7", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 8
UNIQ_UI_DECL_SHOW(8, "Show BOX 8", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 9
UNIQ_UI_DECL_SHOW(9, "Show BOX 9", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 10
UNIQ_UI_DECL_SHOW(10, "Show BOX 10", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 11
UNIQ_UI_DECL_SHOW(11, "Show BOX 11", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 12
UNIQ_UI_DECL_SHOW(12, "Show BOX 12", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 13
UNIQ_UI_DECL_SHOW(13, "Show BOX 13", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 14
UNIQ_UI_DECL_SHOW(14, "Show BOX 14", 0)
#endif
#if UNIQ_UI_BOX_COUNT >= 15
UNIQ_UI_DECL_SHOW(15, "Show BOX 15", 0)
#endif
#undef UNIQ_UI_DECL_SHOW

uniform bool UI_FREEZE_CHECKPOINTS <
    ui_label = "Freeze Checkpoints";
    ui_tooltip =
        "Keeps the current checkpoint frame and does not capture new frames.\n"
        "This allows to sample RGB values from frozen checkpoint frame.\n"
        "Right click on this widget to setup keyboard shortcut.\n"
        "NOTE: Depth probes still read the LIVE buffer!";
    ui_category = "Sampling Box";
    ui_category_closed = true;
> = false;

uniform bool UI_SAMPLE_00 <
    ui_label = "Allow Sampling (0,0)";
    ui_tooltip =
        "Shift the sampling point in setup to allow (0,0) point sampling.\n"
        "Cursor position is calculated with a 1-pixel clamp, so (0,0)\n"
        "cannot be reached unless we force that offset.";
    ui_category = "Sampling Box";
> = false;

uniform bool UI_SHOW_ZOOM <
    ui_label = "Show Sampling Zoom Window";
    ui_tooltip =
        "Displays zoom window near sampling point while long-click sampling (yellow dot).\n"
        "Out-of-range (near screen edges) pixels are black.";
    ui_category = "Sampling Box";
> = true;

uniform bool UI_SHOW_SAMPLER <
    ui_label = "Show Sampling Box";
    ui_tooltip =
        "Displays sampling box widget that shows:\n"
        "- RGB values of sampled color,\n"
        "- X,Y position of sample (scaled by preprocessor setup),\n"
        "- linearized depth (0-1).\n"
        "Always drawn in Setup, Checkpoint Pass, and Depth views.";
    ui_category = "Sampling Box";
> = false;

uniform bool UI_PANEL_LOCK <
    ui_label = "Lock Sampling Box (Use UV)";
    ui_tooltip =
        "ON: uses Sampling Box Position (UV) to set position of sampling box.\n"
        "OFF: drag the sampling box in-game.";
    ui_category = "Sampling Box";
> = false;

uniform float2 UI_PANEL_POS <
    ui_type = "drag";
    ui_label = "Sampling Box Position (UV)";
    ui_tooltip =
        "Top-left UV position of the sampling box. Requires Lock Sampling Box (Use UV) checked.\n"
        "(1,1) clamps to the bottom-right.";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "Sampling Box";
> = float2(1.0, 1.0);

uniform float UI_HOLD_MS <
    ui_type = "drag";
    ui_label = "Long-click (ms)";
    ui_tooltip =
        "Hold left mouse button this long on a pixel to freeze it's RGB, X/Y, and depth values.";
    ui_min = 80.0; ui_max = 2000.0;
    ui_category = "Sampling Box";
> = 1000.0;
#endif

#if ENABLE_DEBUG_STATS
uniform bool UI_STATS_LOCK <
    ui_label = "Lock Stats Window (Use UV)";
    ui_tooltip =
        "ON: uses Stats Window Position (UV) to set position of stats window.\n"
        "OFF: drag the stats window in-game.\n"
        "Use mouse wheel and scrollbar to scroll stats list.";
    ui_category = "Debug stats";
    ui_category_closed = true;
> = false;

uniform float2 UI_STATS_POS <
    ui_type = "drag";
    ui_label = "Stats Window Position (UV)";
    ui_tooltip =
        "Top-left UV position of the stats window. Requires Lock Stats Window (Use UV) checked.\n"
        "(1,1) clamps to the bottom-right.";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "Debug stats";
> = float2(0.0, 0.0);
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
uniform float2 UI_MOUSE < source = "mousepoint"; hidden = true; >;
uniform bool UI_LMB < source = "mousebutton"; keycode = 0; hidden = true; >;
uniform float UI_FT < source = "frametime"; hidden = true; >;
#endif
#if ENABLE_DEBUG_STATS
uniform float UI_WHEEL < source = "mousewheel"; hidden = true; min = -10000; max = 10000; step = 1; >;
#endif

#if UNIQ_UI_BOX_COUNT >= 1
UNIQ_UI_DECL_FULL(1, "BOX 1", "UniqFX/ui_box1_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 2
UNIQ_UI_DECL_FULL(2, "BOX 2", "UniqFX/ui_box2_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 3
UNIQ_UI_DECL_FULL(3, "BOX 3", "UniqFX/ui_box3_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 4
UNIQ_UI_DECL_FULL(4, "BOX 4", "UniqFX/ui_box4_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 5
UNIQ_UI_DECL_FULL(5, "BOX 5", "UniqFX/ui_box5_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 6
UNIQ_UI_DECL_FULL(6, "BOX 6", "UniqFX/ui_box6_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 7
UNIQ_UI_DECL_FULL(7, "BOX 7", "UniqFX/ui_box7_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 8
UNIQ_UI_DECL_FULL(8, "BOX 8", "UniqFX/ui_box8_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 9
UNIQ_UI_DECL_FULL(9, "BOX 9", "UniqFX/ui_box9_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 10
UNIQ_UI_DECL_FULL(10, "BOX 10", "UniqFX/ui_box10_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 11
UNIQ_UI_DECL_FULL(11, "BOX 11", "UniqFX/ui_box11_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 12
UNIQ_UI_DECL_FULL(12, "BOX 12", "UniqFX/ui_box12_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 13
UNIQ_UI_DECL_FULL(13, "BOX 13", "UniqFX/ui_box13_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 14
UNIQ_UI_DECL_FULL(14, "BOX 14", "UniqFX/ui_box14_mask.png")
#endif
#if UNIQ_UI_BOX_COUNT >= 15
UNIQ_UI_DECL_FULL(15, "BOX 15", "UniqFX/ui_box15_mask.png")
#endif

/*=============================================================================
	Textures
=============================================================================*/

#define UNIQ_UI_DECL_RT(NAME, W, H, FMT) \
texture NAME##Tex { Width = W; Height = H; Format = FMT; }; \
sampler NAME##Point \
{ \
    Texture = NAME##Tex; \
    MinFilter = POINT; MagFilter = POINT; MipFilter = POINT; \
    AddressU = CLAMP; AddressV = CLAMP; \
};

UNIQ_UI_DECL_RT(UNIQ_UI_Store1, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#if UNIQ_UI_CHECKPOINTS >= 2
UNIQ_UI_DECL_RT(UNIQ_UI_Store2, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#endif
#if UNIQ_UI_CHECKPOINTS >= 3
UNIQ_UI_DECL_RT(UNIQ_UI_Store3, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#endif

#if CHECKPOINT_FRAME_SMOOTHING >= 1
    #define UNIQ_UI_DECL_H1(N) UNIQ_UI_DECL_RT(UNIQ_UI_Store##N##Hist1, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#else
    #define UNIQ_UI_DECL_H1(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 2
    #define UNIQ_UI_DECL_H2(N) UNIQ_UI_DECL_RT(UNIQ_UI_Store##N##Hist2, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#else
    #define UNIQ_UI_DECL_H2(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 3
    #define UNIQ_UI_DECL_H3(N) UNIQ_UI_DECL_RT(UNIQ_UI_Store##N##Hist3, BUFFER_WIDTH, BUFFER_HEIGHT, UNIQ_UI_COLOR_FORMAT)
#else
    #define UNIQ_UI_DECL_H3(N)
#endif
#define UNIQ_UI_DECL_HISTS(N) UNIQ_UI_DECL_H1(N) UNIQ_UI_DECL_H2(N) UNIQ_UI_DECL_H3(N)
UNIQ_UI_DECL_HISTS(1)
#if UNIQ_UI_CHECKPOINTS >= 2
UNIQ_UI_DECL_HISTS(2)
#endif
#if UNIQ_UI_CHECKPOINTS >= 3
UNIQ_UI_DECL_HISTS(3)
#endif
#undef UNIQ_UI_DECL_HISTS
#undef UNIQ_UI_DECL_H1
#undef UNIQ_UI_DECL_H2
#undef UNIQ_UI_DECL_H3

UNIQ_UI_DECL_RT(UNIQ_UI_Eval, UNIQ_UI_BOX_COUNT, UNIQ_UI_CONDITIONS, RGBA16F)
UNIQ_UI_DECL_RT(UNIQ_UI_EvalOn, UNIQ_UI_BOX_COUNT, 1, RGBA16F)

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
UNIQ_UI_DECL_RT(UNIQ_UI_State, UNIQ_UI_STATE_N, 1, RGBA32F)
UNIQ_UI_DECL_RT(UNIQ_UI_StatePrev, UNIQ_UI_STATE_N, 1, RGBA32F)
#endif
#undef UNIQ_UI_DECL_RT

/*=============================================================================
	Helpers
=============================================================================*/

float3 ufx_store(float2 uv, int sid)
{
    float4 uv4 = float4(uv, 0, 0);
    float3 c = float3(0.0, 0.0, 0.0);
#if UNIQ_UI_CHECKPOINTS >= 3
    [branch]
    if(sid == 2)
        c = tex2Dlod(UNIQ_UI_Store3Point, uv4).rgb;
    else
#endif
#if UNIQ_UI_CHECKPOINTS >= 2
    [branch]
    if(sid == 1)
        c = tex2Dlod(UNIQ_UI_Store2Point, uv4).rgb;
    else
#endif
        c = tex2Dlod(UNIQ_UI_Store1Point, uv4).rgb;
    return c;
}

#if CHECKPOINT_FRAME_SMOOTHING >= 1
float3 ufx_store_age(float2 uv, int sid, int age)
{
    float4 uv4 = float4(uv, 0, 0);
    float3 c = float3(0.0, 0.0, 0.0);
#if CHECKPOINT_FRAME_SMOOTHING >= 3
    #define UNIQ_UI_AGE_SAMP(H1, H2, H3) \
        [branch] \
        if(age >= 3) \
            c = tex2Dlod(H3, uv4).rgb; \
        else if(age >= 2) \
            c = tex2Dlod(H2, uv4).rgb; \
        else \
            c = tex2Dlod(H1, uv4).rgb;
#elif CHECKPOINT_FRAME_SMOOTHING >= 2
    #define UNIQ_UI_AGE_SAMP(H1, H2, H3) \
        [branch] \
        if(age >= 2) \
            c = tex2Dlod(H2, uv4).rgb; \
        else \
            c = tex2Dlod(H1, uv4).rgb;
#else
    #define UNIQ_UI_AGE_SAMP(H1, H2, H3) \
        c = tex2Dlod(H1, uv4).rgb
#endif
#if UNIQ_UI_CHECKPOINTS >= 3
    [branch]
    if(sid == 2)
    {
        UNIQ_UI_AGE_SAMP(UNIQ_UI_Store3Hist1Point, UNIQ_UI_Store3Hist2Point, UNIQ_UI_Store3Hist3Point);
    }
    else
#endif
#if UNIQ_UI_CHECKPOINTS >= 2
    [branch]
    if(sid == 1)
    {
        UNIQ_UI_AGE_SAMP(UNIQ_UI_Store2Hist1Point, UNIQ_UI_Store2Hist2Point, UNIQ_UI_Store2Hist3Point);
    }
    else
#endif
    {
        UNIQ_UI_AGE_SAMP(UNIQ_UI_Store1Hist1Point, UNIQ_UI_Store1Hist2Point, UNIQ_UI_Store1Hist3Point);
    }
#undef UNIQ_UI_AGE_SAMP
    return c;
}

float3 ufx_store_smooth(float2 uv, int sid, int n)
{
    float3 c = ufx_store(uv, sid);
    float w = 1.0;
    n = clamp(n, 0, CHECKPOINT_FRAME_SMOOTHING);
    [branch]
    if(n >= 1)
    {
        c += ufx_store_age(uv, sid, 1);
        w += 1.0;
#if CHECKPOINT_FRAME_SMOOTHING >= 2
        [branch]
        if(n >= 2)
        {
            c += ufx_store_age(uv, sid, 2);
            w += 1.0;
#if CHECKPOINT_FRAME_SMOOTHING >= 3
            [branch]
            if(n >= 3)
            {
                c += ufx_store_age(uv, sid, 3);
                w += 1.0;
            }
#endif
        }
#endif
    }
    return c / w;
}
#endif

float2 ufx_orig_to_uv(float2 px)
{
    float2 last = max(UNIQ_UI_ORIG - 1.0, float2(0.0, 0.0));
    float2 p = floor(clamp(px, float2(0.0, 0.0), last));
    return saturate((p + 0.375) / UNIQ_UI_ORIG);
}

float4 ufx_clamp_orig_rect(float4 rpx)
{
    // Inclusive corners (X1,Y1,X2,Y2) -> xywh. Either corner order is OK.
    float4 r = float4(0.0, 0.0, 0.0, 0.0);
    float2 last = float2(0.0, 0.0);
    float2 a = float2(0.0, 0.0);
    float2 b = float2(0.0, 0.0);
    float2 lo = float2(0.0, 0.0);
    float2 hi = float2(0.0, 0.0);
    last = max(UNIQ_UI_ORIG - 1.0, float2(0.0, 0.0));
    a = clamp(rpx.xy, float2(0.0, 0.0), last);
    b = clamp(rpx.zw, float2(0.0, 0.0), last);
    lo = min(a, b);
    hi = max(a, b);
    r = float4(lo, hi - lo + 1.0);
    return r;
}

float2 ufx_uv_to_orig_px(float2 uv)
{
    float2 last = max(UNIQ_UI_ORIG - 1.0, float2(0.0, 0.0));
    float2 p = floor(saturate(uv) * UNIQ_UI_ORIG);
    p = min(p, last);
    return p;
}

bool ufx_xywh_is_frame(float4 r)
{
    return (r.x < 0.5) && (r.y < 0.5) && (abs(r.z - UNIQ_UI_ORIG.x) < 0.5) && (abs(r.w - UNIQ_UI_ORIG.y) < 0.5);
}

bool ufx_rect_is_fs(float4 rpx, bool fs)
{
    return fs || ufx_xywh_is_frame(ufx_clamp_orig_rect(rpx));
}

float4 ufx_effective_rect(float4 rpx, bool fs)
{
    float4 r = float4(0.0, 0.0, 0.0, 0.0);
    float4 o = float4(0.0, 0.0, 1.0, 1.0);
    if(!fs)
    {
        r = ufx_clamp_orig_rect(rpx);
        if(!ufx_xywh_is_frame(r))
            o = float4(r.xy / UNIQ_UI_ORIG, r.zw / UNIQ_UI_ORIG);
    }
    return o;
}

float ufx_mask_cov(sampler s, float2 uv, float4 er)
{
    float2 local = float2(0.0, 0.0);
    float cov = 0.0;
    [branch]
    if(er.z > 0.0 && er.w > 0.0)
    {
        local = (uv - er.xy) / er.zw;
        cov = saturate(tex2Dlod(s, float4(local, 0, 0)).x);
    }
    return cov;
}

float ufx_mask_inside(sampler s, float2 uv, float4 er)
{
    float2 local = float2(0.0, 0.0);
    float cov = 0.0;
    [branch]
    if(er.z > 0.0 && er.w > 0.0)
    {
        local = (uv - er.xy) / er.zw;
        [branch]
        if(local.x >= 0.0 && local.y >= 0.0 && local.x <= 1.0 && local.y <= 1.0)
            cov = saturate(tex2Dlod(s, float4(local, 0, 0)).x);
    }
    return cov;
}

#if ENABLE_SETUP_MODE
bool ufx_is_setup_view()
{
    return UI_VIEW == UNIQ_UI_VIEW_SETUP;
}

bool ufx_is_combined_view()
{
    return UI_VIEW == UNIQ_UI_VIEW_COMBINED;
}

float2 ufx_quad_uv(float2 uv)
{
    float2 cuv = uv * 2.0;
    if(uv.x >= 0.5)
        cuv.x -= 1.0;
    if(uv.y >= 0.5)
        cuv.y -= 1.0;
    return saturate(cuv);
}

int ufx_quad_id(float2 uv)
{
    int q = 0;
    if(uv.x >= 0.5)
        q = 1;
    if(uv.y >= 0.5)
        q += 2;
    return q;
}

bool ufx_wants_sampler()
{
    bool on = false;
    if(!ufx_is_combined_view())
        on = UI_SHOW_SAMPLER || UI_SHOW_ZOOM || ufx_is_setup_view()
            || (UI_VIEW == UNIQ_UI_VIEW_CKPT) || (UI_VIEW == UNIQ_UI_VIEW_DEPTH);
    return on;
}

bool ufx_setup_use_layers(inout float2 uv)
{
    bool run = false;
    [branch]
    if(UI_VIEW == UNIQ_UI_VIEW_SETUP)
        run = true;
    else if(UI_VIEW == UNIQ_UI_VIEW_COMBINED)
    {
        [branch]
        if(uv.x >= 0.5 && uv.y < 0.5)
        {
            uv = ufx_quad_uv(uv);
            run = true;
        }
    }
    return run;
}

int ufx_ckpt_probe()
{
    return clamp(UI_PROBE_CKPT, 0, UNIQ_UI_CHECKPOINTS - 1);
}

bool ufx_state_ready(float w)
{
    return abs(w - UNIQ_UI_STATE_MAGIC) < 0.02;
}
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
float2 ufx_mouse_uv()
{
    return clamp(UI_MOUSE * BUFFER_PIXEL_SIZE, BUFFER_PIXEL_SIZE, 1.0 - BUFFER_PIXEL_SIZE);
}

#if ENABLE_SETUP_MODE
float2 ufx_sample_orig_px()
{
    float2 last = max(UNIQ_UI_ORIG - 1.0, float2(0.0, 0.0));
    float2 px = ufx_uv_to_orig_px(UI_MOUSE * BUFFER_PIXEL_SIZE);
    if(UI_SAMPLE_00)
        px = max(px - 1.0, float2(0.0, 0.0));
    else
        px = max(px, float2(1.0, 1.0));
    px = min(px, last);
    return px;
}

float2 ufx_sample_uv()
{
    return ufx_orig_to_uv(ufx_sample_orig_px());
}
#endif

float2 ufx_state_uv(int slot)
{
    return float2((slot + 0.5) / (float)UNIQ_UI_STATE_N, 0.5);
}

float4 ufx_state(int slot)
{
    return tex2Dlod(UNIQ_UI_StatePoint, float4(ufx_state_uv(slot), 0, 0));
}

#if ENABLE_DEBUG_STATS
float ufx_stats_view_h()
{
    float min_h = UNIQ_UI_STATS_PAD * 2.0 + (float)UNIQ_UI_STATS_LINES * UNIQ_UI_STATS_ROW;
    float max_h = min(UNIQ_UI_STATS_VIEW_MAX, BUFFER_SCREEN_SIZE.y - UNIQ_UI_STATS_MARGIN);
    max_h = max(max_h, min_h);
    return min(UNIQ_UI_STATS_CONTENT_H, max_h);
}

float ufx_stats_scroll_max()
{
    return max(UNIQ_UI_STATS_CONTENT_H - ufx_stats_view_h(), 0.0);
}

float2 ufx_stats_home()
{
    float2 def = float2(0.0, 0.0);
    float2 view = float2(UNIQ_UI_STATS_W, ufx_stats_view_h());
    def.x = 1.0 - view.x * BUFFER_PIXEL_SIZE.x;
    def.y = 0.5 - 0.5 * view.y * BUFFER_PIXEL_SIZE.y;
    return max(def, float2(0.0, 0.0));
}
#endif
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
float3 ufx_dt_mix(float3 o, float2 uv, float2 pos, float size, float3 col, float res)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float3 r = o;
    if(px.y >= pos.y && px.y < pos.y + size)
        r = lerp(o, col, saturate(res));
    return r;
}

float2 ufx_dt_at(float2 origin, int col)
{
    return DrawText_Shift(origin, int2(col, 0), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO);
}

int ufx_dt_uint(float2 pos, float2 uv, int v, inout float res)
{
    uint u = 0;
    uint a = 0;
    uint b = 0;
    uint c = 0;
    uint d = 0;
    uint e = 0;
    int n = 1;
    int buf[5];
    v = clamp(v, 0, 99999);
    u = (uint)v;
    e = u % 10u;
    u = u / 10u;
    d = u % 10u;
    u = u / 10u;
    c = u % 10u;
    u = u / 10u;
    b = u % 10u;
    u = u / 10u;
    a = u;
    buf[0] = __0;
    buf[1] = __0;
    buf[2] = __0;
    buf[3] = __0;
    buf[4] = __0;
    if(v >= 10000)
    {
        buf[0] = __0 + (int)a;
        buf[1] = __0 + (int)b;
        buf[2] = __0 + (int)c;
        buf[3] = __0 + (int)d;
        buf[4] = __0 + (int)e;
        n = 5;
    }
    else if(v >= 1000)
    {
        buf[0] = __0 + (int)b;
        buf[1] = __0 + (int)c;
        buf[2] = __0 + (int)d;
        buf[3] = __0 + (int)e;
        n = 4;
    }
    else if(v >= 100)
    {
        buf[0] = __0 + (int)c;
        buf[1] = __0 + (int)d;
        buf[2] = __0 + (int)e;
        n = 3;
    }
    else if(v >= 10)
    {
        buf[0] = __0 + (int)d;
        buf[1] = __0 + (int)e;
        n = 2;
    }
    else
    {
        buf[0] = __0 + (int)e;
        n = 1;
    }
    DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, buf, n, res);
    return n;
}

void ufx_dt_u01(float2 dp, float2 uv, float v, inout float res)
{
    int n = 0;
    int whole = 0;
    int f0 = 0;
    int f1 = 0;
    int f2 = 0;
    uint un = 0;
    uint uw = 0;
    uint ua = 0;
    uint ub = 0;
    int g[5];
    v = saturate(v);
    n = clamp((int)(v * 1000.0 + 0.5), 0, 1000);
    un = (uint)n;
    uw = un / 1000u;
    whole = (int)uw;
    un = un - uw * 1000u;
    ua = un / 100u;
    f0 = (int)ua;
    un = un - ua * 100u;
    ub = un / 10u;
    f1 = (int)ub;
    f2 = (int)(un - ub * 10u);
    g[0] = __0 + whole;
    g[1] = __Dot;
    g[2] = __0 + f0;
    g[3] = __0 + f1;
    g[4] = __0 + f2;
    DrawText_String(DrawText_Shift(dp, int2(-1, 0), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, g, 5, res);
}

#if ENABLE_SETUP_MODE
float3 ufx_dt_depth_row(float3 o, float2 tex, float2 origin, float depth)
{
    float res = 0.0;
    float2 coord = tex;
    int lab[7];
    lab[0] = __D; lab[1] = __e; lab[2] = __p; lab[3] = __t;
    lab[4] = __h; lab[5] = __Colon; lab[6] = __Space;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, coord, lab, 7, res);
    ufx_dt_u01(ufx_dt_at(origin, 8), coord, saturate(depth), res);
    return ufx_dt_mix(o, tex, origin, UNIQ_UI_DT_SIZE, float3(1.00, 0.95, 0.55), res);
}
#endif

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
int ufx_dt_mask_tag(float2 pos, float2 uv, inout float res)
{
    int tag[6];
    tag[0] = __sBrac_O;
    tag[1] = __M;
    tag[2] = __A;
    tag[3] = __S;
    tag[4] = __K;
    tag[5] = __sBrac_C;
    DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, tag, 6, res);
    return 6;
}
#endif

int ufx_dt_ch_tag(float2 pos, float2 uv, int ck, inout float res)
{
    int n = 0;
    int tag[4];
    int br[1];
    ck = clamp(ck, 1, 3);
    tag[0] = __sBrac_O;
    tag[1] = __C;
    tag[2] = __H;
    tag[3] = __Space;
    DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, tag, 4, res);
    n = 4 + ufx_dt_uint(ufx_dt_at(pos, 4), uv, ck, res);
    br[0] = __sBrac_C;
    DrawText_String(ufx_dt_at(pos, n), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, br, 1, res);
    return n + 1;
}

void ufx_dt_rect_px(float2 pos, float2 uv, int bx, int by, int bw, int bh, inout float res)
{
    int col = 1;
    int x2 = 0;
    int y2 = 0;
    int sep[4];
    x2 = bx + bw - 1;
    y2 = by + bh - 1;
    sep[0] = __rBrac_O;
    sep[1] = 0;
    sep[2] = 0;
    sep[3] = 0;
    DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 1, res);
    col += ufx_dt_uint(ufx_dt_at(pos, col), uv, bx, res);
    sep[0] = __Comma;
    DrawText_String(ufx_dt_at(pos, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 1, res);
    col += 1;
    col += ufx_dt_uint(ufx_dt_at(pos, col), uv, by, res);
    sep[0] = __rBrac_C;
    sep[1] = __Minus;
    sep[2] = __Greater;
    sep[3] = __rBrac_O;
    DrawText_String(ufx_dt_at(pos, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 4, res);
    col += 4;
    col += ufx_dt_uint(ufx_dt_at(pos, col), uv, x2, res);
    sep[0] = __Comma;
    DrawText_String(ufx_dt_at(pos, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 1, res);
    col += 1;
    col += ufx_dt_uint(ufx_dt_at(pos, col), uv, y2, res);
    sep[0] = __rBrac_C;
    sep[1] = __Equals;
    DrawText_String(ufx_dt_at(pos, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 2, res);
    col += 2;
    col += ufx_dt_uint(ufx_dt_at(pos, col), uv, bw, res);
    sep[0] = __x;
    DrawText_String(ufx_dt_at(pos, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sep, 1, res);
    col += 1;
    ufx_dt_uint(ufx_dt_at(pos, col), uv, bh, res);
}
#endif

#if ENABLE_SETUP_MODE
float3 ufx_legend_line(float2 uv, float3 o, float2 origin, float3 col, int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9, int a10, int a11, int a12, int a13, int a14, int a15, int a16, int a17)
{
    float res = 0.0;
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 coord = uv;
    float2 text_pos = float2(0.0, 0.0);
    int line[18];
    line[0] = a0; line[1] = a1; line[2] = a2; line[3] = a3; line[4] = a4;
    line[5] = a5; line[6] = a6; line[7] = a7; line[8] = a8; line[9] = a9;
    line[10] = a10; line[11] = a11; line[12] = a12; line[13] = a13; line[14] = a14;
    line[15] = a15; line[16] = a16; line[17] = a17;
    text_pos = ufx_dt_at(origin, 2);
    DrawText_String(text_pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, coord, line, 18, res);
    if(px.x >= text_pos.x && px.y >= text_pos.y && px.y < text_pos.y + UNIQ_UI_DT_SIZE)
        o = lerp(o, float3(0.92, 0.92, 0.95), saturate(res));
    if(px.x >= origin.x && px.y >= origin.y + 1.0 && px.x < origin.x + 10.0 && px.y < origin.y + 13.0)
        o = col;
    return o;
}

float3 ufx_legend_draw(float2 uv, float3 src)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 origin = float2(8.0, 8.0);
    float2 plate1 = float2(0.0, 0.0);
    float3 o = src;
    float row_h = UNIQ_UI_DT_SIZE;
    float y = 0.0;
    float margin = 8.0;
    if(UI_SHOW_LEGEND == UNIQ_UI_LEGEND_TR)
        origin = float2(BUFFER_SCREEN_SIZE.x - margin - UNIQ_UI_LEGEND_W, margin);
    else if(UI_SHOW_LEGEND == UNIQ_UI_LEGEND_BL)
        origin = float2(margin, BUFFER_SCREEN_SIZE.y - margin - UNIQ_UI_LEGEND_H);
    else if(UI_SHOW_LEGEND == UNIQ_UI_LEGEND_BR)
        origin = float2(BUFFER_SCREEN_SIZE.x - margin - UNIQ_UI_LEGEND_W, BUFFER_SCREEN_SIZE.y - margin - UNIQ_UI_LEGEND_H);
    plate1 = origin + float2(UNIQ_UI_LEGEND_W, UNIQ_UI_LEGEND_H);
    if(px.x >= origin.x && px.y >= origin.y && px.x <= plate1.x && px.y <= plate1.y)
    {
        o = lerp(src, float3(0.04, 0.04, 0.05), 0.90);
        if(min(min(px.x - origin.x, plate1.x - px.x), min(px.y - origin.y, plate1.y - px.y)) < 2.0)
            o = float3(0.50, 0.50, 0.55);
        y = origin.y + 6.0;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_BOX_ON,
            __B, __O, __X, __Space, __D, __I, __S, __P, __L, __A, __Y, __E, __D, __Space, __Space, __Space, __Space, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_BOX_OFF,
            __B, __O, __X, __Space, __N, __O, __T, __Space, __D, __I, __S, __P, __L, __A, __Y, __E, __D, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_BOX_DIS,
            __B, __O, __X, __Space, __D, __I, __S, __A, __B, __L, __E, __D, __Space, __Space, __Space, __Space, __Space, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_CUR,
            __C, __U, __R, __S, __O, __R, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_COND,
            __C, __O, __N, __D, __I, __T, __I, __O, __N, __Space, __P, __R, __O, __B, __E, __Space, __Space, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_FRZ,
            __L, __A, __S, __T, __Space, __P, __R, __O, __B, __E, __Space, __Space, __Space, __Space, __Space, __Space, __Space, __Space);
        y += row_h;
        o = ufx_legend_line(uv, o, float2(origin.x + 6.0, y), UNIQ_UI_COL_PROBE,
            __C, __U, __R, __R, __E, __N, __T, __L, __Y, __Space, __P, __R, __O, __B, __I, __N, __G, __Space);
    }
    return o;
}

float2 ufx_label_keep(float2 origin, float2 size, float pad)
{
    float2 screen = BUFFER_SCREEN_SIZE;
    float max_x = 0.0;
    float max_y = 0.0;
    max_x = screen.x - pad - size.x;
    max_y = screen.y - pad - size.y;
    if(max_x < pad)
        max_x = pad;
    if(max_y < pad)
        max_y = pad;
    origin.x = clamp(origin.x, pad, max_x);
    origin.y = clamp(origin.y, pad, max_y);
    return origin;
}

float ufx_label_lw(int shown, bool mask_on)
{
    int n = 11 + ((shown >= 10) ? 2 : 1);
    if(mask_on)
        n = n + 7;
    return UNIQ_UI_DT_SIZE * 0.5 * (float)n;
}

float2 ufx_label_home(float4 r, int shown, bool mask_on)
{
    float2 origin = float2(5.0, 4.0);
    float2 size = float2(ufx_label_lw(shown, mask_on), UNIQ_UI_DT_SIZE);
    origin.x = r.x * BUFFER_SCREEN_SIZE.x + 5.0;
    origin.y = r.y * BUFFER_SCREEN_SIZE.y + 4.0;
    return ufx_label_keep(origin, size, 3.0);
}

float ufx_label_hit(float2 a0, float2 asz, float2 b0, float2 bsz)
{
    float2 a1 = float2(0.0, 0.0);
    float2 b1 = float2(0.0, 0.0);
    a1 = a0 + asz + float2(2.0, 2.0);
    b1 = b0 + bsz + float2(2.0, 2.0);
    a0 -= float2(3.0, 3.0);
    b0 -= float2(3.0, 3.0);
    return (a0.x <= b1.x && b0.x <= a1.x && a0.y <= b1.y && b0.y <= a1.y) ? 1.0 : 0.0;
}

float ufx_label_prev(int id, int prev, bool show, float4 rect, bool fs, bool mask_on, float2 origin, float2 size)
{
    float4 er = float4(0.0, 0.0, 0.0, 0.0);
    float2 po = float2(0.0, 0.0);
    float2 ps = float2(0.0, 0.0);
    float hit = 0.0;
    if(show && (prev < id))
    {
        er = ufx_effective_rect(rect, fs);
        if(er.z > 0.0 && er.w > 0.0)
        {
            ps.x = ufx_label_lw(prev + 1, mask_on);
            ps.y = UNIQ_UI_DT_SIZE;
            po = ufx_label_home(er, prev + 1, mask_on);
            hit = ufx_label_hit(origin, size, po, ps);
        }
    }
    return hit;
}

#define UNIQ_UI_LABEL_PREV(B) \
    stack += ufx_label_prev(id, UNIQ_UI_BOX_I(B), UI_SHOW_B##B, UNIQ_UI_RECT(B), UI_B##B##_FS, UI_B##B##_MASK_ON, origin, size);

float ufx_label_stack(int id, float2 origin, float2 size)
{
    float stack = 0.0;
    UNIQ_UI_EACH_BOX(UNIQ_UI_LABEL_PREV)
    return stack;
}
#undef UNIQ_UI_LABEL_PREV

float3 ufx_box_label(float2 uv, float4 r, int id, int ckpt, bool mask_on, float3 src)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 origin = float2(0.0, 0.0);
    float2 plate0 = float2(0.0, 0.0);
    float2 plate1 = float2(0.0, 0.0);
    float res = 0.0;
    float lw = 0.0;
    float lh = UNIQ_UI_DT_SIZE;
    float pad = 3.0;
    int shown = 1;
    int n = 0;
    int lab[4];
    float3 o = src;
    if(r.z > 0.0 && r.w > 0.0)
    {
        shown = clamp(id, 0, UNIQ_UI_BOX_COUNT - 1) + 1;
        lw = ufx_label_lw(shown, mask_on);
        origin = ufx_label_home(r, shown, mask_on);
        origin.y += ufx_label_stack(id, origin, float2(lw, lh)) * (lh + 4.0);
        origin = ufx_label_keep(origin, float2(lw, lh), pad);
        plate0 = origin - float2(3.0, 3.0);
        plate1 = origin + float2(lw + 2.0, lh + 2.0);
        if(px.x >= plate0.x && px.y >= plate0.y && px.x <= plate1.x && px.y <= plate1.y)
            o = lerp(o, float3(0.03, 0.03, 0.04), 0.88);
        lab[0] = __B; lab[1] = __O; lab[2] = __X; lab[3] = __Space;
        DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 4, res);
        n = 4 + ufx_dt_uint(ufx_dt_at(origin, 4), uv, shown, res);
        n = n + 1;
        if(mask_on)
        {
            n = n + ufx_dt_mask_tag(ufx_dt_at(origin, n), uv, res);
            n = n + 1;
        }
        ufx_dt_ch_tag(ufx_dt_at(origin, n), uv, clamp(ckpt, 0, 2) + 1, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(1.00, 0.95, 0.55), res);
    }
    return o;
}

float3 ufx_panel_draw(float2 uv, float3 base, float2 panel_uv, float3 disp_c, float2 disp_uv, float disp_d, float valid, float hold, float dragging, int ckpt)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 p0 = panel_uv * BUFFER_SCREEN_SIZE;
    float2 p1 = p0 + float2(UNIQ_UI_PANEL_W, UNIQ_UI_PANEL_H);
    float2 q = float2(0.0, 0.0);
    float2 num = float2(0.0, 0.0);
    float2 orig = float2(0.0, 0.0);
    float3 o = base;
    float3 border = float3(0.50, 0.50, 0.55);
    float edge = 0.0;
    float res = 0.0;
    int ck = 1;
    int ox = 0;
    int oy = 0;
    if(px.x >= p0.x && px.y >= p0.y && px.x <= p1.x && px.y <= p1.y)
    {
        q = px - p0;
        o = lerp(base, float3(0.04, 0.04, 0.05), 0.90);
        if(q.y >= 74.0)
            o = disp_c;

        if(valid > 0.5)
            border = float3(0.20, 0.85, 0.75);
        if(hold >= UI_HOLD_MS)
            border = float3(1.00, 0.85, 0.12);
        if(dragging > 0.75)
            border = float3(0.95, 0.55, 0.15);
        edge = min(min(q.x, p1.x - px.x), min(q.y, p1.y - px.y));
        if(edge < 3.0)
            o = border;

        if(q.x >= 8.0 && q.x <= 18.0 && q.y >= 10.0 && q.y <= 24.0)
            o = float3(1.0, 0.2, 0.2);
        if(q.x >= 8.0 && q.x <= 18.0 && q.y >= 32.0 && q.y <= 46.0)
            o = float3(0.2, 1.0, 0.25);
        if(q.x >= 8.0 && q.x <= 18.0 && q.y >= 54.0 && q.y <= 68.0)
            o = float3(0.25, 0.5, 1.0);

        num = p0 + float2(24.0, 10.0);
        res = 0.0;
        ufx_dt_uint(num, uv, (int)round(disp_c.r * 255.0), res);
        o = ufx_dt_mix(o, uv, num, UNIQ_UI_DT_SIZE, float3(1.0, 0.25, 0.22), res);
        num = p0 + float2(24.0, 32.0);
        res = 0.0;
        ufx_dt_uint(num, uv, (int)round(disp_c.g * 255.0), res);
        o = ufx_dt_mix(o, uv, num, UNIQ_UI_DT_SIZE, float3(0.25, 1.0, 0.28), res);
        num = p0 + float2(24.0, 54.0);
        res = 0.0;
        ufx_dt_uint(num, uv, (int)round(disp_c.b * 255.0), res);
        o = ufx_dt_mix(o, uv, num, UNIQ_UI_DT_SIZE, float3(0.30, 0.55, 1.0), res);

        orig = disp_uv;
        ox = (int)orig.x;
        oy = (int)orig.y;
        num = p0 + float2(88.0, 32.0);
        res = 0.0;
        ufx_dt_uint(num, uv, ox, res);
        o = ufx_dt_mix(o, uv, num, UNIQ_UI_DT_SIZE, float3(0.92, 0.92, 0.95), res);
        num = p0 + float2(140.0, 32.0);
        res = 0.0;
        ufx_dt_uint(num, uv, oy, res);
        o = ufx_dt_mix(o, uv, num, UNIQ_UI_DT_SIZE, float3(0.92, 0.92, 0.95), res);

        o = ufx_dt_depth_row(o, uv, p0 + float2(88.0, 54.0), disp_d);

        ck = clamp(ckpt, 0, 2) + 1;
        res = 0.0;
        ufx_dt_ch_tag(p0 + float2(88.0, 10.0), uv, ck, res);
        o = ufx_dt_mix(o, uv, p0 + float2(88.0, 10.0), UNIQ_UI_DT_SIZE, float3(1.00, 0.95, 0.55), res);
    }
    return o;
}
#endif

float ufx_sat(float3 c)
{
    float maxc = max(c.r, max(c.g, c.b));
    float minc = min(c.r, min(c.g, c.b));
    return (maxc - minc) / max(maxc, 1e-4);
}

float ufx_hue(float3 c)
{
    float r = c.r;
    float g = c.g;
    float b = c.b;
    float maxc = max(r, max(g, b));
    float minc = min(r, min(g, b));
    float d = maxc - minc;
    float h = 0.0;
    if(d >= 1e-5)
    {
        if(r >= g && r >= b)
            h = (g - b) / d + (g < b ? 6.0 : 0.0);
        else if(g >= b)
            h = (b - r) / d + 2.0;
        else
            h = (r - g) / d + 4.0;
        h = h / 6.0;
    }
    return h;
}

float ufx_color_match_mode(float3 a, float3 b, float3 blk, int shade)
{
    float m = 0.0;
    float sa = 0.0;
    float sb = 0.0;
    float d = 0.0;
    float nd = 0.0;
    float tmix = 0.0;
    float3 ad = float3(0.0, 0.0, 0.0);
    float3 p = float3(0.0, 0.0, 0.0);
    float3 t = float3(0.0, 0.0, 0.0);
    float3 lo = float3(0.0, 0.0, 0.0);
    float3 dir = float3(0.0, 0.0, 0.0);
    float3 ch = float3(0.0, 0.0, 0.0);
    float3 pred = float3(0.0, 0.0, 0.0);
    if(shade == UNIQ_UI_SHADE_CHROMA)
    {
        sa = max(max(a.r, a.g), max(a.b, 1e-4));
        sb = max(max(b.r, b.g), max(b.b, 1e-4));
        m = 1.0 - saturate(length(a / sa - b / sb) * 0.57735027);
    }
    else if(shade == UNIQ_UI_SHADE_HUE)
    {
        sa = ufx_sat(a);
        sb = ufx_sat(b);
        if(sa < 0.04 && sb < 0.04)
            m = 1.0;
        else if(sa < 0.04 || sb < 0.04)
            m = 0.0;
        else
        {
            d = abs(ufx_hue(a) - ufx_hue(b));
            d = min(d, 1.0 - d);
            m = 1.0 - saturate(d * 2.0);
        }
    }
    else if(shade == UNIQ_UI_SHADE_MIX)
    {
        p = saturate(a);
        t = saturate(b);
        lo = saturate(blk);
        dir = max(t - lo, 0.0);
        t = lo + dir;
        ad = max(lo - p, 0.0);
        pred = max(p - t, 0.0);
        d = max(max(ad.r, max(ad.g, ad.b)), max(pred.r, max(pred.g, pred.b)));
        m = 1.0 - saturate(d);
        sa = (lo.r + lo.g + lo.b) * (1.0 / 3.0);
        ch = lo - sa;
        nd = dot(ch, ch);
        sa = (p.r + p.g + p.b) * (1.0 / 3.0);
        pred = p - sa;
        tmix = 0.0;
        if(nd > 1e-8)
            tmix = dot(pred, ch) / nd;
        tmix = saturate(tmix);
        m = min(m, tmix);
    }
    else
    {
        ad = abs(a - b);
        m = 1.0 - saturate(max(ad.r, max(ad.g, ad.b)));
    }
    return m;
}

float ufx_depth_ok(float depth, float dth, int mode)
{
    float ok = 1.0;
    if(dth > 0.0)
    {
        if(mode == UNIQ_UI_DEPTH_EXACT)
            ok = (abs(depth - dth) <= UNIQ_UI_DEPTH_EXACT_EPS) ? 1.0 : 0.0;
        else if(mode == UNIQ_UI_DEPTH_LE)
            ok = (depth <= dth) ? 1.0 : 0.0;
        else
            ok = (depth >= dth) ? 1.0 : 0.0;
    }
    return ok;
}

float2 ufx_box_q(float2 uv, float4 r)
{
    float2 half_px = 0.5 * r.zw * BUFFER_SCREEN_SIZE;
    return abs((uv - (r.xy + 0.5 * r.zw)) * BUFFER_SCREEN_SIZE) - half_px;
}

float ufx_box_cov(float2 uv, float4 er, float feather)
{
    float2 grow = float2(0.0, 0.0);
    float2 q = float2(0.0, 0.0);
    float cov = 0.0;
    grow = feather * BUFFER_PIXEL_SIZE;
    if(er.z > 0.0 && er.w > 0.0)
    {
        if(uv.x >= er.x - grow.x && uv.y >= er.y - grow.y && uv.x <= er.x + er.z + grow.x && uv.y <= er.y + er.w + grow.y)
        {
            q = ufx_box_q(uv, er);
            if(q.x <= 0.0 && q.y <= 0.0)
                cov = 1.0;
            else
                cov = 1.0 - smoothstep(0.0, feather, length(max(q, 0.0)));
        }
    }
    return cov;
}

float4 ufx_cond_pair(bool on, float4 rect, bool fs, bool mask_on, bool invert, float2 probe, float3 tgt, float3 tgt_blk, int shade, float conf, float dth, int dmode, int sid, int smooth)
{
    float4 pair = float4(-1.0, 0.0, 0.0, 0.0);
    float4 er = float4(0.0, 0.0, 0.0, 0.0);
    float2 uv = float2(0.0, 0.0);
    float3 c = float3(0.0, 0.0, 0.0);
    float sc = 1.0;
    float depth = 0.0;
    float col_ok = 1.0;
    float dep_ok = 1.0;
    float ev = 0.0;
    bool go = on;
    er = ufx_effective_rect(rect, fs);
    if(!mask_on && (er.z <= 0.0 || er.w <= 0.0))
        go = false;
    [branch]
    if(go)
    {
        [branch]
        if(conf > 0.0 || dth > 0.0)
            uv = ufx_orig_to_uv(probe);
        [branch]
        if(conf > 0.0)
        {
#if CHECKPOINT_FRAME_SMOOTHING >= 1
            c = ufx_store_smooth(uv, sid, smooth);
#else
            c = ufx_store(uv, sid);
            smooth = 0;
#endif
            sc = ufx_color_match_mode(c, tgt, tgt_blk, shade);
            col_ok = (sc >= saturate(conf)) ? 1.0 : 0.0;
        }
        [branch]
        if(dth > 0.0)
        {
            depth = ReShade::GetLinearizedDepth(uv);
            dep_ok = ufx_depth_ok(depth, dth, dmode);
        }
        ev = (col_ok > 0.5 && dep_ok > 0.5) ? 1.0 : 0.0;
        if(invert)
            ev = 1.0 - ev;
        pair.x = saturate(ev);
        pair.y = saturate(sc);
        pair.z = saturate(depth);
        pair.w = 1.0;
    }
    return pair;
}

float4 ufx_eval_load(int b, int c)
{
    return tex2Dlod(UNIQ_UI_EvalPoint, float4(((float)b + 0.5) / (float)UNIQ_UI_BOX_COUNT, ((float)c + 0.5) / (float)UNIQ_UI_CONDITIONS, 0, 0));
}

#if UNIQ_UI_CONDITIONS >= 2
float ufx_join(int need, float a, float b, float c, float d, float e)
{
    int hits = ((a > 0.5) ? 1 : 0) + ((b > 0.5) ? 1 : 0);
    float r = 0.0;
#if UNIQ_UI_CONDITIONS >= 3
    hits += (c > 0.5) ? 1 : 0;
#endif
#if UNIQ_UI_CONDITIONS >= 4
    hits += (d > 0.5) ? 1 : 0;
#endif
#if UNIQ_UI_CONDITIONS >= 5
    hits += (e > 0.5) ? 1 : 0;
#endif
    need = clamp(need, 1, UNIQ_UI_CONDITIONS);
    r = (hits >= need) ? 1.0 : 0.0;
    return r;
}
#endif

float ufx_eval_join(int b, int need)
{
#if UNIQ_UI_CONDITIONS == 1
    float a = ufx_eval_load(b, 0).x;
    float r = 0.0;
    if(a > 0.5)
        r = 1.0;
    return r;
#else
    float a = ufx_eval_load(b, 0).x;
    float b2 = ufx_eval_load(b, 1).x;
    float c = -1.0;
    float d = -1.0;
    float e = -1.0;
#if UNIQ_UI_CONDITIONS >= 3
    c = ufx_eval_load(b, 2).x;
#endif
#if UNIQ_UI_CONDITIONS >= 4
    d = ufx_eval_load(b, 3).x;
#endif
#if UNIQ_UI_CONDITIONS >= 5
    e = ufx_eval_load(b, 4).x;
#endif
    return ufx_join(need, a, b2, c, d, e);
#endif
}

#if UNIQ_UI_CONDITIONS >= 2
int ufx_need_of(int b)
{
    int n = 1;
    [branch]
    if(b == 0)
        n = UNIQ_UI_NEED(1);
    UNIQ_UI_EACH_BOX_TAIL(UNIQ_UI_NEED_CASE)
    return n;
}
#endif

float4 ufx_eval_box(int b)
{
    return tex2Dlod(UNIQ_UI_EvalOnPoint, float4(((float)b + 0.5) / (float)UNIQ_UI_BOX_COUNT, 0.5, 0, 0));
}

float ufx_feather(bool ov, float v)
{
    return max(ov ? v : UI_BOX_FEATHER, 1.0);
}

int ufx_skip_end(int prev, int mode)
{
    int end = -1;
    if(mode == UNIQ_UI_SKIP_ALL)
        end = UNIQ_UI_BOX_COUNT - 1;
    else if(mode >= 2)
        end = prev + mode - 1;
    end = min(end, UNIQ_UI_BOX_COUNT - 1);
    return end;
}

#define UNIQ_UI_SKIP_ACCUM(PREV, B) \
    if((PREV) < id) \
    { \
        if(UI_B##B##_ON && ((PREV) > skip_until) && (UNIQ_UI_SKIP_SEL(B) > 0)) \
        { \
            if(ufx_eval_join((PREV), UNIQ_UI_NEED(B)) > 0.5) \
                skip_until = ufx_skip_end((PREV), UNIQ_UI_SKIP_SEL(B)); \
        } \
    }

float ufx_skip_prev(int id)
{
    int skip_until = -1;
    float skipped = 0.0;
    UNIQ_UI_EACH_BOX(UNIQ_UI_SKIP_STEP)
    if(id <= skip_until)
        skipped = 1.0;
    return skipped;
}
#undef UNIQ_UI_SKIP_ACCUM

UNIQ_UI_EACH_BOX(UNIQ_UI_FN_PACK)

float ufx_mask(float2 uv)
{
    float m = 0.0;
    float cov = 0.0;
    float ft = 0.0;
    float4 er = float4(0.0, 0.0, 0.0, 0.0);
    float4 boxst = float4(0.0, 0.0, 0.0, 0.0);
    UNIQ_UI_EACH_BOX(UNIQ_UI_MASK_ADD)
    return saturate(m);
}

#if ENABLE_SETUP_MODE
float ufx_mask_ckpt(float2 uv)
{
    float m = 0.0;
    int ckpt = ufx_ckpt_probe();
    float cov = 0.0;
    float ft = 0.0;
    float4 er = float4(0.0, 0.0, 0.0, 0.0);
    float4 boxst = float4(0.0, 0.0, 0.0, 0.0);
    UNIQ_UI_EACH_BOX(UNIQ_UI_MASK_CKPT_ADD)
    return saturate(m);
}

float ufx_probe_mark(float2 uv, int use, float2 probe)
{
    float2 puv = float2(0.0, 0.0);
    float probe_d = 0.0;
    float m = 0.0;
    if(use >= 0)
    {
        puv = ufx_orig_to_uv(probe);
        probe_d = length((uv - puv) * BUFFER_SCREEN_SIZE);
        m = 1.0 - smoothstep(2.5, 4.5, probe_d);
    }
    return m;
}

float3 ufx_probe_label(float2 uv, int use, float2 probe, int box_id, int cond_id, int samp, float3 src)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 puv = float2(0.0, 0.0);
    float2 origin = float2(0.0, 0.0);
    float2 plate0 = float2(0.0, 0.0);
    float2 plate1 = float2(0.0, 0.0);
    float2 screen = BUFFER_SCREEN_SIZE;
    float res = 0.0;
    float w = 0.0;
    float h = UNIQ_UI_DT_SIZE;
    float gap = 10.0;
    float pad = 3.0;
    int n = 12;
    int col = 0;
    int shown_b = 1;
    int shown_c = 1;
    int shown_z = 1;
    int lab[2];
    float3 o = src;
    if(use >= 0)
    {
        puv = ufx_orig_to_uv(probe) * screen;
        shown_b = clamp(box_id, 0, UNIQ_UI_BOX_COUNT - 1) + 1;
        shown_c = clamp(cond_id, 1, UNIQ_UI_CONDITIONS);
        shown_z = clamp(samp, 0, 2) + 1;
        n = 11 + ((shown_b >= 10) ? 2 : 1);
        w = h * 0.5 * (float)n;
        origin.x = puv.x - w * 0.5;
        origin.y = puv.y - gap - h;
        origin = ufx_label_keep(origin, float2(w, h), pad);
        plate0 = origin - float2(3.0, 3.0);
        plate1 = origin + float2(w + 2.0, h + 2.0);
        if(px.x >= plate0.x && px.y >= plate0.y && px.x <= plate1.x && px.y <= plate1.y)
            src = lerp(src, float3(0.03, 0.03, 0.04), 0.88);
        lab[0] = __B;
        DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 1, res);
        col = 1 + ufx_dt_uint(ufx_dt_at(origin, 1), uv, shown_b, res);
        lab[0] = __Space;
        lab[1] = __C;
        DrawText_String(ufx_dt_at(origin, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 2, res);
        col = col + 2;
        col = col + ufx_dt_uint(ufx_dt_at(origin, col), uv, shown_c, res);
        lab[0] = __Space;
        DrawText_String(ufx_dt_at(origin, col), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 1, res);
        col = col + 1;
        ufx_dt_ch_tag(ufx_dt_at(origin, col), uv, shown_z, res);
        o = ufx_dt_mix(src, uv, origin, UNIQ_UI_DT_SIZE, UNIQ_UI_COL_COND, res);
    }
    return o;
}

float3 ufx_setup_marks(float2 uv, float4 r, bool fs,
                      int use0, float2 p0
#if UNIQ_UI_CONDITIONS >= 2
                      , int use1, float2 p1
#endif
#if UNIQ_UI_CONDITIONS >= 3
                      , int use2, float2 p2
#endif
#if UNIQ_UI_CONDITIONS >= 4
                      , int use3, float2 p3
#endif
#if UNIQ_UI_CONDITIONS >= 5
                      , int use4, float2 p4
#endif
                      , float3 o)
{
    r = ufx_effective_rect(r, fs);
    if(r.z > 0.0 && r.w > 0.0)
    {
        o = lerp(o, UNIQ_UI_COL_COND, ufx_probe_mark(uv, use0, p0));
#if UNIQ_UI_CONDITIONS >= 2
        o = lerp(o, UNIQ_UI_COL_COND, ufx_probe_mark(uv, use1, p1));
#endif
#if UNIQ_UI_CONDITIONS >= 3
        o = lerp(o, UNIQ_UI_COL_COND, ufx_probe_mark(uv, use2, p2));
#endif
#if UNIQ_UI_CONDITIONS >= 4
        o = lerp(o, UNIQ_UI_COL_COND, ufx_probe_mark(uv, use3, p3));
#endif
#if UNIQ_UI_CONDITIONS >= 5
        o = lerp(o, UNIQ_UI_COL_COND, ufx_probe_mark(uv, use4, p4));
#endif
    }
    return o;
}

float3 ufx_setup_probes(float2 uv, float4 r, bool fs,
                       int use0, float2 p0, int s0
#if UNIQ_UI_CONDITIONS >= 2
                       , int use1, float2 p1, int s1
#endif
#if UNIQ_UI_CONDITIONS >= 3
                       , int use2, float2 p2, int s2
#endif
#if UNIQ_UI_CONDITIONS >= 4
                       , int use3, float2 p3, int s3
#endif
#if UNIQ_UI_CONDITIONS >= 5
                       , int use4, float2 p4, int s4
#endif
                       , int id, float3 o)
{
    r = ufx_effective_rect(r, fs);
    if(r.z > 0.0 && r.w > 0.0)
    {
        o = ufx_probe_label(uv, use0, p0, id, 1, s0, o);
#if UNIQ_UI_CONDITIONS >= 2
        o = ufx_probe_label(uv, use1, p1, id, 2, s1, o);
#endif
#if UNIQ_UI_CONDITIONS >= 3
        o = ufx_probe_label(uv, use2, p2, id, 3, s2, o);
#endif
#if UNIQ_UI_CONDITIONS >= 4
        o = ufx_probe_label(uv, use3, p3, id, 4, s3, o);
#endif
#if UNIQ_UI_CONDITIONS >= 5
        o = ufx_probe_label(uv, use4, p4, id, 5, s4, o);
#endif
    }
    return o;
}

float3 ufx_setup_tint(float2 uv, float4 r, bool enable, float on, float feather,
                      int id, int ckpt, bool mask_on, float tcov, float skipped, float3 src)
{
    float sdf = 0.0;
    float outline = 0.0;
    float fill = 0.0;
    float vis = 0.0;
    float outside = 0.0;
    float2 grow = float2(0.0, 0.0);
    float2 q = float2(0.0, 0.0);
    float3 tint = float3(0.0, 0.0, 0.0);
    float3 o = src;
    [branch]
    if(r.z > 0.0 && r.w > 0.0)
    {
        grow = max(feather, 2.0) * BUFFER_PIXEL_SIZE;
        if(uv.x >= r.x - grow.x && uv.y >= r.y - grow.y && uv.x <= r.x + r.z + grow.x && uv.y <= r.y + r.w + grow.y)
        {
            q = ufx_box_q(uv, r);
            outside = length(max(q, 0.0));
            sdf = abs(outside + min(max(q.x, q.y), 0.0));
            outline = 1.0 - smoothstep(0.0, 2.0, sdf);
            fill = ufx_box_cov(uv, r, feather) * 0.28;
            if(!enable)
                tint = UNIQ_UI_COL_BOX_DIS;
            else if(skipped > 0.5)
            {
                tint = UNIQ_UI_COL_BOX_OFF;
                on = 0.0;
            }
            else
                tint = lerp(UNIQ_UI_COL_BOX_OFF, UNIQ_UI_COL_BOX_ON, on);
            vis = max(outline, fill * lerp(0.35, 1.0, on));
            o = lerp(src, tint, saturate(vis));
            [branch]
            if(mask_on)
                o = lerp(o, tint, saturate(tcov) * lerp(0.35, 1.0, on) * 0.45);
        }
        o = ufx_box_label(uv, r, id, ckpt, mask_on, o);
    }
    return o;
}
#endif

#if ENABLE_DEBUG_STATS
float3 ufx_stats_row_tag(float3 o, float2 uv, float2 p0, float2 origin, bool skipped, int skip_mode, int id)
{
    float res = 0.0;
    float cw = UNIQ_UI_DT_SIZE * 0.5 / UNIQ_UI_DT_RATIO;
    float right = p0.x + UNIQ_UI_STATS_W - UNIQ_UI_STATS_PAD - UNIQ_UI_STATS_BAR_W - 4.0;
    int n = 0;
    int digits = 1;
    int to_box = 1;
    int tag[16];
    float3 col = UNIQ_UI_COL_BOX_DIS;
    float2 pos = origin;
    tag[0] = 0; tag[1] = 0; tag[2] = 0; tag[3] = 0; tag[4] = 0;
    tag[5] = 0; tag[6] = 0; tag[7] = 0; tag[8] = 0; tag[9] = 0;
    tag[10] = 0; tag[11] = 0; tag[12] = 0; tag[13] = 0; tag[14] = 0;
    tag[15] = 0;
    if(skipped)
    {
        tag[0] = __sBrac_O; tag[1] = __S; tag[2] = __K; tag[3] = __I; tag[4] = __P;
        tag[5] = __P; tag[6] = __E; tag[7] = __D; tag[8] = __sBrac_C;
        n = 9;
        col = UNIQ_UI_COL_BOX_OFF;
    }
    else if(skip_mode == UNIQ_UI_SKIP_ALL)
    {
        tag[0] = __sBrac_O;
        tag[1] = __C; tag[2] = __A; tag[3] = __N; tag[4] = __Space;
        tag[5] = __S; tag[6] = __K; tag[7] = __I; tag[8] = __P; tag[9] = __Space;
        tag[10] = __A; tag[11] = __L; tag[12] = __L;
        tag[13] = __sBrac_C;
        n = 14;
        col = UNIQ_UI_COL_PROBE;
    }
    else if(skip_mode >= 2)
    {
        to_box = min(id + skip_mode + 1, UNIQ_UI_BOX_COUNT);
        if(to_box >= 10)
            digits = 2;
        n = 13 + digits + 1;
        col = UNIQ_UI_COL_PROBE;
        tag[0] = __sBrac_O;
        tag[1] = __C; tag[2] = __A; tag[3] = __N; tag[4] = __Space;
        tag[5] = __S; tag[6] = __K; tag[7] = __I; tag[8] = __P; tag[9] = __Space;
        tag[10] = __T; tag[11] = __O; tag[12] = __Space;
    }
    if(n > 0)
    {
        pos.x = right - (float)n * cw;
        if(skipped || skip_mode == UNIQ_UI_SKIP_ALL)
        {
            DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, tag, n, res);
        }
        else
        {
            DrawText_String(pos, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, tag, 13, res);
            digits = ufx_dt_uint(ufx_dt_at(pos, 13), uv, to_box, res);
            tag[0] = __sBrac_C;
            DrawText_String(ufx_dt_at(pos, 13 + digits), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, tag, 1, res);
        }
        o = ufx_dt_mix(o, uv, pos, UNIQ_UI_DT_SIZE, col, res);
    }
    return o;
}

float3 ufx_stats_tf(float3 o, float2 uv, float2 origin, float ev)
{
    float res = 0.0;
    float3 col = UNIQ_UI_COL_BOX_DIS;
    int n = 3;
    int w[7];
    w[0] = __O; w[1] = __f; w[2] = __f; w[3] = __Space; w[4] = __Space;
    w[5] = 0; w[6] = 0;
    if(ev > 1.5)
    {
        w[0] = __S; w[1] = __K; w[2] = __I; w[3] = __P;
        w[4] = __P; w[5] = __E; w[6] = __D;
        col = UNIQ_UI_COL_BOX_OFF;
        n = 7;
    }
    else if(ev < 0.0)
    {
        col = UNIQ_UI_COL_BOX_DIS;
        n = 3;
    }
    else if(ev > 0.5)
    {
        w[0] = __T; w[1] = __R; w[2] = __U; w[3] = __E;
        col = UNIQ_UI_COL_BOX_ON;
        n = 4;
    }
    else
    {
        w[0] = __F; w[1] = __A; w[2] = __L; w[3] = __S; w[4] = __E;
        col = UNIQ_UI_COL_BOX_OFF;
        n = 5;
    }
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, w, n, res);
    return ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, col, res);
}

float3 ufx_stats_cond(float3 o, float2 uv, float2 origin, int n, float ev, float inv, bool skipped, bool cond_on)
{
    float res = 0.0;
    int lab[10];
    int punct[2];
    int suf[11];
    int extra = 3;
    float shown = -1.0;
    lab[0] = __C; lab[1] = __o; lab[2] = __n; lab[3] = __d; lab[4] = __i;
    lab[5] = __t; lab[6] = __i; lab[7] = __o; lab[8] = __n; lab[9] = __Space;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 10, res);
    ufx_dt_uint(ufx_dt_at(origin, 10), uv, n, res);
    punct[0] = __Colon; punct[1] = __Space;
    DrawText_String(ufx_dt_at(origin, 11), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, punct, 2, res);
    o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.75, 0.78, 0.82), res);
    if(!cond_on)
    {
        res = 0.0;
        lab[0] = __O; lab[1] = __F; lab[2] = __F;
        DrawText_String(ufx_dt_at(origin, 13), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 3, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, UNIQ_UI_COL_BOX_DIS, res);
    }
    else
    {
        shown = skipped ? 2.0 : ev;
        o = ufx_stats_tf(o, uv, ufx_dt_at(origin, 13), shown);
        if(inv > 0.5 && !skipped && ev >= 0.0)
        {
            if(ev > 0.5)
                extra = 4;
            else if(ev >= 0.0)
                extra = 5;
            res = 0.0;
            suf[0] = __Space; suf[1] = __rBrac_O;
            suf[2] = __i; suf[3] = __n; suf[4] = __v; suf[5] = __e;
            suf[6] = __r; suf[7] = __t; suf[8] = __e; suf[9] = __d; suf[10] = __rBrac_C;
            DrawText_String(ufx_dt_at(origin, 13 + extra), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, suf, 11, res);
            o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.75, 0.78, 0.82), res);
        }
    }
    return o;
}

float ufx_stats_gate_ev(bool active, float ev)
{
    float g = -1.0;
    if(active)
        g = ev;
    return g;
}

float3 ufx_stats_gates(float3 o, float2 uv, float2 origin, float ev, float sc, float ct, float depth, float dt, int dmode)
{
    float res = 0.0;
    int lab[14];
    int ge[2];
    int dop[2];
    int sk[4];
    int dcol = 17;
    lab[0] = 0; lab[1] = 0; lab[2] = 0; lab[3] = 0;
    lab[4] = 0; lab[5] = 0; lab[6] = 0; lab[7] = 0;
    lab[8] = 0; lab[9] = 0; lab[10] = 0; lab[11] = 0;
    lab[12] = 0; lab[13] = 0;
    ge[0] = __Greater;
    ge[1] = __Equals;
    dop[0] = __Greater;
    dop[1] = __Equals;
    sk[0] = __S; sk[1] = __K; sk[2] = __I; sk[3] = __P;
    if(dmode == UNIQ_UI_DEPTH_EXACT)
    {
        dop[0] = __Tilde;
        dop[1] = __Equals;
    }
    else if(dmode == UNIQ_UI_DEPTH_LE)
    {
        dop[0] = __Less;
        dop[1] = __Equals;
    }
    if(ev < 0.0)
    {
        lab[0] = __N; lab[1] = __o; lab[2] = __Space;
        lab[3] = __e; lab[4] = __v; lab[5] = __a; lab[6] = __l;
        lab[7] = __u; lab[8] = __a; lab[9] = __t; lab[10] = __i;
        lab[11] = __o; lab[12] = __n;
        DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 13, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, UNIQ_UI_COL_BOX_DIS, res);
    }
    else
    {
        lab[0] = __C; lab[1] = __Space;
        DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 2, res);
        if(ct <= 0.0)
        {
            DrawText_String(ufx_dt_at(origin, 2), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sk, 4, res);
            dcol = 7;
        }
        else
        {
            ufx_dt_u01(ufx_dt_at(origin, 3), uv, saturate(sc), res);
            DrawText_String(ufx_dt_at(origin, 8), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, ge, 2, res);
            ufx_dt_u01(ufx_dt_at(origin, 12), uv, saturate(ct), res);
        }
        lab[0] = __D; lab[1] = __Space;
        DrawText_String(ufx_dt_at(origin, dcol), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 2, res);
        if(dt <= 0.0)
        {
            DrawText_String(ufx_dt_at(origin, dcol + 2), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, sk, 4, res);
        }
        else
        {
            ufx_dt_u01(ufx_dt_at(origin, dcol + 3), uv, saturate(depth), res);
            DrawText_String(ufx_dt_at(origin, dcol + 8), UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, dop, 2, res);
            ufx_dt_u01(ufx_dt_at(origin, dcol + 12), uv, saturate(dt), res);
        }
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.90, 0.90, 0.94), res);
    }
    return o;
}

float3 ufx_stats_displayed(float3 o, float2 uv, float2 origin, float on)
{
    int lab[10];
    float res = 0.0;
    lab[0] = __D; lab[1] = __i; lab[2] = __s; lab[3] = __p; lab[4] = __l;
    lab[5] = __a; lab[6] = __y; lab[7] = __e; lab[8] = __d; lab[9] = __Colon;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 10, res);
    o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.85, 0.85, 0.90), res);
    o = ufx_stats_tf(o, uv, ufx_dt_at(origin, 11), on);
    return o;
}

float3 ufx_stats_block(float2 uv, float3 o, float2 p0, int id, bool enable, bool fs, int skip_mode, bool mask_on, float4 rect, int need, int ckpt, float4 col_t, float4 dep_t, float4 dmode_t, float4 inv, float4 cond_use, float c5_conf, float c5_dep, float c5_dmode, float c5_inv, float c5_use, float scroll)
{
    float row = UNIQ_UI_STATS_ROW;
    float pad = UNIQ_UI_STATS_PAD;
    float y = 0.0;
    float res = 0.0;
    float on = 0.0;
    int shown_id = 1;
    int ckpt_show = 1;
    int col = 0;
    int bx = 0;
    int by = 0;
    int bw = 0;
    int bh = 0;
    float4 e1 = float4(-1.0, 0.0, 0.0, 0.0);
#if UNIQ_UI_CONDITIONS >= 2
    float4 e2 = float4(-1.0, 0.0, 0.0, 0.0);
#endif
#if UNIQ_UI_CONDITIONS >= 3
    float4 e3 = float4(-1.0, 0.0, 0.0, 0.0);
#endif
#if UNIQ_UI_CONDITIONS >= 4
    float4 e4 = float4(-1.0, 0.0, 0.0, 0.0);
#endif
#if UNIQ_UI_CONDITIONS >= 5
    float4 e5 = float4(-1.0, 0.0, 0.0, 0.0);
#endif
    float4 r = float4(0.0, 0.0, 0.0, 0.0);
    float2 origin = float2(0.0, 0.0);
    float2 val = float2(0.0, 0.0);
    int lab[21];
    float2 line_px = float2(0.0, 0.0);
    float skipped = 0.0;
    float4 boxst = ufx_eval_box(id);
    y = p0.y + pad + (float)id * (float)UNIQ_UI_STATS_LINES * row - scroll;
    origin = float2(p0.x + pad, y);
    shown_id = id + 1;
    skipped = boxst.y;
    on = boxst.x;
    ckpt = clamp(ckpt, 0, 2);
    ckpt_show = ckpt + 1;
    lab[0] = __B; lab[1] = __O; lab[2] = __X; lab[3] = __Space;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 4, res);
    col = 4 + ufx_dt_uint(ufx_dt_at(origin, 4), uv, shown_id, res);
    col = col + 1;
    if(mask_on)
    {
        col = col + ufx_dt_mask_tag(ufx_dt_at(origin, col), uv, res);
        col = col + 1;
    }
    ufx_dt_ch_tag(ufx_dt_at(origin, col), uv, ckpt_show, res);
    o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, UNIQ_UI_COL_PROBE, res);
    o = ufx_stats_row_tag(o, uv, p0, origin, skipped > 0.5, enable ? skip_mode : 0, id);
    if(id > 0)
    {
        line_px = uv * BUFFER_SCREEN_SIZE;
        if(line_px.y >= y - 1.0 && line_px.y < y && line_px.x >= p0.x + 2.0 && line_px.x <= p0.x + UNIQ_UI_STATS_W - 4.0 - UNIQ_UI_STATS_BAR_W)
            o = float3(0.22, 0.22, 0.26);
    }

    origin.y = y + row;
    res = 0.0;
    if(!enable)
    {
        lab[0] = __D; lab[1] = __I; lab[2] = __S; lab[3] = __A; lab[4] = __B; lab[5] = __L; lab[6] = __E; lab[7] = __D;
        DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 8, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, UNIQ_UI_COL_BOX_OFF, res);
    }
    else
        o = ufx_stats_displayed(o, uv, origin, (skipped > 0.5) ? 0.0 : ((on > 0.5) ? 1.0 : 0.0));

    origin.y = y + row * 2.0;
    res = 0.0;
    lab[0] = __P; lab[1] = __o; lab[2] = __s; lab[3] = __And; lab[4] = __S; lab[5] = __i; lab[6] = __z; lab[7] = __e;
    lab[8] = __Colon; lab[9] = __Space;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 10, res);
    o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.75, 0.78, 0.82), res);
    val = ufx_dt_at(origin, 10);
    if(!enable)
        o = ufx_stats_tf(o, uv, val, -1.0);
    else if(ufx_rect_is_fs(rect, fs))
    {
        res = 0.0;
        lab[0] = __F; lab[1] = __U; lab[2] = __L; lab[3] = __L; lab[4] = __S; lab[5] = __C; lab[6] = __R; lab[7] = __E; lab[8] = __E; lab[9] = __N;
        DrawText_String(val, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 10, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.90, 0.90, 0.94), res);
    }
    else
    {
        r = ufx_clamp_orig_rect(rect);
        bx = (int)(r.x + 0.5);
        by = (int)(r.y + 0.5);
        bw = (int)(r.z + 0.5);
        bh = (int)(r.w + 0.5);
        res = 0.0;
        ufx_dt_rect_px(val, uv, bx, by, bw, bh, res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.90, 0.90, 0.94), res);
    }

    origin.y = y + row * 3.0;
    res = 0.0;
    lab[0] = __C; lab[1] = __o; lab[2] = __n; lab[3] = __d; lab[4] = __i; lab[5] = __t; lab[6] = __i; lab[7] = __o; lab[8] = __n; lab[9] = __s;
    lab[10] = __Space; lab[11] = __t; lab[12] = __o; lab[13] = __Space; lab[14] = __m; lab[15] = __a; lab[16] = __t; lab[17] = __c;
    lab[18] = __h; lab[19] = __Colon; lab[20] = __Space;
    DrawText_String(origin, UNIQ_UI_DT_SIZE, UNIQ_UI_DT_RATIO, uv, lab, 21, res);
    o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.75, 0.78, 0.82), res);
    val = ufx_dt_at(origin, 21);
    if(!enable)
        o = ufx_stats_tf(o, uv, val, -1.0);
    else
    {
        res = 0.0;
        ufx_dt_uint(val, uv, clamp(need, 1, UNIQ_UI_CONDITIONS), res);
        o = ufx_dt_mix(o, uv, origin, UNIQ_UI_DT_SIZE, float3(0.90, 0.90, 0.94), res);
    }

    if(enable && skipped < 0.5)
    {
        e1 = ufx_eval_load(id, 0);
#if UNIQ_UI_CONDITIONS >= 2
        e2 = ufx_eval_load(id, 1);
#endif
#if UNIQ_UI_CONDITIONS >= 3
        e3 = ufx_eval_load(id, 2);
#endif
#if UNIQ_UI_CONDITIONS >= 4
        e4 = ufx_eval_load(id, 3);
#endif
#if UNIQ_UI_CONDITIONS >= 5
        e5 = ufx_eval_load(id, 4);
#endif
    }
    origin.y = y + row * 4.0;
    o = ufx_stats_cond(o, uv, origin, 1, e1.x, inv.x, skipped > 0.5, enable && (cond_use.x > 0.0));
    origin.y = y + row * 5.0;
    o = ufx_stats_gates(o, uv, origin, ufx_stats_gate_ev(enable && skipped < 0.5 && (cond_use.x > 0.0), e1.x), e1.y, col_t.x, e1.z, dep_t.x, (int)(dmode_t.x + 0.5));
#if UNIQ_UI_CONDITIONS >= 2
    origin.y = y + row * 6.0;
    o = ufx_stats_cond(o, uv, origin, 2, e2.x, inv.y, skipped > 0.5, enable && (cond_use.y > 0.0));
    origin.y = y + row * 7.0;
    o = ufx_stats_gates(o, uv, origin, ufx_stats_gate_ev(enable && skipped < 0.5 && (cond_use.y > 0.0), e2.x), e2.y, col_t.y, e2.z, dep_t.y, (int)(dmode_t.y + 0.5));
#endif
#if UNIQ_UI_CONDITIONS >= 3
    origin.y = y + row * 8.0;
    o = ufx_stats_cond(o, uv, origin, 3, e3.x, inv.z, skipped > 0.5, enable && (cond_use.z > 0.0));
    origin.y = y + row * 9.0;
    o = ufx_stats_gates(o, uv, origin, ufx_stats_gate_ev(enable && skipped < 0.5 && (cond_use.z > 0.0), e3.x), e3.y, col_t.z, e3.z, dep_t.z, (int)(dmode_t.z + 0.5));
#endif
#if UNIQ_UI_CONDITIONS >= 4
    origin.y = y + row * 10.0;
    o = ufx_stats_cond(o, uv, origin, 4, e4.x, inv.w, skipped > 0.5, enable && (cond_use.w > 0.0));
    origin.y = y + row * 11.0;
    o = ufx_stats_gates(o, uv, origin, ufx_stats_gate_ev(enable && skipped < 0.5 && (cond_use.w > 0.0), e4.x), e4.y, col_t.w, e4.z, dep_t.w, (int)(dmode_t.w + 0.5));
#endif
#if UNIQ_UI_CONDITIONS >= 5
    origin.y = y + row * 12.0;
    o = ufx_stats_cond(o, uv, origin, 5, e5.x, c5_inv, skipped > 0.5, enable && (c5_use > 0.0));
    origin.y = y + row * 13.0;
    o = ufx_stats_gates(o, uv, origin, ufx_stats_gate_ev(enable && skipped < 0.5 && (c5_use > 0.0), e5.x), e5.y, c5_conf, e5.z, c5_dep, (int)(c5_dmode + 0.5));
#endif
    return o;
}

float2 ufx_stats_origin_px()
{
    float4 s4 = float4(0.0, 0.0, 0.0, 0.0);
    float2 panel = float2(0.0, 0.0);
    float2 p = float2(0.0, 0.0);
    float2 maxp = float2(0.0, 0.0);
    float2 view = float2(UNIQ_UI_STATS_W, ufx_stats_view_h());
    s4 = ufx_state(UNIQ_UI_STATE_STATS_BASE);
    panel = ufx_stats_home();
    if(s4.w > 0.5)
        panel = s4.xy;
    if(UI_STATS_LOCK)
        panel = UI_STATS_POS;
    p = panel * BUFFER_SCREEN_SIZE;
    maxp = BUFFER_SCREEN_SIZE - view;
    if(maxp.x < 0.0)
        maxp.x = 0.0;
    if(maxp.y < 0.0)
        maxp.y = 0.0;
    return clamp(p, float2(0.0, 0.0), maxp);
}

float ufx_stats_scroll()
{
    float4 s = float4(0.0, 0.0, 0.0, 0.0);
    s = ufx_state(UNIQ_UI_STATE_STATS_SCROLL);
    return clamp(s.x, 0.0, ufx_stats_scroll_max());
}

float4 ufx_stats_bar(float2 p0, float2 p1, float scroll)
{
    float track_x = 0.0;
    float track_y0 = 0.0;
    float track_h = 0.0;
    float view_h = 0.0;
    float content = 0.0;
    float thumb_h = 0.0;
    float thumb_y = 0.0;
    float maxs = 0.0;
    track_x = p1.x - 2.0 - UNIQ_UI_STATS_BAR_W;
    track_y0 = p0.y + 4.0;
    view_h = p1.y - p0.y;
    track_h = view_h - 8.0;
    content = UNIQ_UI_STATS_CONTENT_H;
    thumb_h = track_h;
    thumb_y = track_y0;
    maxs = content - view_h;
    if(maxs < 0.0)
        maxs = 0.0;
    if(content > view_h && track_h > 1.0)
    {
        thumb_h = track_h * (view_h / content);
        if(thumb_h < 20.0)
            thumb_h = 20.0;
        if(thumb_h > track_h)
            thumb_h = track_h;
        if(maxs > 0.0)
            thumb_y = track_y0 + (scroll / maxs) * (track_h - thumb_h);
    }
    return float4(track_x, track_y0, thumb_y, thumb_h);
}

float3 ufx_stats_fill(float2 uv, float3 src, float2 p0, float2 p1)
{
    float4 s4 = float4(0.0, 0.0, 0.0, 0.0);
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float3 o = src;
    float edge = 0.0;
    s4 = ufx_state(UNIQ_UI_STATE_STATS_BASE);
    o = lerp(src, float3(0.04, 0.04, 0.05), 0.92);
    edge = min(min(px.x - p0.x, p1.x - px.x), min(px.y - p0.y, p1.y - px.y));
    if(edge < 2.0)
    {
        if(s4.z > 0.5)
            o = float3(0.95, 0.55, 0.15);
        else
            o = float3(0.50, 0.50, 0.55);
    }
    return o;
}

float3 ufx_stats_scrollbar(float2 uv, float3 src, float2 p0, float2 p1)
{
    float4 s = float4(0.0, 0.0, 0.0, 0.0);
    float4 bar = float4(0.0, 0.0, 0.0, 0.0);
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float3 o = src;
    float scroll = 0.0;
    float view_h = 0.0;
    if(UNIQ_UI_STATS_CONTENT_H > (p1.y - p0.y) + 0.5)
    {
        s = ufx_state(UNIQ_UI_STATE_STATS_SCROLL);
        scroll = clamp(s.x, 0.0, ufx_stats_scroll_max());
        bar = ufx_stats_bar(p0, p1, scroll);
        view_h = p1.y - p0.y;
        if(px.x >= bar.x && px.x <= p1.x - 2.0 && px.y >= bar.y && px.y <= p0.y + view_h - 4.0)
            o = float3(0.12, 0.12, 0.14);
        if(px.x >= bar.x + 1.0 && px.x <= p1.x - 3.0 && px.y >= bar.z && px.y <= bar.z + bar.w)
        {
            if(s.z > 0.75)
                o = float3(0.95, 0.55, 0.15);
            else
                o = float3(0.50, 0.50, 0.55);
        }
    }
    return o;
}
#endif

#if ENABLE_SETUP_MODE
float2 ufx_zoom_origin(float2 sample_px)
{
    float2 o = float2(0.0, 0.0);
    float2 screen = BUFFER_SCREEN_SIZE;
    float bw = (float)UNIQ_UI_ZOOM_W;
    float bh = (float)UNIQ_UI_ZOOM_H;
    float gap = (float)UNIQ_UI_ZOOM_GAP;
    float sx = floor(sample_px.x);
    float sy = floor(sample_px.y);
    o.x = sx + gap;
    o.y = sy - gap - bh;
    if(o.x + bw > screen.x)
        o.x = sx - gap - bw;
    if(o.y < 0.0)
        o.y = sy + gap;
    if(o.x < 0.0)
        o.x = max(sx + gap, 0.0);
    if(o.x + bw > screen.x)
        o.x = max(screen.x - bw, 0.0);
    if(o.y + bh > screen.y)
        o.y = max(sy - gap - bh, 0.0);
    if(o.y + bh > screen.y)
        o.y = max(screen.y - bh, 0.0);
    if(o.y < 0.0)
        o.y = 0.0;
    o = floor(o);
    if(o.x + bw > screen.x)
        o.x = max(floor(screen.x - bw), 0.0);
    if(o.y + bh > screen.y)
        o.y = max(floor(screen.y - bh), 0.0);
    if(o.x < 0.0)
        o.x = 0.0;
    if(o.y < 0.0)
        o.y = 0.0;
    return o;
}

static const float3 UNIQ_UI_LUMA = float3(0.2126, 0.7152, 0.0722);

float3 ufx_zoom_draw(float2 uv, float3 o, float2 sample_uv, int sid)
{
    float2 px = uv * BUFFER_SCREEN_SIZE;
    float2 sample_px = sample_uv * BUFFER_SCREEN_SIZE;
    float2 origin = float2(0.0, 0.0);
    float2 src_uv = float2(0.0, 0.0);
    float2 orig_px = float2(0.0, 0.0);
    float3 cell = float3(0.0, 0.0, 0.0);
    float3 center_c = float3(0.0, 0.0, 0.0);
    float lum = 0.0;
    int ipx = 0;
    int ipy = 0;
    int ox = 0;
    int oy = 0;
    int lx = 0;
    int ly = 0;
    int sx = 0;
    int sy = 0;
    int src_x = 0;
    int src_y = 0;
    int cx = 0;
    int cy = 0;
    int x0 = 0;
    int y0 = 0;
    int x1 = 0;
    int y1 = 0;
    int on_xhair = 0;
    int inner_w = UNIQ_UI_ZOOM_TW * UNIQ_UI_ZOOM_SCALE;
    int inner_h = UNIQ_UI_ZOOM_TH * UNIQ_UI_ZOOM_SCALE;
    int ow = (int)UNIQ_UI_ORIG.x;
    int oh = (int)UNIQ_UI_ORIG.y;

    origin = ufx_zoom_origin(sample_px);
    orig_px = ufx_uv_to_orig_px(sample_uv);
    ipx = (int)floor(px.x);
    ipy = (int)floor(px.y);
    ox = (int)origin.x;
    oy = (int)origin.y;
    if(ipx >= ox && ipy >= oy && ipx < ox + UNIQ_UI_ZOOM_W && ipy < oy + UNIQ_UI_ZOOM_H)
    {
        if(ipx < ox + UNIQ_UI_ZOOM_BORDER || ipy < oy + UNIQ_UI_ZOOM_BORDER || ipx >= ox + UNIQ_UI_ZOOM_W - UNIQ_UI_ZOOM_BORDER || ipy >= oy + UNIQ_UI_ZOOM_H - UNIQ_UI_ZOOM_BORDER)
            o = float3(0.50, 0.50, 0.55);
        else
        {
            lx = ipx - ox - UNIQ_UI_ZOOM_BORDER;
            ly = ipy - oy - UNIQ_UI_ZOOM_BORDER;
            if(lx < 0 || ly < 0 || lx >= inner_w || ly >= inner_h)
                o = float3(0.0, 0.0, 0.0);
            else
            {
                sx = (int)((uint)lx / (uint)UNIQ_UI_ZOOM_SCALE);
                sy = (int)((uint)ly / (uint)UNIQ_UI_ZOOM_SCALE);
                cx = (int)orig_px.x;
                cy = (int)orig_px.y;
                src_x = cx - UNIQ_UI_ZOOM_CX + sx;
                src_y = cy - UNIQ_UI_ZOOM_CY + sy;
                if(src_x < 0 || src_y < 0 || src_x >= ow || src_y >= oh)
                    cell = float3(0.0, 0.0, 0.0);
                else
                {
                    src_uv = ufx_orig_to_uv(float2((float)src_x, (float)src_y));
                    cell = saturate(ufx_store(src_uv, sid));
                }
                o = cell;

                center_c = saturate(ufx_store(ufx_orig_to_uv(float2((float)cx, (float)cy)), sid));
                lum = dot(center_c, UNIQ_UI_LUMA);
                x0 = UNIQ_UI_ZOOM_CX * UNIQ_UI_ZOOM_SCALE;
                y0 = UNIQ_UI_ZOOM_CY * UNIQ_UI_ZOOM_SCALE;
                x1 = x0 + UNIQ_UI_ZOOM_SCALE;
                y1 = y0 + UNIQ_UI_ZOOM_SCALE;
                if(lx >= x0 - 1 && lx <= x1 && ly >= y0 - 1 && ly <= y1)
                {
                    if(lx == x0 - 1 || lx == x1 || ly == y0 - 1 || ly == y1)
                        on_xhair = 1;
                }
                if(on_xhair)
                {
                    if(lum > 0.55)
                        o = float3(0.05, 0.05, 0.05);
                    else
                        o = float3(1.00, 1.00, 1.00);
                }
            }
        }
    }
    return o;
}

float3 ufx_overlay(float2 uv, float3 o)
{
    bool show = false;
    int sid = 0;
    float4 s0 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s1 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s2 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s3 = float4(0.0, 0.0, 0.0, 0.0);
    float2 panel = float2(0.0, 0.0);
    float2 muv = float2(0.0, 0.0);
    float2 disp_uv = float2(0.0, 0.0);
    float3 disp_c = float3(0.0, 0.0, 0.0);
    float disp_d = 0.0;
    float md = 0.0;
    float sd = 0.0;
    float hold = 0.0;
    float frozen = 0.0;
    bool ready = false;
    show = ufx_wants_sampler();
    if(show)
    {
        s0 = ufx_state(0);
        s1 = ufx_state(1);
        s2 = ufx_state(2);
        s3 = ufx_state(3);
        ready = ufx_state_ready(s0.w);
        panel = ready ? s0.xy : UI_PANEL_POS;
        muv = ufx_sample_uv();
        sid = ufx_ckpt_probe();
        hold = ready ? s1.w : 0.0;
        frozen = ready ? s2.a : 0.0;
        if(frozen > 0.5)
        {
            disp_uv = s3.xy;
            disp_c = saturate(s2.rgb);
            disp_d = s3.w;
        }
        md = length((uv - muv) * BUFFER_SCREEN_SIZE);
        o = ufx_panel_draw(uv, o, panel, disp_c, disp_uv, disp_d, frozen, hold, ready ? s0.z : 0.0, sid);
        if(frozen > 0.5)
        {
            sd = length((uv - ufx_orig_to_uv(s3.xy)) * BUFFER_SCREEN_SIZE);
            o = lerp(o, UNIQ_UI_COL_FRZ, 1.0 - smoothstep(2.5, 4.5, sd));
        }
        o = lerp(o, (hold >= UI_HOLD_MS) ? UNIQ_UI_COL_PROBE : UNIQ_UI_COL_CUR, 1.0 - smoothstep(2.0, 3.5, md));
    }
    return o;
}

float3 ufx_zoom_top(float2 uv, float3 o)
{
    float4 s0 = float4(0.0, 0.0, 0.0, 0.0);
    float4 s1 = float4(0.0, 0.0, 0.0, 0.0);
    float2 muv = float2(0.0, 0.0);
    int sid = 0;
    if(UI_SHOW_ZOOM && !ufx_is_combined_view())
    {
        s0 = ufx_state(0);
        s1 = ufx_state(1);
        if(ufx_state_ready(s0.w) && s1.w >= UI_HOLD_MS)
        {
            muv = ufx_sample_uv();
            sid = ufx_ckpt_probe();
            o = ufx_zoom_draw(uv, o, muv, sid);
        }
    }
    return o;
}

float3 ufx_debug_view(float2 uv, float3 o)
{
    if(UI_VIEW == UNIQ_UI_VIEW_MASK)
        o = ufx_mask(uv).xxx;
    else if(UI_VIEW == UNIQ_UI_VIEW_MASK_CKPT)
        o = ufx_mask_ckpt(uv).xxx;
    else if(UI_VIEW == UNIQ_UI_VIEW_SETUP || UI_VIEW == UNIQ_UI_VIEW_CKPT)
        o = ufx_store(uv, ufx_ckpt_probe());
    else if(UI_VIEW == UNIQ_UI_VIEW_DEPTH)
        o = saturate(ReShade::GetLinearizedDepth(uv)).xxx;
    return o;
}

float3 ufx_combined_color(float2 uv)
{
    float2 cuv = ufx_quad_uv(uv);
    int q = ufx_quad_id(uv);
    float3 o = float3(0.0, 0.0, 0.0);
    [branch]
    if(q == 0)
        o = tex2Dlod(ReShade::BackBuffer, float4(cuv, 0, 0)).rgb;
    else if(q == 1)
        o = ufx_store(cuv, ufx_ckpt_probe());
    else if(q == 2)
        o = saturate(ReShade::GetLinearizedDepth(cuv)).xxx;
    else
        o = ufx_mask(cuv).xxx;
    return o;
}

float3 ufx_hud_chrome(float2 uv, float3 o)
{
    o = ufx_overlay(uv, o);
    if((ufx_is_setup_view() || ufx_is_combined_view()) && UI_SHOW_LEGEND != UNIQ_UI_LEGEND_OFF)
        o = ufx_legend_draw(uv, o);
    return o;
}
#endif

/*=============================================================================
	Passes
=============================================================================*/

float4 PS_EvalA(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    int b = (int)pos.x;
    int c = (int)pos.y;
    float4 r = float4(-1.0, 0.0, 0.0, 0.0);
    if(b < 0 || b > 4)
        discard;
    [branch]
    if(b == 0)
        r = ufx_pack_box1(c);
    UNIQ_UI_EACH_BOX_A_TAIL(UNIQ_UI_EVAL_CASE)
    return r;
}

#if UNIQ_UI_BOX_COUNT >= 6
float4 PS_EvalB(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    int b = (int)pos.x;
    int c = (int)pos.y;
    float4 r = float4(-1.0, 0.0, 0.0, 0.0);
    if(b < 5 || b > 9)
        discard;
    [branch]
    if(b == 5)
        r = ufx_pack_box6(c);
    UNIQ_UI_EACH_BOX_B_TAIL(UNIQ_UI_EVAL_CASE)
    return r;
}
#endif

#if UNIQ_UI_BOX_COUNT >= 11
float4 PS_EvalC(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    int b = (int)pos.x;
    int c = (int)pos.y;
    float4 r = float4(-1.0, 0.0, 0.0, 0.0);
    if(b < 10 || b > 14)
        discard;
    [branch]
    if(b == 10)
        r = ufx_pack_box11(c);
    UNIQ_UI_EACH_BOX_C_TAIL(UNIQ_UI_EVAL_CASE)
    return r;
}
#endif

float4 PS_EvalOn(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    int b = (int)pos.x;
    float on = 0.0;
    float skipped = 0.0;
#if UNIQ_UI_CONDITIONS >= 2
    on = ufx_eval_join(b, ufx_need_of(b));
#else
    on = ufx_eval_join(b, 1);
#endif
    skipped = ufx_skip_prev(b);
    return float4(on, skipped, 0.0, 1.0);
}

#if ENABLE_SETUP_MODE
#define UNIQ_UI_CKPT_HOLD \
    [branch] \
    if(UI_FREEZE_CHECKPOINTS) \
        discard;
#else
#define UNIQ_UI_CKPT_HOLD
#endif

#define UNIQ_UI_PS_CKPT_COPY(NAME, SAMP) \
float4 NAME(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target \
{ \
    float4 o = float4(0.0, 0.0, 0.0, 1.0); \
    UNIQ_UI_CKPT_HOLD \
    o = float4(tex2Dlod(SAMP, float4(uv, 0, 0)).rgb, 1.0); \
    return o; \
}

UNIQ_UI_PS_CKPT_COPY(PS_Save, ReShade::BackBuffer)
#if CHECKPOINT_FRAME_SMOOTHING >= 1
    #define UNIQ_UI_PS_H1(N) UNIQ_UI_PS_CKPT_COPY(PS_CopyStore##N, UNIQ_UI_Store##N##Point)
#else
    #define UNIQ_UI_PS_H1(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 2
    #define UNIQ_UI_PS_H2(N) UNIQ_UI_PS_CKPT_COPY(PS_CopyStore##N##Hist1, UNIQ_UI_Store##N##Hist1Point)
#else
    #define UNIQ_UI_PS_H2(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 3
    #define UNIQ_UI_PS_H3(N) UNIQ_UI_PS_CKPT_COPY(PS_CopyStore##N##Hist2, UNIQ_UI_Store##N##Hist2Point)
#else
    #define UNIQ_UI_PS_H3(N)
#endif
#define UNIQ_UI_PS_HISTS(N) UNIQ_UI_PS_H1(N) UNIQ_UI_PS_H2(N) UNIQ_UI_PS_H3(N)
UNIQ_UI_PS_HISTS(1)
#if UNIQ_UI_CHECKPOINTS >= 2
UNIQ_UI_PS_HISTS(2)
#endif
#if UNIQ_UI_CHECKPOINTS >= 3
UNIQ_UI_PS_HISTS(3)
#endif
#undef UNIQ_UI_PS_HISTS
#undef UNIQ_UI_PS_H1
#undef UNIQ_UI_PS_H2
#undef UNIQ_UI_PS_H3
#undef UNIQ_UI_PS_CKPT_COPY

#if UNIQ_UI_CHECKPOINTS >= 2
float4 PS_Ckpt2RestoreCh1(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 o = float4(0.0, 0.0, 0.0, 1.0);
    [branch]
    if(UI_CKPT2_RESTORE_CH1)
        o = float4(tex2Dlod(UNIQ_UI_Store1Point, float4(uv, 0, 0)).rgb, 1.0);
    else
        discard;
    return o;
}
#if UNIQ_UI_CHECKPOINTS >= 3
float4 PS_Ckpt3RestoreCh2(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 o = float4(0.0, 0.0, 0.0, 1.0);
    [branch]
    if(UI_CKPT3_RESTORE_CH2)
        o = float4(tex2Dlod(UNIQ_UI_Store2Point, float4(uv, 0, 0)).rgb, 1.0);
    else
        discard;
    return o;
}
#endif
#endif
#undef UNIQ_UI_CKPT_HOLD

#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
float4 PS_CopyState(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return tex2Dlod(UNIQ_UI_StatePoint, float4(uv, 0, 0));
}

float4 PS_UpdateState(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
#if ENABLE_SETUP_MODE
    float4 s0 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(0), 0, 0));
    float4 s1 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(1), 0, 0));
    float4 s2 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(2), 0, 0));
    float4 s3 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(3), 0, 0));
#endif
#if ENABLE_DEBUG_STATS
    float4 st0 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(UNIQ_UI_STATE_STATS_BASE), 0, 0));
    float4 st1 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(UNIQ_UI_STATE_STATS_BASE + 1), 0, 0));
#endif
    float2 mouse_uv = ufx_mouse_uv();
    bool lmb = UI_LMB;
    int slot = 0;
    float drag_move = 0.0;
#if ENABLE_SETUP_MODE
    float2 sample_uv = ufx_sample_uv();
    float2 size_uv = float2(UNIQ_UI_PANEL_W, UNIQ_UI_PANEL_H) * BUFFER_PIXEL_SIZE;
    float2 panel_max = max(float2(1.0, 1.0) - size_uv, float2(0.0, 0.0));
    bool ready = ufx_state_ready(s0.w);
    float2 panel = ready ? s0.xy : UI_PANEL_POS;
    float2 grab = ready ? s1.xy : float2(0.0, 0.0);
    float dragging = ready ? s0.z : 0.0;
    float prev_lmb = ready ? s1.z : 0.0;
    float hold = ready ? s1.w : 0.0;
    float3 cap_c = ready ? s2.rgb : float3(0.0, 0.0, 0.0);
    float valid = ready ? s2.a : 0.0;
    float2 cap_uv = ready ? s3.xy : float2(0.0, 0.0);
    float cap_d = ready ? s3.w : 0.0;
    int sid = ufx_ckpt_probe();
    bool show = ufx_wants_sampler();
    bool over = false;
#endif
#if ENABLE_DEBUG_STATS
    float4 st2 = tex2Dlod(UNIQ_UI_StatePrevPoint, float4(ufx_state_uv(UNIQ_UI_STATE_STATS_SCROLL), 0, 0));
    float4 bar = float4(0.0, 0.0, 0.0, 0.0);
    float2 stats_size = float2(0.0, 0.0);
    float2 stats_max = float2(0.0, 0.0);
    float2 stats = float2(0.0, 0.0);
    float2 stats_grab = st1.xy;
    float2 stats_px = float2(0.0, 0.0);
    float2 stats_p1 = float2(0.0, 0.0);
    float2 mouse_px = float2(0.0, 0.0);
    float stats_drag = st0.z;
    float stats_placed = 0.0;
    float view_h = 0.0;
    float scroll_max = 0.0;
    float scroll = st2.x;
    float prev_wheel = st2.y;
    float bar_mode = st2.z;
    float bar_grab = st2.w;
    float wheel = UI_WHEEL;
    float span = 0.0;
    bool over_stats = false;
    bool over_bar = false;
    bool over_thumb = false;
#if !ENABLE_SETUP_MODE
    float prev_lmb = st1.z;
#endif
    view_h = ufx_stats_view_h();
    scroll_max = ufx_stats_scroll_max();
    stats_size = float2(UNIQ_UI_STATS_W, view_h) * BUFFER_PIXEL_SIZE;
    stats_max = max(float2(1.0, 1.0) - stats_size, float2(0.0, 0.0));
    stats_placed = (st0.w > 0.5) ? 1.0 : 0.0;
    stats = (stats_placed > 0.5) ? st0.xy : ufx_stats_home();
    if(bar_mode < 0.25)
    {
        prev_wheel = wheel;
        bar_mode = 0.5;
    }
#endif

#if ENABLE_SETUP_MODE
    if(UI_PANEL_LOCK)
        panel = UI_PANEL_POS;
    over = show
        && mouse_uv.x >= panel.x && mouse_uv.y >= panel.y
        && mouse_uv.x <= panel.x + size_uv.x
        && mouse_uv.y <= panel.y + size_uv.y;
    if(UI_PANEL_LOCK)
        dragging = 0.0;
#endif
#if ENABLE_DEBUG_STATS
    if(UI_STATS_LOCK)
        stats = UI_STATS_POS;
    over_stats = mouse_uv.x >= stats.x && mouse_uv.y >= stats.y
        && mouse_uv.x <= stats.x + stats_size.x
        && mouse_uv.y <= stats.y + stats_size.y;
    if(UI_STATS_LOCK)
        stats_drag = 0.0;
    mouse_px = mouse_uv * BUFFER_SCREEN_SIZE;
    stats_px = stats * BUFFER_SCREEN_SIZE;
    stats_p1 = stats_px + float2(UNIQ_UI_STATS_W, view_h);
    bar = ufx_stats_bar(stats_px, stats_p1, clamp(scroll, 0.0, scroll_max));
    over_bar = (scroll_max > 0.5)
        && mouse_px.x >= bar.x && mouse_px.x <= stats_p1.x - 2.0
        && mouse_px.y >= bar.y && mouse_px.y <= stats_p1.y - 4.0;
    over_thumb = over_bar && mouse_px.y >= bar.z && mouse_px.y <= bar.z + bar.w;
#endif

    if(lmb && prev_lmb < 0.5)
    {
#if ENABLE_SETUP_MODE && ENABLE_DEBUG_STATS
        if(over_bar)
        {
            bar_mode = 1.0;
            stats_drag = 0.0;
            dragging = 0.0;
            if(over_thumb)
                bar_grab = mouse_px.y - bar.z;
            else
            {
                span = (stats_p1.y - 4.0 - bar.y) - bar.w;
                if(span < 1.0)
                    span = 1.0;
                scroll = clamp((mouse_px.y - bar.y - bar.w * 0.5) / span, 0.0, 1.0) * scroll_max;
                bar_grab = bar.w * 0.5;
            }
        }
        else if(over_stats && !UI_STATS_LOCK)
        {
            stats_drag = 0.5;
            stats_grab = mouse_uv - stats;
            dragging = 0.0;
            bar_mode = 0.5;
        }
        else if(over && show && !UI_PANEL_LOCK)
        {
            dragging = 0.5;
            grab = mouse_uv - panel;
            stats_drag = 0.0;
            bar_mode = 0.5;
        }
#elif ENABLE_DEBUG_STATS
        if(over_bar)
        {
            bar_mode = 1.0;
            stats_drag = 0.0;
            if(over_thumb)
                bar_grab = mouse_px.y - bar.z;
            else
            {
                span = (stats_p1.y - 4.0 - bar.y) - bar.w;
                if(span < 1.0)
                    span = 1.0;
                scroll = clamp((mouse_px.y - bar.y - bar.w * 0.5) / span, 0.0, 1.0) * scroll_max;
                bar_grab = bar.w * 0.5;
            }
        }
        else if(over_stats && !UI_STATS_LOCK)
        {
            stats_drag = 0.5;
            stats_grab = mouse_uv - stats;
            bar_mode = 0.5;
        }
#else
        if(over && show && !UI_PANEL_LOCK)
        {
            dragging = 0.5;
            grab = mouse_uv - panel;
        }
#endif
    }
    if(!lmb)
    {
#if ENABLE_SETUP_MODE
        dragging = 0.0;
#endif
#if ENABLE_DEBUG_STATS
        stats_drag = 0.0;
        if(bar_mode > 0.75)
            bar_mode = 0.5;
#endif
    }

#if ENABLE_SETUP_MODE
#if ENABLE_DEBUG_STATS
    if(show && lmb && dragging < 0.75 && stats_drag < 0.75 && bar_mode < 0.75)
#else
    if(show && lmb && dragging < 0.75)
#endif
    {
        if(prev_lmb < 0.5)
            hold = 0.0;
        hold += max(UI_FT, 1.0);
        if(hold >= UI_HOLD_MS)
        {
            cap_c = ufx_store(sample_uv, sid);
            cap_uv = ufx_sample_orig_px();
            cap_d = ReShade::GetLinearizedDepth(sample_uv);
            valid = 1.0;
        }
    }
    else
        hold = 0.0;
#endif

#if ENABLE_SETUP_MODE
    if(lmb && dragging > 0.25 && dragging < 0.75)
    {
        if(hold >= UI_HOLD_MS)
            dragging = 0.0;
        else
        {
            drag_move = length((mouse_uv - (panel + grab)) * BUFFER_SCREEN_SIZE);
            if(drag_move > UNIQ_UI_DRAG_SLOP)
                dragging = 1.0;
        }
    }
    if(dragging > 0.75)
        panel = mouse_uv - grab;
    panel = clamp(panel, float2(0.0, 0.0), panel_max);
#endif
#if ENABLE_DEBUG_STATS
    if(lmb && stats_drag > 0.25 && stats_drag < 0.75)
    {
#if ENABLE_SETUP_MODE
        if(hold >= UI_HOLD_MS)
            stats_drag = 0.0;
        else
        {
#endif
            drag_move = length((mouse_uv - (stats + stats_grab)) * BUFFER_SCREEN_SIZE);
            if(drag_move > UNIQ_UI_DRAG_SLOP)
                stats_drag = 1.0;
#if ENABLE_SETUP_MODE
        }
#endif
    }
    if(stats_drag > 0.75)
    {
        stats = mouse_uv - stats_grab;
        stats_placed = 1.0;
    }
    stats = clamp(stats, float2(0.0, 0.0), stats_max);
    stats_px = stats * BUFFER_SCREEN_SIZE;
    stats_p1 = stats_px + float2(UNIQ_UI_STATS_W, view_h);
    over_stats = mouse_uv.x >= stats.x && mouse_uv.y >= stats.y
        && mouse_uv.x <= stats.x + stats_size.x
        && mouse_uv.y <= stats.y + stats_size.y;
    if(lmb && bar_mode > 0.75)
    {
        span = (stats_p1.y - 8.0) - bar.w;
        if(span < 1.0)
            span = 1.0;
        scroll = clamp((mouse_px.y - bar_grab - (stats_px.y + 4.0)) / span, 0.0, 1.0) * scroll_max;
    }
    if(over_stats && bar_mode < 0.75 && stats_drag < 0.75)
        scroll = scroll - (wheel - prev_wheel) * UNIQ_UI_STATS_WHEEL;
    prev_wheel = wheel;
    if(scroll < 0.0)
        scroll = 0.0;
    if(scroll > scroll_max)
        scroll = scroll_max;
#endif

#if ENABLE_SETUP_MODE
    if(valid > 0.5 && abs(s3.z - (float)sid) > 0.25)
        cap_c = ufx_store(ufx_orig_to_uv(cap_uv), sid);
#endif

    slot = clamp((int)floor(uv.x * (float)UNIQ_UI_STATE_N), 0, UNIQ_UI_STATE_N - 1);
#if ENABLE_SETUP_MODE
    if(slot == 0)
        return float4(panel, dragging, UNIQ_UI_STATE_MAGIC);
    if(slot == 1)
        return float4(grab, lmb ? 1.0 : 0.0, hold);
    if(slot == 2)
        return float4(cap_c, valid);
    if(slot == 3)
        return float4(cap_uv, (float)sid, cap_d);
#endif
#if ENABLE_DEBUG_STATS
    if(slot == UNIQ_UI_STATE_STATS_BASE)
        return float4(stats, stats_drag, stats_placed);
    if(slot == UNIQ_UI_STATE_STATS_BASE + 1)
    {
#if ENABLE_SETUP_MODE
        return float4(stats_grab, 0.0, 1.0);
#else
        return float4(stats_grab, lmb ? 1.0 : 0.0, 1.0);
#endif
    }
    return float4(scroll, prev_wheel, bar_mode, bar_grab);
#else
    return float4(cap_uv, (float)sid, cap_d);
#endif
}
#endif

float4 PS_Restore(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    float cov = 0.0;
    float ft = 0.0;
    float m = 0.0;
    float4 er = float4(0.0, 0.0, 0.0, 0.0);
    float4 boxst = float4(0.0, 0.0, 0.0, 0.0);

#if ENABLE_SETUP_MODE
    [branch]
    if(UI_VIEW == UNIQ_UI_VIEW_NONE || UI_VIEW == UNIQ_UI_VIEW_COMBINED)
    {
#endif

    [branch]
    if(UI_STRENGTH > 0.0)
    {
        [branch]
        if(UI_INV_MASK)
        {
            m = ufx_mask(uv);
            cov = (1.0 - m) * UI_STRENGTH;
            if(cov > 0.0)
                o = lerp(o, ufx_store(uv, UI_INV_MASK_STORE), cov);
        }
        else
        {
            UNIQ_UI_EACH_BOX(UNIQ_UI_RESTORE)
        }
    }
#if ENABLE_SETUP_MODE
    }
#endif
    return float4(o, processed.a);
}

#if ENABLE_SETUP_MODE
float4 PS_SetupA(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 suv = uv;
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    [branch]
    if(UI_VIEW == UNIQ_UI_VIEW_COMBINED)
        o = ufx_combined_color(uv);
    else
        o = ufx_debug_view(uv, o);
    [branch]
    if(ufx_setup_use_layers(suv))
    {
        uv = suv;
        UNIQ_UI_SETUP_LAYERS(UNIQ_UI_EACH_BOX_A)
    }
    return float4(o, processed.a);
}

#if UNIQ_UI_BOX_COUNT >= 6
float4 PS_SetupB(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 suv = uv;
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    [branch]
    if(ufx_setup_use_layers(suv))
    {
        uv = suv;
        UNIQ_UI_SETUP_LAYERS(UNIQ_UI_EACH_BOX_B)
    }
    return float4(o, processed.a);
}
#endif

#if UNIQ_UI_BOX_COUNT >= 11
float4 PS_SetupC(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 suv = uv;
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    [branch]
    if(ufx_setup_use_layers(suv))
    {
        uv = suv;
        UNIQ_UI_SETUP_LAYERS(UNIQ_UI_EACH_BOX_C)
    }
    return float4(o, processed.a);
}
#endif

float4 PS_Overlay(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    o = ufx_hud_chrome(uv, o);
#if !ENABLE_DEBUG_STATS
    o = ufx_zoom_top(uv, o);
#endif
    return float4(o, processed.a);
}

#if ENABLE_DEBUG_STATS
float4 PS_Zoom(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 processed = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0));
    float3 o = processed.rgb;
    o = ufx_zoom_top(uv, o);
    return float4(o, processed.a);
}
#endif
#endif

#if ENABLE_DEBUG_STATS
float4 PS_StatsA(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    UNIQ_UI_STATS_HEAD
    if(px.x >= p0.x && px.y >= p0.y && px.x <= p1.x && px.y <= p1.y)
    {
        scroll = ufx_stats_scroll();
        o = ufx_stats_fill(uv, o, p0, p1);
        if(px.y >= p0.y + 2.0 && px.y <= p1.y - 2.0)
        {
            bid = (int)((px.y - p0.y - UNIQ_UI_STATS_PAD + scroll) / block_h);
            [branch]
            if(bid == 0)
            {
                UNIQ_UI_STATS_LOAD(1);
            }
            UNIQ_UI_EACH_BOX_A_TAIL(UNIQ_UI_STATS_CASE)
            UNIQ_UI_STATS_APPLY
        }
        o = ufx_stats_scrollbar(uv, o, p0, p1);
    }
    return float4(o, processed.a);
}

#if UNIQ_UI_BOX_COUNT >= 6
float4 PS_StatsB(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    UNIQ_UI_STATS_HEAD
    if(px.x >= p0.x && px.y >= p0.y && px.x <= p1.x && px.y <= p1.y)
    {
        scroll = ufx_stats_scroll();
        if(px.y >= p0.y + 2.0 && px.y <= p1.y - 2.0)
        {
            bid = (int)((px.y - p0.y - UNIQ_UI_STATS_PAD + scroll) / block_h);
            [branch]
            if(bid == 5)
            {
                UNIQ_UI_STATS_LOAD(6);
            }
            UNIQ_UI_EACH_BOX_B_TAIL(UNIQ_UI_STATS_CASE)
            UNIQ_UI_STATS_APPLY
        }
        o = ufx_stats_scrollbar(uv, o, p0, p1);
    }
    return float4(o, processed.a);
}
#endif

#if UNIQ_UI_BOX_COUNT >= 11
float4 PS_StatsC(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    UNIQ_UI_STATS_HEAD
    if(px.x >= p0.x && px.y >= p0.y && px.x <= p1.x && px.y <= p1.y)
    {
        scroll = ufx_stats_scroll();
        if(px.y >= p0.y + 2.0 && px.y <= p1.y - 2.0)
        {
            bid = (int)((px.y - p0.y - UNIQ_UI_STATS_PAD + scroll) / block_h);
            [branch]
            if(bid == 10)
            {
                UNIQ_UI_STATS_LOAD(11);
            }
            UNIQ_UI_EACH_BOX_C_TAIL(UNIQ_UI_STATS_CASE)
            UNIQ_UI_STATS_APPLY
        }
        o = ufx_stats_scrollbar(uv, o, p0, p1);
    }
    return float4(o, processed.a);
}
#endif
#endif

/*=============================================================================
	Techniques
=============================================================================*/

#define UNIQ_UI_PASS(NAME, PS) \
    pass NAME \
    { \
        VertexShader = PostProcessVS; \
        PixelShader = PS; \
    }
#define UNIQ_UI_PASS_RT(NAME, PS, RT) \
    pass NAME \
    { \
        VertexShader = PostProcessVS; \
        PixelShader = PS; \
        RenderTarget = RT; \
    }
#define UNIQ_UI_PASS_KEEP(NAME, PS, RT) \
    pass NAME \
    { \
        VertexShader = PostProcessVS; \
        PixelShader = PS; \
        RenderTarget = RT; \
        ClearRenderTargets = false; \
    }
#define UNIQ_UI_PASS_HOLD(NAME, PS) \
    pass NAME \
    { \
        VertexShader = PostProcessVS; \
        PixelShader = PS; \
        ClearRenderTargets = false; \
    }
#if CHECKPOINT_FRAME_SMOOTHING >= 3
    #define UNIQ_UI_CKPT_SHIFT3(N) UNIQ_UI_PASS_KEEP(ShiftHist3, PS_CopyStore##N##Hist2, UNIQ_UI_Store##N##Hist3Tex)
#else
    #define UNIQ_UI_CKPT_SHIFT3(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 2
    #define UNIQ_UI_CKPT_SHIFT2(N) UNIQ_UI_PASS_KEEP(ShiftHist2, PS_CopyStore##N##Hist1, UNIQ_UI_Store##N##Hist2Tex)
#else
    #define UNIQ_UI_CKPT_SHIFT2(N)
#endif
#if CHECKPOINT_FRAME_SMOOTHING >= 1
    #define UNIQ_UI_CKPT_SHIFT1(N) UNIQ_UI_PASS_KEEP(ShiftHist1, PS_CopyStore##N, UNIQ_UI_Store##N##Hist1Tex)
#else
    #define UNIQ_UI_CKPT_SHIFT1(N)
#endif
#define UNIQ_UI_CKPT_SAVE(N) UNIQ_UI_PASS_KEEP(Save, PS_Save, UNIQ_UI_Store##N##Tex)
#define UNIQ_UI_CKPT_PASSES(N) \
    UNIQ_UI_CKPT_SHIFT3(N) \
    UNIQ_UI_CKPT_SHIFT2(N) \
    UNIQ_UI_CKPT_SHIFT1(N) \
    UNIQ_UI_CKPT_SAVE(N)

technique UniqFX_ConditionalUIMask_Checkpoint1
<
    ui_label = "UniqFX: Conditional UI Mask [Checkpoint 1]";
    ui_tooltip =
        "Captures the current frame.\n"
        "Place first, or after effects you want in this snapshot.";
>
{
    UNIQ_UI_CKPT_PASSES(1)
}

#if UNIQ_UI_CHECKPOINTS >= 2
technique UniqFX_ConditionalUIMask_Checkpoint2
<
    ui_label = "UniqFX: Conditional UI Mask [Checkpoint 2]";
    ui_tooltip =
        "Captures the current frame. Place after more effects.\n"
        "Place after effects you want in this snapshot.";
>
{
    UNIQ_UI_CKPT_PASSES(2)
    UNIQ_UI_PASS_HOLD(RestorePrev, PS_Ckpt2RestoreCh1)
}
#endif

#if UNIQ_UI_CHECKPOINTS >= 3
technique UniqFX_ConditionalUIMask_Checkpoint3
<
    ui_label = "UniqFX: Conditional UI Mask [Checkpoint 3]";
    ui_tooltip =
        "Captures the current frame. Place after more effects.\n"
        "Place after effects you want in this snapshot.";
>
{
    UNIQ_UI_CKPT_PASSES(3)
    UNIQ_UI_PASS_HOLD(RestorePrev, PS_Ckpt3RestoreCh2)
}
#endif

technique UniqFX_ConditionalUIMask_Restore
<
    ui_label = "UniqFX: Conditional UI Mask [Restore]";
    ui_tooltip =
        "Place after ALL checkpoint passes.\n"
        "Allows to setup multiple backbuffer checkpoints\n"
        "and restore them on given UI boxes using conditional\n"
        "comparisons of colors and depths at given samples.\n"
        "For more details check help after enabling this effect.";
>
{
#if ENABLE_SETUP_MODE || ENABLE_DEBUG_STATS
    UNIQ_UI_PASS_RT(CopyState, PS_CopyState, UNIQ_UI_StatePrevTex)
    UNIQ_UI_PASS_RT(UpdateState, PS_UpdateState, UNIQ_UI_StateTex)
#endif
    UNIQ_UI_PASS_RT(EvalA, PS_EvalA, UNIQ_UI_EvalTex)
#if UNIQ_UI_BOX_COUNT >= 6
    UNIQ_UI_PASS_KEEP(EvalB, PS_EvalB, UNIQ_UI_EvalTex)
#endif
#if UNIQ_UI_BOX_COUNT >= 11
    UNIQ_UI_PASS_KEEP(EvalC, PS_EvalC, UNIQ_UI_EvalTex)
#endif
    UNIQ_UI_PASS_RT(EvalOn, PS_EvalOn, UNIQ_UI_EvalOnTex)
    UNIQ_UI_PASS(Restore, PS_Restore)
#if ENABLE_SETUP_MODE
    UNIQ_UI_PASS(SetupA, PS_SetupA)
#if UNIQ_UI_BOX_COUNT >= 6
    UNIQ_UI_PASS(SetupB, PS_SetupB)
#endif
#if UNIQ_UI_BOX_COUNT >= 11
    UNIQ_UI_PASS(SetupC, PS_SetupC)
#endif
    UNIQ_UI_PASS(Overlay, PS_Overlay)
#endif
#if ENABLE_DEBUG_STATS
    UNIQ_UI_PASS(StatsA, PS_StatsA)
#if UNIQ_UI_BOX_COUNT >= 6
    UNIQ_UI_PASS(StatsB, PS_StatsB)
#endif
#if UNIQ_UI_BOX_COUNT >= 11
    UNIQ_UI_PASS(StatsC, PS_StatsC)
#endif
#endif
#if ENABLE_SETUP_MODE && ENABLE_DEBUG_STATS
    UNIQ_UI_PASS(Zoom, PS_Zoom)
#endif
}
