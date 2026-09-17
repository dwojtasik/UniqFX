/*=============================================================================
    UniqFX : Depth Blur [DoF]
    Version: 2026.09.17
    Author : Dominik Wojtasik
    License: MIT
    Source : https://github.com/dwojtasik/UniqFX

    Separable Gaussian blur. Kernel radius follows linearized depth:
    close = 0 (sharp), far = 1 (full blur).

    Autofocus mode samples depth at a UV look-point and treats that depth as
    sharp, then blurs linearly away from it.
=============================================================================*/

#include "ReShade.fxh"

/*=============================================================================
    UI
=============================================================================*/

uniform float UI_RADIUS <
    ui_type = "drag";
    ui_label = "Radius";
    ui_tooltip = "Gaussian radius in pixels at full strength.";
    ui_min = 0.0; ui_max = 64.0;
    ui_step = 0.5;
    ui_category = "Blur";
> = 12.0;

uniform int UI_QUALITY <
    ui_type = "combo";
    ui_label = "Quality";
    ui_items = "Fast (7 taps)\0Balanced (13 taps)\0High (21 taps)\0Ultra (31 taps)\0";
    ui_tooltip = "Samples per axis. Higher = smoother blur, more GPU cost.";
    ui_category = "Blur";
> = 1;

uniform bool UI_LINEAR <
    ui_label = "Blur In Linear Colour";
    ui_tooltip = "Convert to linear before blurring. Reduces dark fringes around highlights.";
    ui_category = "Blur";
> = true;

uniform float UI_NEAR <
    ui_type = "drag";
    ui_label = "Near (sharp)";
    ui_tooltip = "Without autofocus: linear depth at and below this stays sharp.\n"
                 "With autofocus: Near/Far span is how far from the focus plane full blur is reached.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.001;
    ui_category = "Depth";
> = 0.0;

uniform float UI_FAR <
    ui_type = "drag";
    ui_label = "Far (full blur)";
    ui_tooltip = "Without autofocus: linear depth at and above this gets full radius.\n"
                 "With autofocus: Near/Far span is how far from the focus plane full blur is reached.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.001;
    ui_category = "Depth";
> = 1.0;

uniform float UI_CURVE <
    ui_type = "drag";
    ui_label = "Curve";
    ui_tooltip = "Power on the 0-1 depth strength.\n"
                 "> 1 keeps mid-ground sharper.\n"
                 "< 1 starts blurring sooner.";
    ui_min = 0.1; ui_max = 8.0;
    ui_step = 0.05;
    ui_category = "Depth";
> = 1.0;

uniform float UI_EDGE <
    ui_type = "drag";
    ui_label = "Edge Keep";
    ui_tooltip = "Stops closer (sharper) pixels from bleeding into distant blur.\n"
                 "0 = off. Raise if silhouettes smear onto the background.";
    ui_min = 0.0; ui_max = 200.0;
    ui_step = 1.0;
    ui_category = "Depth";
> = 25.0;

uniform bool UI_AF_ON <
    ui_label = "Enabled";
    ui_tooltip = "Sample depth at Point Of View (UV) and treat that depth as sharp.\n"
                 "Everything else blurs linearly with depth distance from that plane.";
    ui_category = "Autofocus";
> = true;

uniform float2 UI_AF_POV <
    ui_type = "drag";
    ui_label = "Point Of View (UV)";
    ui_tooltip = "Screen point the camera is looking at. Depth here is the focus plane.\n"
                 "(0.0, 0.0) = top-left.\n"
                 "(0.5, 0.5) = center.\n"
                 "(1.0, 1.0) = bottom-right.";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.001;
    ui_category = "Autofocus";
> = float2(0.5, 0.5);

uniform float UI_AF_SPEED <
    ui_type = "drag";
    ui_label = "Adjust Speed (ms)";
    ui_tooltip = "How quickly the focus plane eases to a new look-at depth in milliseconds.\n"
                 "0 = instant.";
    ui_min = 0.0; ui_max = 5000.0;
    ui_step = 10.0;
    ui_category = "Autofocus";
> = 500.0;

uniform float UFX_DB_Frametime < source = "frametime"; >;

/*=============================================================================
    Textures
=============================================================================*/

