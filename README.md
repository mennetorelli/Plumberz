# Intro
This project extends the research conducted by Luca Lodi and Philippe Scorsolini for the course of "Principles of Programming Languages" at Politecnico di Milano by prof. Matteo Pradella and with the supervision of Riccardo Tommasini. For more information, visit [their repository on GitHub](https://github.com/plumberz/plumberz.github.io)

While the previous research was focused on examining [Pipes](https://hackage.haskell.org/package/pipes) and [Tubes](https://hackage.haskell.org/package/tubes) libraries for stream processing in Haskell, this research focuses on the [Conduit](https://hackage.haskell.org/package/conduit) library.

# Conduit library
As the tutorial on the homepage of [Conduit's official reopsitory explains](https://github.com/snoyberg/conduit), Conduit is a framework for dealing with streaming data, which standardizes various interfaces for streams of data, and allows a consistent interface for transforming, manipulating, and consuming that data. The main benefits that Conduit provides are constant memory usage and deterministic resource usage.

Since Conduit deals with streams of data, such data flows through a pipeline, which is the main concept of Conduit. Each component of a pipeline can consume data from upstream, and produce data to send downstream. For instance, this is an example of a Conduit pipeline:

```haskell
runConduit $ yieldMany [1..10] .| mapC show .| mapM_C print
```

Each component of the pipeline consumes a stream of data from upstream, and produces a stream of data to be sent downstream. For instance, from the perspecive of `mapC show`, `yieldMany [1..10]` is its upstream and `mapM_C print` is its downstream.

* `yieldMany` consumes nothing from upstream, and produces a stream of
  `Int`s
* `mapC show` consumes a stream of `Int`s, and produces a stream of
  `String`s
* When we combine these two components together, we get something
  which consumes nothing from upstream, and produces a stream of
  `String`s.

To add some type signatures into this:

```haskell
yieldMany [1..10] :: ConduitT ()  Int    IO ()
mapC show         :: ConduitT Int String IO ()
```

There are four type parameters to `ConduitT`:

* The first indicates the upstream value, or input. For `yieldMany`,
  we're using `()`, though really it could be any type since we never
  read anything from upstream. For `mapC`, it's `Int`
* The second indicates the downstream value, or output. For
  `yieldMany`, this is `Int`. Notice how this matches the input of
  `mapC`, which is what lets us combine these two. The output of
  `mapC` is `String`.
* The third indicates the base monad, which tells us what kinds of
  effects we can perform. A `ConduitT` is a monad transformer, so you
  can use `lift` to perform effects. (We'll learn more about conduit's
  monadic nature later.) We're using `IO` in our example.
* The final indicates the result type of the component. This is
  typically only used for the most downstream component in a
  pipeline.

 The components of a pipeline are connected to the `.|` operator, which type is:
 
 ```haskell
(.|) :: Monad m => ConduitT a b m () -> ConduitT b c m r -> ConduitT a c m r
```

This shows us that:
* The output from the first component must match the input from the
  second
* We ignore the result type from the first component, and keep the
  result of the second
* The combined component consumes the same type as the first component
  and produces the same type as the second component
* Everything has to run in the same base monad

and a pipeline is run with the runConduit function
