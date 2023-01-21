+++
title = "Fishing for Dark Vessels with a U-Net"
description = "A rundown of my solution for the xView3[https://iuu.xview.us] competition to find dark fishing vessels in SAR satellite images."
date = 2023-01-21T13:37:08+00:00
draft = true

[taxonomies]
tags = ["machine learning", "julia"]

[extra]
author = "drsk"
subtitle = "Or How I took Julia on a Fishing Trip"
+++

During 2021, I stumbled upon a computer vision challenge called xView3
organized by the defense innovation unit [DIU](https://www.diu.mil/) and
[Global Fishing Watch](https://globalfishingwatch.org/). Then challenge was
about detecting fishing vessels with the help of synthetic aperture radar (SAR)
images and machine learning. You can read all about it on the official [xView3](https://iuu.xview.us/).

The cause was good, and so was the money for the winners. So I set sail for an
odyssey into computer vision, machine learning and huge satellite images. In
the end I missed the timeline to complete and hand in my solution in time. The
journey was worthwile nevertheless.

These are essentially my research notes of the project. You can find my
solution at [github](https://github.com/drsk0/xview).

***

| ![sar_plot.png](/assets/sar_plot.png) |
|:--:|
| <b><font size="-1">The vertical, horizontal and bathymetry bands of the SAR data together with the generated image for training.<font/> </b>|

***

My chief officer on deck[^1] was [Julia](https://julialang.org/), a fresh,
smart and fast computer language with an excellent deep learning framework
called [Flux](https://fluxml.ai/). Why Julia and not PyTorch, Tensorflow,
Kiras? There are thousands of articles praising Julia, and probably as many
damming it. My take as a functional programmer is that Julia currently is
close to a sweetspot of speed, functional features, ease of use and good math
libraries. Julia's REPL is a joy to use, has fuzzy history search and syntax
highlighting and has become my favorite tool for data analysis. The flux
framework features automatic differentiation and a plenatory of composable
building blocks to implement deep learning models very quickly.

Unsurprisingly, the crux of this project wasn't implementing the deep learning
model or training it. The crux was to deal and preprocess the huge amount
of data. Every single SAR image is around 1.5 GB in size. Even just for data
preprocessing, loading a full image leads to an out-of-memory exception fairly
quickly on my laptop.

For this reason, I decided to only work with the smallest training dataset
available, consisting of five scenes from different places on earth. For bigger
datasets, I would move my code to [juliahub](https://juliahub.com) and rent a
performant machine with plenty of memory and GPU's. However, for experimenting,
my laptop was just enough as long as I found a way to circumvent loading full
images in to memory. Also, I decided to only use the horizontal and vertical
bands of the SAR image together with the bathymetry data as a signal, reasoning
that the additional wind data would only lead to a minor improvement in the
detection, if at all. The bathymetry data, on the other side, would provide a
strong signal to distinguish sea from land features.

I used [Rasters](https://github.com/rafaqz/Rasters.jl) to load satellite
images in the `tif` file format. Loading all satellite images of a scene lazily
without sinking my laptop[^2] is simple:

```julia
rs = RasterStack(
        (
            x -> joinpath(fp, x)
        ).(["VV_dB.tif", "VH_dB.tif", "bathymetry_processed.tif"]);
        lazy=true)
```

The bathymetry data has a different resolution than the vertical and horizontal
bands. Therefore, I did resample the missing data during a preprocessing step
using linear interpolation.

```julia
open(Raster(joinpath(subDir, "bathymetry.tif"))) do gaBat
    gaBatPrim = resample(gaBat, to=gaV, method=:near)
    Rasters.write(joinpath(subDir, "bathymetry_processed.tif"), gaBatPrim)
end
```

The fishing vessels are tiny compared to the size of the full satellite image.
They are so small, it's almost impossible to spot them if you don't know where
to look. Hence, a fairly small neighborhood around the vessel should be enough
for the input signal of the object detection algorithm. I split the images into
hundreds of overlapping 128x128 pixel tiles with the help of [TiledIteration](https://github.com/JuliaArrays/TiledIteration.jl).
Then, I implemented a data loader to feed the training loop one randomly
selected tile after another.

```julia
    satData = dataDirs .|> fp -> getSatelliteData(fp, csv, tileSize)
    xtrain = MultipleSatelliteData([first(sd) for sd in satData])
    ytrain = MultipleSatelliteData([last(sd) for sd in satData])
    dataLoader = MLU.DataLoader(
        (xtrain, ytrain);
        collate=true,
        batchsize=batchSize,
        shuffle=true
    )
```

The tile size is a hyper-parameter of the model, the 128 pixels led to good
results. The model has a tendency for false positives at the boundaries of
the tiles. A possible solution would be to choose a big enough overlap for the
tiles and then only consider detected vessels in the interior of the tiles.

***

- UNet model architecture 
  - good in medical image segmentation
  - intuition that it should be capable of detecting small changes in the image structure
  - UNet is based on convolution/deconvolution in a encoder/decoder chain
  - compare to Transformer in the future, using attention instead
  - [UNet.jl](https://github.com/DhairyaLGandhi/UNet.jl)
- loss function
  - binary cross entropy
- activation function
  - sigmoid
- image
- flux training loop
  - optimiser ADAM
  - dataloader for lazy tile loading
- running on julia hub
  - gpu support
- results
  - accuracy history
  - f1 metric
  - f1 metric history


***

[^1]: I promise, no more ship talk after this.

[^2]: Oops, it's just too tempting.