texture UFX_DB_BlurTex
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler UFX_DB_BlurSamp
{
    Texture = UFX_DB_BlurTex;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DB_FocusTex
{
    Width = 1;
    Height = 1;
    Format = R32F;
};

sampler UFX_DB_FocusSamp
{
    Texture = UFX_DB_FocusTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

texture UFX_DB_FocusOldTex
{
    Width = 1;
    Height = 1;
    Format = R32F;
};

sampler UFX_DB_FocusOldSamp
{
    Texture = UFX_DB_FocusOldTex;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

/*=============================================================================
    Common
=============================================================================*/

int ufx_db_taps()
{
    if(UI_QUALITY >= 3)
        return 15;
    if(UI_QUALITY == 2)
        return 10;
    if(UI_QUALITY == 1)
        return 6;
    return 3;
}

float ufx_db_focus_depth()
{
    return tex2Dlod(UFX_DB_FocusSamp, float4(0.5, 0.5, 0, 0)).x;
}

float ufx_db_strength(float2 uv)
{
    float d = ReShade::GetLinearizedDepth(uv);
    float span = max(UI_FAR - UI_NEAR, 1e-6);
    float t;

    [branch]
    if(UI_AF_ON)
        t = saturate(abs(d - ufx_db_focus_depth()) / span);
    else
        t = saturate((d - UI_NEAR) / span);

    return pow(t, UI_CURVE);
}

float3 ufx_db_to_linear(float3 c)
{
    return UI_LINEAR ? pow(max(c, 0.0), 2.2) : c;
}

float3 ufx_db_to_gamma(float3 c)
{
    return UI_LINEAR ? pow(max(c, 0.0), 1.0 / 2.2) : c;
}

float ufx_db_sample_w(float center_d, float2 uv, float w)
{
    [branch]
    if(UI_EDGE <= 0.0)
        return w;

    float closer = max(center_d - ReShade::GetLinearizedDepth(uv), 0.0);
    return w * saturate(1.0 - closer * UI_EDGE);
}

float3 ufx_db_gaussian(sampler s, float2 uv, float2 axis, float radius, float center_d, bool src_linear)
{
    float3 center = tex2Dlod(s, float4(uv, 0, 0)).rgb;
    if(!src_linear)
        center = ufx_db_to_linear(center);

    float sigma = max(radius * 0.333333, 1e-3);
    int taps = ufx_db_taps();
    float3 acc = center;
    float wsum = 1.0;

    [loop]
    for(int i = 1; i <= taps; i++)
    {
        float x = radius * (float(i) / float(taps));
        float w = exp(-0.5 * (x / sigma) * (x / sigma));
        float2 off = axis * x;

        float2 uv_p = saturate(uv + off);
        float2 uv_n = saturate(uv - off);

        float3 c_p = tex2Dlod(s, float4(uv_p, 0, 0)).rgb;
        float3 c_n = tex2Dlod(s, float4(uv_n, 0, 0)).rgb;
        if(!src_linear)
        {
            c_p = ufx_db_to_linear(c_p);
            c_n = ufx_db_to_linear(c_n);
        }

        float w_p = ufx_db_sample_w(center_d, uv_p, w);
        float w_n = ufx_db_sample_w(center_d, uv_n, w);

        acc += c_p * w_p + c_n * w_n;
        wsum += w_p + w_n;
    }

    return acc / max(wsum, 1e-6);
}

/*=============================================================================
    Passes
=============================================================================*/

float4 PS_FocusCopy(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    return tex2Dlod(UFX_DB_FocusSamp, float4(0.5, 0.5, 0, 0));
}

float4 PS_FocusUpdate(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float target = ReShade::GetLinearizedDepth(saturate(UI_AF_POV));
    float prev = tex2Dlod(UFX_DB_FocusOldSamp, float4(0.5, 0.5, 0, 0)).x;
    float tau = max(UI_AF_SPEED, 0.0);
    float dt = max(UFX_DB_Frametime, 0.0);
    float a = (tau <= 0.0) ? 1.0 : (1.0 - exp(-dt / tau));
    return lerp(prev, target, saturate(a));
}

float4 PS_BlurH(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float strength = ufx_db_strength(uv);
    float radius = UI_RADIUS * strength;
    float3 orig = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0)).rgb;

    [branch]
    if(radius < 0.01)
        return float4(ufx_db_to_linear(orig), strength);

    float center_d = ReShade::GetLinearizedDepth(uv);
    float3 blurred = ufx_db_gaussian(ReShade::BackBuffer, uv, float2(BUFFER_PIXEL_SIZE.x, 0.0), radius, center_d, false);
    return float4(blurred, strength);
}

float4 PS_BlurV(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 h = tex2Dlod(UFX_DB_BlurSamp, float4(uv, 0, 0));
    float strength = h.a;
    float3 orig = tex2Dlod(ReShade::BackBuffer, float4(uv, 0, 0)).rgb;
    float radius = UI_RADIUS * strength;

    [branch]
    if(radius < 0.01)
        return float4(orig, 1.0);

    float center_d = ReShade::GetLinearizedDepth(uv);
    float3 blurred = ufx_db_gaussian(UFX_DB_BlurSamp, uv, float2(0.0, BUFFER_PIXEL_SIZE.y), radius, center_d, true);
    return float4(ufx_db_to_gamma(blurred), 1.0);
}

/*=============================================================================
    Technique
=============================================================================*/

technique UniqFX_DepthBlur
<
    ui_label = "UniqFX: Depth Blur [DoF]";
    ui_tooltip =
        "Gaussian blur whose radius follows linearized depth.\n"
        "Autofocus mode samples depth at a UV look-point and treats that depth as sharp,\n"
        "then blurs linearly away from it.";
>
{
    pass FocusCopy
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_FocusCopy;
        RenderTarget = UFX_DB_FocusOldTex;
    }
    pass FocusUpdate
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_FocusUpdate;
        RenderTarget = UFX_DB_FocusTex;
    }
    pass BlurH
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BlurH;
        RenderTarget = UFX_DB_BlurTex;
    }
    pass BlurV
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BlurV;
    }
}
