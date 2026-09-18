# UniqFX
My shader collection for [ReShade](https://reshade.me).

 * [Conditional UI Mask](#conditional-ui-mask)
 * [FakeBumpMap](#fakebumpmap)
 * [Demake](#demake)
 * [Depth Blur [DoF]](#depth-blur-dof)

## Conditional UI Mask

Complex solution for UI masking in ReShade.
Allows to setup multiple backbuffer checkpoints and restore them on given UI boxes using conditional comparisons of colors and depths at given samples.

Features:
* Multiple UI masks displayed based on conditions
* Multiple matchers for color and depth
* Multiple backbuffer checkpoints to restore data from
* In-game setup UI for simplified usage - use setup and debug view to preview all important details
* Automatic scaling of created presets - game resolution no longer matters

### Combined debug view

https://github.com/user-attachments/assets/65a27929-62a5-469e-a2b5-e8c320c755d4

### In game sampling

<p align="center">
  <img src="https://github.com/dwojtasik/SliderCompareHtml/blob/main/assets/UniqFX/ConditionalUIMask/sampling.gif?raw=true" width="50%"/>
</p>

## FakeBumpMap

Relights large planes with a textured normal and extrudes surfaces fragments by pixel walk.

* Requires [iMMERSE](https://github.com/martymcmodding/iMMERSE) shaders installed
* Supports multiple textured normals providers:
  * [iMMERSE: Launchpad](https://github.com/martymcmodding/iMMERSE) with Smoothed + Textured Normal Map Mode
    * recommended provider as it offers better results
  * [LUMENITE Kernel 2.0](https://github.com/umar-afzaal/LumeniteFX) with SMOOTH_NORMALS=1
    * requries Large Planes Only <= 1.0

### Comparison (click to open slider view)

<table>
  <tr>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_2_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_2_a.jpg&r_label=UniqFX:%20FakeBumpMap">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_2_a.jpg" width="100%" alt="Bricks">
      </a>
      <br>
      <b>Bricks</b>
    </td>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_1_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_1_a.jpg&r_label=UniqFX:%20FakeBumpMap">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_1_a.jpg" width="100%" alt="Wall">
      </a>
      <br>
      <b>Wall</b>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_3_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_3_a.jpg&r_label=UniqFX:%20FakeBumpMap">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_3_a.jpg" width="100%" alt="Bamboo">
      </a>
      <br>
      <b>Bamboo</b>
    </td>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_4_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_4_a.jpg&r_label=UniqFX:%20FakeBumpMap">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/FakeBumpMap/scct_4_a.jpg" width="100%" alt="Tiles">
      </a>
      <br>
      <b>Tiles</b>
    </td>
  </tr>
</table>

## Demake

Simplifies graphics to achieve visuals of game demake by:
* scaling output into low-resolution and back
* limiting color pallete and applying dithering
* old-hardware depth fog
* flatten lighting, blocky shadows and reduced specular gloss
* merging nearby high-poly faces (based on depth and normal) into one shared plane that fakes low-poly geometry
* fake distance LOD (minified textures, flatter lighting, coarser vertices)
* snapping and jittering face intersections like PS1 vertices
* pixelating & bluring textures

### Comparison (click to open slider view)

<table>
  <tr>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_1_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_1_a.jpg&r_label=UniqFX:%20Demake">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_1_a.jpg" width="100%" alt="Demake 1">
      </a>
    </td>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_2_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_2_a.jpg&r_label=UniqFX:%20Demake">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_2_a.jpg" width="100%" alt="Demake 2">
      </a>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_3_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_3_a.jpg&r_label=UniqFX:%20Demake">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_3_a.jpg" width="100%" alt="Demake 3">
      </a>
    </td>
    <td width="50%" align="center">
      <a href="https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_4_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_4_a.jpg&r_label=UniqFX:%20Demake">
        <img src="https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/Demake/scct_4_a.jpg" width="100%" alt="Demake 4">
      </a>
    </td>
  </tr>
</table>

## Depth Blur [DoF]

Separable Gaussian blur that follows linearized depth with autofocus option.

### Comparison (click to open slider view)

[![DepthBlur SCCT](https://github.com/dwojtasik/SliderCompareHtml/blob/main/assets/UniqFX/DepthBlur/scct_1_a.jpg)](https://dwojtasik.github.io/SliderCompareHtml/?l_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/DepthBlur/scct_1_b.jpg&l_label=No%20effect&r_img=https://raw.githubusercontent.com/dwojtasik/SliderCompareHtml/refs/heads/main/assets/UniqFX/DepthBlur/scct_1_a.jpg&r_label=UniqFX:%20Depth%20Blur%20[DoF])
