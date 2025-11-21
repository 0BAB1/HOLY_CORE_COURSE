**The goal is to maximise FPS on DOOM.**

With the shitty cache from last editions as instruction cache, we are able to go up to 0.5 FPS (a notable boost from the 0.25 without any cache).

Then, when using it as data cache as well, simulaition tells us the number of stalls is horrific, which was expected as writing back and re fetching 128 words everytime we want to store / read, it gets bad pretty darn fast.

And on FPGA, the ata cache cretes rare edge cases that simply makes doom non raunnable.

Instead of trryning to fix this using duct tape, the moment has come to make a direct decision :

**We shall re-do the cache system. And design it to be robust.**, Once and for all. This is the first pareto-optimal modification as simulation reports show that **~65%** of the time is spent **stalling**( because we need AXI to access the DRAM large enough to fit large programs like DOOM) !!! Then we'll focus on other important improvements, like pipelinning and adding beter hardware support.

Here is the road map :

- Set the old "data cache" (which is just a dumb AXI Burst 128 words fetcher / write backer) to "instruction" cache.
  - The reason why is it's perfect for an instrction caches, and already proved to double perfs in DOOM !
  - We'll also reduce the number of word it fetches from 128 to... something else, we'll see on the spot. But 128 is way to much !
  - We'll do this whilst disbling the data cache completely.
- Once this new cache is in place, and that we technically have no data cache anymore, we'll create a new data cache
  - We'll go with a 8 sets and 2 way data cache with 16 words blocks, totalling 256 words, i.e. a 1KB cache
  - This is pretty heavy so we'll make it optionnal of course
  - The goal will also be to re-design the CPU / cache interface, with future pipelinning optimizations in mind, as just outputting a stall signal is producing too many edge cases so far.


So firt, let's think about this new "interface".  So far, the caches proced a "stall" signal, which blocked the entire core. This creates tons of edge cases when we introduce the idea of havin a non cachable range as we need to not stall until the next request, but what defines a "request" ? the only way to signal the cache we want to R/W is through the R/W enable but the cache has no idea of whether the core will grab the data now or later... right now .

Let's see... what we want is a way to signal the fact that we are requesting data, and signal when the request id over to go to the next request... Well, we can use a handshake signal ! But his introduces a 1 cycle delay that we would gmadly avoid... What we wanty is an async read if the data is there and ready to go... What we can do then is a 1 cycle handshake, were the IDLE state assert the valid by default but sets it low if it's nit, kinda like a busy flag... Like a stall flag... Wait, are we running in circles ?

