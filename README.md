# UniqFX
My shader collection for [ReShade](https://reshade.me).

## FakeBumpMap

Relights large planes with a textured normal and extrude surface fragemnts by pixel walk.

* Requires [iMMERSE](https://github.com/martymcmodding/iMMERSE) shaders installed
* Supports multiple textured normals providers:
  * [iMMERSE: Launchpad](https://github.com/martymcmodding/iMMERSE) with Smoothed + Textured Normal Map Mode
  * [LUMENITE Kernel 2.0](https://github.com/umar-afzaal/LumeniteFX) with SMOOTH_NORMALS=1
    * requries Large Planes Only <= 1.0

### Comparison

Splinter Cell Chaos Theory: [Bricks](https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_2_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_2_a.jpg&r_label=UniqFX:%20FakeBumpMap) | [Wall](https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_1_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_1_a.jpg&r_label=UniqFX:%20FakeBumpMap) | [Bamboo](https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_3_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_3_a.jpg&r_label=UniqFX:%20FakeBumpMap) | [Tiles](https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_4_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_4_a.jpg&r_label=UniqFX:%20FakeBumpMap)

![FakeBumpMap SCCT](https://github.com/dwojtasik/SliderCompareHtml/blob/main/assets/UniqFX/FakeBumpMap/scct_2_a.jpg)
