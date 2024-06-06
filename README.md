#  Metal Blend Pipelines

This project is an experiment to try several methods to blend many textures, a problem commonly found in drawing software.
It focuses on using Apple's Metal APIs in various ways: with fragment shaders, compute shaders or higher-level (but still Metal based) APIs like Core Image and Metal Petal.
A big motivation here has been to understand how Core Image could be so fast compared to basic usage of compute shaders, and whether it's possible to do better or as good, but without the downsides of Core Image. I was also curious to try Apple Silicon specific optimizations like tile memory usage.

The solution has to provide correct and pixel accurate image result, color managed and with at least 16f internal pixel format.
The different pipelines get compared in terms of speed and memory usage.

### Dataset and testing conditions

50 textures get blended then the result is displayed. Each one is RGBA, 8bits/sample, 4000x2000 pixels.
This data alone, common for all methods, uses ~1.5GB.
The blend operation is a basic `(background + foreground) / 1.1`.

The results listed below are generated on a 2021 MacBook Pro 14" with 32GB memory and M1 Pro Soc, 16 GPU cores, running macOS 14.5. Image result is displayed in a full size window on a UHD@144Hz display, making the Metal drawable 3840x1836 pixels.

## Pipelines

_Note: in all pipelines, the last output texture is the MTKView's drawable itself, so there's no additional command needed to display the result._

### Core Image framework

The simplest approach when you just want to think in terms of image composition graph with good flexilibility on the operations to perform. It is a rather efficient solution since Core Image will merge the operations as much as possible, reducing synchronization, memory latency and memory bandwidth issues. Unfortunately it also has a rather high memory usage, non-debuggable shaders and unpredictable stutters when it decides to optimize the rendering graph, as it involves compiling a new Metal shader at runtime.

The full image composition graph is generated, providing a single `CIImage`. This is then rendered through `CIContext.startTask()` which will encode all the rendering work in the provided `MTLCommandBuffer`.

### Compute (1 encoder, 1 dispatch/layer)

This is the most basic approach with Metal only. For each blend operation, a compute kernel is run, reading 1 pixel from 2 input textures, and writing the blended result to a 3rd output texture. This output is then the first input of the next blend operation, along with another layer's texture, and so on.

A single `MTLComputeCommandEncoder` is used, and each blend is done by a distinct `dispathThreads()` call.

### Render (1 encoder/layer, 1 draw/encoder)

Same as with above compute pipeline, except that a fragment shader is used instead of a compute kernel for each blend operation. Another difference is that one `MTLRenderCommandEncoder` **per blend operation** is used. Using a single `MTLRenderCommandEncoder` and 1 draw/blend gives random artifacts as one is not allowed to read & write to/from the same texture within a single render encoder. This happens as, starting from the 2nd layer to blend, the output texture of the 1st blend is the input of the 2nd blend, but the output on this 2nd blend operation is still the same output texture. The issue doesn't happen with `MTLComputeCommandEncoder`, most likely because the output texture is guaranteed to be fully written before the next pass is executed. This makes compute shaders more reliable but also slower due to the added synchronization.

### Render with tile memory (1 encoder, 1 draw/layer)

This one is a variation of the above render pipeline. However using tile memory implies using memoryless textures, which only "persist" within a single `MTLRenderCommandEncoder`. So we need to find a way not to run into the undefined behavior caused by reading & writing to the same texture. Documentation is lacking on the topic so I used best guess. What I ended up doing is using 2 memoryless textures, and swapping them on each subpass of the render encoder. So on the 2nd blend we read from `memoryless1` and `layer2`, and write to `memoryless2`. On the next blend we read from `memoryless2` and `layer3`, and write to `memoryless1`. I could not find yet documentation telling that this approach is well defined behavior, but on all devices I tried this gave correct and stable results.

### Render (1 encoder, 1 draw/layer)

Now successful in using a single `MTLRenderCommandEncoder` to blend the 50 layers, we can now use the same approach but without memoryless textures, to see how much the tile memory will actually affect the results.

### Compute (1 encoder, 1 dispatch/layer, 4 tiles)

After having tried render pipelines, let's get back to something closer to what Core Image is doing: a solution fully based on compute kernels. We found out that `MTLComputeCommandEncoder` allows us to use a single encoder out of the box because it guarantees dependencies between reads and writes of several dispatches. So let's try to allow Metal drivers to hide synchronization latency by running 4 fully independent pipelines, by splitting the output in 4 tiles, and only writing to a common `MTLTexture` in the final blend. This shoud allow the 4 pipeline to run in parallel, and one pipeline to move forward while the other waits on memory writes.

_Hint: this didn't help 🙃._

### Monolithic compute (1 encoder, 1 dispatch)

Since above approach didn't help, let's try to get even closer to what Core Image is doing: by blending all layers within a single compute kernel. This is not flexible at all but it'll still be interesting to know how this affects speed.

### Compute with threadgroup memory/imageblocks (1? encoder, 1? dispatch/layer)

_TODO_

### [Metal Petal framework](https://github.com/MetalPetal/MetalPetal)

This is a third-party framework very similar to Apple's Core Image. However it relies on fragment shaders in addition to compute kernels, and claims to be faster than Core Image.
The pipeline setup is almost identical to the one in Core Image, except for a few points:
- We don't need to (un)flip the output image
- The API makes it safer to work with unpremultiplied alpha textures
- We can't tell it to use our already existing `MTLCommandBuffer`. It will always create its own, from its own `MTLCommandQueue`. This prevents us from controlling how the Metal Petal shaders will be executed in the middle of our own Metal pipeline.

## Results

## Insights

sequential command buffers
drawable bottleneck

## Sources

[WWDC21: Create image processing apps powered by Apple Silicon](https://developer.apple.com/wwdc21/10153)
