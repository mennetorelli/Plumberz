# Table of contents

* [Intro](#Intro)
* [Conduit library](#Conduit-library)
  * [Practical introduction](#Practical-introduction)
  * [Conduit package overview](#Conduit-package-overview)
    * [Pipe datatype](#Pipe-datatype)
    * [From Pipe to ConduitT newtype](#From-Pipe-to-ConduitT-newtype)
    * [Primitives](#Primitives)
    * [ZipSink, ZipSource and ZipConduit newtypes](#ZipSink,-ZipSource-and-ZipConduit-newtypes)
    * [Tubes, Pipes and Conduit comparison](#Tubes,-Pipes-and-Conduit-comparison)
* [Batch wordcount with Conduit](#Batch-wordcount-with-Conduit)
  * [I/O version without Conduit](#I/O-version-without-Conduit)
  * [Wordcount Conduit version](#Wordcount-Conduit-version)
  * [Wordcount Conduit version - single pipeline](#Wordcount-Conduit-version---single-pipeline)
* [Performance evaluation](#Performance-evaluation)
  * [Wordcount evaluation - Ghci](#Wordcount-evaluation---Ghci)
  * [Wordcount evaluation - executable file](#Wordcount-evaluation---executable-file)
  * [General evaluation of simpler pipelines](#General-evaluation-of-simpler-pipelines)
  * [Performance conclusions](#Performance-conclusions)
* [Distributed wordcount with network-conduit and async](#Distributed-wordcount-with-network-conduit-and-async)
  * [Synchronous wordcount](#Synchronous-wordcount)
  * [Wordcount with timeout](#Wordcount-with-timeout)
  * [Distributed wordcount conclusions](#Distributed-wordcount-Conclusions)


# Intro
This project extends the research conducted by [Luca Lodi](https://github.com/lulogit) and [Philippe Scorsolini](https://github.com/phisco) 
for the course of "Principles of Programming Languages" at Politecnico di Milano 
by prof. Matteo Pradella and with the supervision of [Riccardo Tommasini](https://github.com/riccardotommasini). 
For more information, visit [their repository on GitHub](https://github.com/plumberz/plumberz.github.io)

While the previous research was focused on examining [Pipes](https://hackage.haskell.org/package/pipes) 
and [Tubes](https://hackage.haskell.org/package/tubes) libraries for stream processing in Haskell, 
this research focuses on the [Conduit](https://hackage.haskell.org/package/conduit) library.

# Conduit library
As the tutorial on the homepage of [Conduit's official repository](https://github.com/snoyberg/conduit) explains, 
Conduit is a framework for dealing with streaming data, which standardizes various interfaces for streams of data, 
and allows a consistent interface for transforming, manipulating, and consuming that data. 
The main benefits that Conduit provides are constant memory and deterministic resource usage.

## Practical introduction

Since Conduit deals with streams of data, such data flows through a **pipeline**, which is the main concept of Conduit. 
Each component of a pipeline can consume data from **upstream**, and produce data to send **downstream**. 
For instance, this is an example of a Conduit pipeline:

```haskell
runConduit $ yieldMany [1..10] .| mapC (*2) .| mapC show .| mapM_C print
```
 
For instance, from the perspecive of `mapC (*2)`, `yieldMany [1..10]` is its upstream and `mapC show` is its downstream.
The following explains more in detail how the stream is manipulated at each step of the pipeline:

* `yieldMany` consumes nothing from upstream, and produces a stream of `Int`s.
* `mapC (*2)` consumes a stream of `Int`s, and produces another stream of `Int`s.
* `mapC show` consumes a stream of `Int`s, and produces a stream of `String`s.
* `mapM_C print` consumes a stream of `String`s, and produces nothing to downstream.
* If we combine, for instance, the first three components together, 
  we get something which consumes nothing from upstream, and produces a stream of `String`s.

To add some type signatures into them:

```haskell
yieldMany [1..10] :: ConduitT ()     Int    IO ()
mapC (*2)         :: ConduitT Int    Int    IO ()
mapC show         :: ConduitT Int    String IO ()
mapM_C print      :: ConduitT String Void   IO ()
```

The previous type signatures highlight that there are four type parameters to `ConduitT`:

* The first indicates the upstream value, or input. For `yieldMany`, we're using `()`, 
  though it could be any type since we never read anything from upstream. For both `mapC`s, it's `Int`
* The second indicates the downstream value, or output. For `yieldMany` and the first `mapC`, this is `Int`. 
  Notice how this matches the input of both `mapC`s, which is what lets us combine these two. 
  The output of the second `mapC` is `String`.
* The third indicates the base monad, which tells us what kinds of effects we can perform. 
  In our example we are using `IO` as base monad, because we used `print` in the most downstream component.
  A `ConduitT` is a **monad transformer**, so it's possible to use `lift` to perform effects. 
* The final indicates the result type of the component. 
  This is typically only used for the most downstream component in a pipeline.
  In our example we have `()`, since `mapM_C print` doesn't have a result value, 
  but we could have for instance a pipeline like `yieldMany [1..10] .| mapC (*2) .| sumC`, 
  where the most downstream component `sumC` gets the sum of all values in the stream, and therefore results in a `Int` value.

 The components of a pipeline are connected to the `.|` operator, which type is:
 
 ```haskell
(.|) :: Monad m => ConduitT a b m () -> ConduitT b c m r -> ConduitT a c m r
```

This is prefectly in line with our example, and shows us that:
* The output from the first component must match the input from the second.
* We ignore the result type from the first component, and keep the result of the second.
* The combined component consumes the same type as the first component and produces the same type as the second component.
* Everything has to run in the same base monad.

Finally, a pipeline is run with the `runConduit` function, which has type signature:
 
```haskell
runConduit :: Monad m => ConduitT () Void m r -> m r
```

This gives us a better idea of what a pipeline is: just a self contained component, 
which consumes nothing from upstream, denoted by `()`, and producing nothing to downstream, denoted by `Void`. 
(In practice, `()` and `Void` indicate the same thing.)
We can then run such standalone component with `runConduit` to extract a monadic action that will return a result (the `m r`).

In addition of runConduit there is also the function runConduitPure, which is used when the pipeline has no side effects.
The pipeline shown before has side effects because we printed each value in the last component, 
but we could have a situation like this, in which we accumulate all the results in a list with `sinkList` 
without printing nothing (and therefore without having monadic values):

```haskell
runConduitPure $ yieldMany [1..10] .| mapC (*2) .| sinkList
```

A pure pipeline is basically a pipeline with `Identity` as the base monad, 
and therefore `runConduitPure` has the following type signature:

```haskell
runConduitPure :: ConduitT () Void Identity r -> r
```


## Conduit package overview

### Pipe datatype
`Pipe` is the underlying datatype for all the types in Conduit package. It is defined as follows:

```haskell
-- Defined in Data.Conduit.Internal
data Pipe l i o u m r 
    = HaveOutput (Pipe l i o u m r) o
    | NeedInput (i -> Pipe l i o u m r) (u -> Pipe l i o u m r)
    | Done r
    | PipeM (m (Pipe l i o u m r))
    | Leftover (Pipe l i o u m r) l
```

`Pipe` has six type parameters:
* l is the type of values that may be left over from this `Pipe`. 
  A `Pipe` with no leftovers would use `Void` here, and one with leftovers would use the same type as the i parameter. 
  Leftovers are automatically provided to the next `Pipe` in the monadic chain.
* i is the type of values for this `Pipe`'s input stream.
* o is the type of values for this `Pipe`'s output stream.
* u is the result type from the upstream `Pipe`.
* m is the underlying monad.
* r is the result type.

And it has five constructors:

* `HaveOutput`: Provide new output to be sent downstream. 
  This constructor has two fields: the next `Pipe` to be used and the output value.
* `NeedInput`: Request more input from upstream. The first field takes a new input value and provides a new `Pipe`. 
  The second takes an upstream result value, which indicates that upstream is producing no more results.
* `Done`: Processing with this `Pipe` is complete, providing the final result.
* `PipeM`: Require running of a monadic action to get the next `Pipe`.
* `Leftover`: Return leftover input, which should be provided to future operations.

A `Pipe` is instance of many typeclasses, from the most common like `Functor`, `Applicative` and `Monad` to more complex ones.
There is the instance of `MonadIO`, which provides `liftIO`. 
Most importantly, there is the instance of `MonadTrans`, which allows to perform generic `lift` operations.
Worth noting is also the instance of `MonadResource` which is in turng defined in the Conduit module itself, 
and is a Monad allowing for safe resource allocation. This provides the `liftResourceT`, which unwraps the `ResourceT` transformer. 
`ResourceT` transformers are used for instance were file reading/writing comes into play 
(this is the case of our next examples in the folowing secions).

Here we report some of the typeclasses of which `Pipe` is instance:

```haskell
-- Defined in Data.Conduit.Internal
Monad m => Functor (Pipe l i o u m)
Monad m => Applicative (Pipe l i o u m)
Monad m => Monad (Pipe l i o u m)
Monad m => Monoid (Pipe l i o u m ())
MonadIO m => MonadIO (Pipe l i o u m)
MonadTrans (Pipe l i o u)
MonadResource m => MonadResource (Pipe l i o u m)
```


### From Pipe to ConduitT newtype
As shown in the practical introduction, the core datatype of the conduit package is `ConduitT`, 
which is built of top of `Pipe` and defined as:

```haskell
-- Defined in Data.Conduit
newtype ConduitT i o m r = ConduitT {
    unConduitT :: forall b. (r -> Pipe i i o () m b) -> Pipe i i o () m b
}
```

Also the `ConduitT` newtype is instance of the same typeclasses of `Pipe`.

```haskell
-- Defined in Data.Conduit
Functor (ConduitT i o m)
Applicative (ConduitT i o m)
Monad (ConduitT i o m)
Monad m => Monoid (ConduitT i o m ())
MonadIO m => MonadIO (ConduitT i o m)
MonadTrans (ConduitT i o)
MonadResource m => MonadResource (ConduitT i o m)
```

As we have seen in the introduction from a more practical perspective, 
`ConduitT`'s type represents a general component of a pipeline which can consume a stream of input values `i`, 
produce a stream of output values `o`, perform actions in the `m` monad, and produce a final result `r`. 

In addition to the `ConduitT` generic newtype type, in the `Data.Conduit` module there are also some other deprecated type synonyms 
built on top of it which further specify the nature of the pipe component we are considering.

```haskell
-- Defined in Data.Conduit
type Source     m o   =           ConduitT () o    m ()
type Sink     i m   r =           ConduitT i  Void m r
type Conduit  i m o   =           ConduitT i  o    m ()
type Producer   m o   = forall i. ConduitT i  o    m ()
type Consumer i m   r = forall o. ConduitT i  o    m r
```

More in detail, we have the `Source` and `Sink` components which, like their names indicate, 
are more specific than the generic `ConduitT` component.
`Source` provides a stream of output values, without consuming any input or producing a final result. 
`Sink` consumes a stream of input values and produces a final result, without producing any output.
`Producer` and `Consumer` are a generalization of respectively a `Source` and a `Sink`, 
i.e. a `Producer` can be used either as a `ConduitT` or a `Source`, 
and a `Consumer` can be used either as a `ConduitT` or a `Sink`.
Those type synonyms however have been deprecated due to simplify the package, 
and users can employ the `ConduitT` type for each one of these cases.


### Primitives
Now, let's introduce the main primitives on which many of the functions contained in the library are built.
Arguably the most important two primitives are:

```haskell
-- Defined in Data.Conduit
yield :: Monad m => o -> ConduitT i o m ()
await :: Monad m => ConduitT i o m (Maybe i)
```

`yield` sends a value downstream, while `await` waits for a single input value from upstream.

In the `Data.Conduit.Internal` module there are also the versions based on `Pipe` instead of the newtype `ConduitT`,
but the concept is almost the same.

```haskell
-- Defined in Data.Conduit.Internal
yield :: Monad m => o -> Pipe l i o u m ()
await :: Pipe l i o u m (Maybe i) 
```

Based on these two primitives there are other similar functions like `yieldMany`, which is basically `yield` for more values,
and `awaitForever` which waits for input forever, calling the given inner `ConduitT` for each piece of new input.

Most of the functions available in the modules of Conduit package are based on these two primitives.
For example, in the practical introduction we have seen `mapC`, which is implemented as follows:

```haskell
-- Defined in Conduit
mapC :: Monad m => (i -> o) -> ConduitT i o m ()
mapC f =
    loop
  where
    loop = do
        mx <- await
        case mx of
            Nothing -> return ()
            Just x -> do
                yield (f x)
                loop
 ```

We can see that `mapC` takes as parameter the function of type `(i -> o)`, and has a result value of `ConduitT i o m ()`.
It performs indefinitely the folowing action: waits for a data with `await`, then if the data is a `Nothing` it returns `()`,
otherwise if it is a `Just` it applies the function to its value and yields the result.
Many of the Prelude functions are reimplemented in Conduit to match the `ConduitT` datatype.

Another important primitive is `leftover`, 
which a single piece of leftover input to be consumed by the next pipe in the current monadic binding.

```haskell
-- Defined in Data.Conduit
leftover :: i -> ConduitT i o m ()
```

An example in which it is used is the `takeWhileC` function, which streams all values downstream that match the given predicate.

```haskell
-- Defined in Conduit
takeWhileC :: Monad m => (i -> Bool) -> ConduitT i i m ()
takeWhileC f =
    loop
  where
    loop = do
        mx <- await
        case mx of
            Nothing -> return ()
            Just x
                | f x -> do
                    yield x
                    loop
                | otherwise -> leftover x
```

In `takeWhileC` the primitive `leftover` is necessary because otherwise the first element that doesn't match the predicate 
would be discarded, instead we want to send it to the next pipe.


### ZipSink, ZipSource and ZipConduit newtypes
There are some newtypes that are worth mentioning, even if we didn't employed them in our project.

`ZipSink` is a newtype wrapper which provides a different `Applicative` instance than the standard one for `ConduitT`. 
Instead of sequencing the consumption of a stream, it allows two components to consume in parallel. 

```haskell
-- Defined in Data.Conduit
newtype ZipSink i m r = ZipSink {
    getZipSink :: Sink i m r
}
```

`ZipSource` in the dual of `ZipSink`, because it allows us to produce in parallel.

```haskell
-- Defined in Data.Conduit
newtype ZipSource m o = ZipSource {
    getZipSource :: Source m o
}
```

`ZipConduit` allows you to combine a bunch of transformers in such a way that:
* Drain all of the `ZipConduit`s of all yielded values, until they are all awaiting
* Grab the next value from upstream, and feed it to all of the `ZipConduit`s
* Repeat

```haskell
-- Defined in Data.Conduit
newtype ZipConduit i o m r = ZipConduit {
    getZipConduit :: ConduitT i o m r
}
```


### Tubes, Pipes and Conduit comparison
[Philippe and Luca's previous research](https://github.com/plumberz/plumberz.github.io)
already conatins a comparison between Pipes and Tubes libraries, which highlights the many similarities between the two,
from datatypes to the semantic of the primitives. Also Conduit has many similarities with the two libraries. 

Let's start with the datatype provided:

| *Pipes*  	    | *Tubes*       | *Conduit*                               
|---------------|---------------|--------------------------------------
| `Proxy`    	| `Tube` 	    | `Pipe`
| `Producer` 	| `Source`      | `ConduitT` (or deprecated `Source`)
| `Pipe`     	| `Channel`     | `ConduitT` (or deprecated `Conduit`)
| `Consumer` 	| `Sink`        | `ConduitT` (or deprecated `Sink`)
| `Effect`   	| /             | /

We can see that each of the datatypes of a library have their counterpart in the other ones, 
except from `Effect` which is peculiar of Pipes, but can be easily conceptualized in Tubes with `Tube () () m r` 
and in the same way in Conduit with `ConduitT () () m r`.

For what concerns the primitives, each library implements both yield and await, 
which are similar both in syntax and in semantics.
`leftover`, instead, is a peculiar primitive of Conduit, since neither Pipes nor Tubes have the concept of leftover values.

The composition of pipelines in the three libraries are performed with the following composition operators:

| *Pipes*  	    | *Tubes*       | *Conduit*                               
|---------------|---------------|---------------
| `>->`    	    | `><` 	        | `.|`

Pipes allows to use the `>->` both between Proxies and between Producers/Pipes/Consumers thanks to Rank-N ghc extension.
On the contrary, in Tubes the `><` operator can compose only matching Tubes, 
and it is necessary to obtain the corresponding `Tube` from a `Source`/`Channel`/`Sink` 
using `sample`/`tune`/`pour` operations before applying the composition.
Conduit probably provides the most flexible pipeline composition among the three libraries,
thanks to the unique datatype `ConduitT` and  `.|` operator.

For what concerns the various operations contained in Prelude, each library reimplement them in terms of the specific datatypes. 
Specifically, Pipes defines these functions in `Pipes.Prelude`, Tubes inside `Tubes.Util`, Conduit in `Data.Conduit`.
For example, if we consider again the `map` function, both in Pipes and in Tubes we can find again `map`, and in Conduit `mapC`, 
as we have seen in the various examples of this discussion.


# Batch wordcount with Conduit
To understand better how the library works, we implemented a simple wordcount script. 
The rationale is the following: the script reads from a .txt file, and counts occurrences of all the words contained into it, 
and finally prints the result to the user. 

All the versions described in this section are in the [Wordcount_batch.hs](code/Wordcount_batch.hs) file.

## I/O version without Conduit
First of all, we implemented a lazy I/O version of the wordcount script without using Conduit library, 
to higlight the differences between a non-Conduit and a Conduit version, and understand the benefits that Conduit provides. 

```haskell
import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (pack, toLower, filter, words)

import System.IO

wordcount :: IO ()
wordcount = withFile "input.txt" ReadMode $ \handle -> do
    content <- hGetContents handle
    print $ toList $ foldr
        (\x v -> insertWith (+) x 1 v) 
        empty 
        (fmap Data.Text.toLower 
            $ fmap (Data.Text.filter isAlphaNum)
            $ (Data.Text.words . pack) content)
 ```

The rationale is as follows: first of all the function reads from the input.txt file by means of `withFile` function, 
then extracts the content with `hGetContents`, 
and finally accumulates all the words contained in a hashmap by means of a `foldr` used with `(\x v -> insertWith (+) x 1 v)` function. 
The words are obtained from the `String` read from the file using a combination of `fmap`s: 
first of all the string is converted in a `Text` with `pack` and split in a series of `Text`s with `words` function, 
then such words are cleaned from eventual non alphanumerical characters, and finally lowercased due to prevent duplicates.

This I/O example works fine, but the main problem compared to any Conduit version is that the memory usage is not constant: 
the more the file size grows, the more there are possibilities of a stack overflow.


## Wordcount Conduit version
We implemented a first version of the above wordcount using Conduit.

```haskell
import Data.Char (toLower)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (filter, words)

import Conduit

wordcountC :: IO ()
wordcountC = do
    content <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| foldC
    hashMap <- runConduit $ yieldMany (Data.Text.words content)
        .| mapC (Data.Text.filter isAlphaNum)
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)
```

This version of the wordcount deals with data in a stram processing style, using Conduit. 
In particular, the `wordcountC` function contains two monadic actions which run a pipeline each 
(plus the third monadic action that prints the result).

The first monadic action has the purpose of reading form the input file and accumulate its content in a `Text`. 
More in detail the steps of the pipeline are:

* the file is read with `sourceFile`, which produces a `ByteString` to be sent downstream. 
* Then the `ByteString` is converted in a Text with `decodeUtf8C`.
* Each character of the `ByteString` is mapped to the toLower function, using the `omapCE` function. 
  This is an example of the ability of Conduit to work with **chunked data**.
  Here the issue is that instead of having a stream of `Char` values, we have a stream of `Text` values,
  and our `mapC` function will work on the `Text`s. 
  But our `toUpper` function works on the `Char`s inside of the `Text`. 
  This is where the chunked functions in conduit come into play. 
  In addition to functions that work directly on the values in a stream, 
  we have functions that work on the _elements_ inside those values. 
  These functions get a `CE` suffix instead of `C`.
* At last, the `foldC` accumulates the data from upstream.

Instead of using `runConduit`, the pipeline is run with the helper function `runResourceT`, 
which is nothing more than `runResourceT . runConduit`. 
`runResourceT` is contained in the built-in package [resourceT](https://www.stackage.org/package/resourcet) of Conduit 
and allows to allocate resources and guarantees that they will be cleaned up.

The second monadic action deals with analyzing the `Text` extracted from the first pipeline and counts the words contained into it. 
More in detail the steps are:

* `yieldMany (Data.Text.words content)` produces a stream of words starting from the single `Text`.
* `mapC (Data.Text.filter isAlphaNum)` filters the non alphanumeric characters. 
  Note that in this case we use `mapC` instead of `ompaCE`, 
  because we are not working anymore with each character contained in the stream.
* `foldMC insertInHashMap empty` is a monadic strict left fold used to accumulate the words in the hashmap.

This first implementation, however, has a drowback, i.e. the employment of two different pipelines to compute the task. 
The next versions of the task show our attempt to achieve the same results using only one stream of data.


## Wordcount Conduit version - single pipeline
```haskell
import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)

import Conduit

wordcountCv2 :: IO ()
wordcountCv2 = do 
    hashMap <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| peekForeverE (do
            word <- takeWhileCE isAlphaNum .| foldC
            dropWhileCE (not . isAlphaNum)
            yield word)
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)
```

In this implementation we merged the two pipelines in a single one, using `peekForeverE`. 
`peekForeverE` is the "chunked" version of the conduit combinator `peekForever`, 
which continuously runs a conduit as long as there is some input available in a stream. 
A combinator is an element that when given a conduit, will generate a conduit.

the argument of `peekForeverE` is a monadic action that contains an "inner" conduit, and the steps are as follows:
* With `takeWhileCE` we send downstream all the elements that match the `isAlphaNum` predicate, 
i.e. in our case we accumulate the chunked stream into a word variable using the `foldC` function.
* With `dropCE 1` we discard from the stream the non-alphanumeric characters (i.e. the spaces, or other punctuation characters).
* Finally, we `yield` the previously stored word downstream, 
  and in this case the downstream corresponds to `foldMC insertInHashMap empty` of the "outer" conduit.

This version shows another powerful feature of Conduit: 
in addition of being able to combine multiple components together by connecting the output of the upstream 
to the input of the downstream via the `.|` operator, we can also exploit **monadic composition**:
we can combine simple conduits in more complex ones using the standard monadic interface (or `do`-notation).
In our example, we exploited monadic composition in the "inner" conduit, 
because the accumulation part with `takeWhileCE isAlphaNum .| foldC`, the `dropCE` and the producing `yield`
are packed together in a single `do` block.

We can replace `peekForeverE` with `splitOnUnboundedE`, which is a conduit combinator that splits a stream of arbitrarily-chunked data 
based on a predicate on the elements, i.e. exactly what we need in our example.

```haskell
import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)

import Conduit
import qualified Data.Conduit.Combinators as CC

wordcountCv3 :: IO ()
wordcountCv3 = do 
    hashMap <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)
```


# Performance evaluation

We decided to conduct a simple performance evaluation to see the differences between the preliminar version without Conduit (`wordcount`)
and the two single-pipeline Conduit versions (`wordcountCv2` and `wordcountCv3`). Our parameter was the waiting time.

The evaluation was conducted as follows: we evaluated each wordcount using different file inputs, 
and for each file we executed the function 20 times.
Specifically, we used a .txt file of about 100 words (plus punctuation)
whose content is defined in the [File_generator.hs](code/File_generator.hs) script, 
and such file was repeated a variable number of times depending on what we were going to evaluate.
So, from now on, when we refer to file size we are actually referring to the times the content of the file is repeated.
We measured the time at the beginning and at the end of each wordcount execution by means of the `Data.Time.Clock` module, 
and then we saved the elapsed time for each of the executions.

The results of each evaluation are available in [this file](performance/data.xlsx).
Such results have been analysed and visualized with [Jupyter Notebook](https://jupyter.org/) 
using [Pandas](https://pandas.pydata.org/) library for Python.
A dedicated script [Wordcount_performance.hs](code/Wordcount_performance.hs) 
has been built to automatize executions and their collection of data.

## Wordcount evaluation - Ghci

The first evaluation was conducted on Ghci using files repeated respectively 2000, 3000, 4000, 5000 and 6000 times.
The result higlight clearly which is the advantage of using Conduit w.r.t. to a standard lazy I/O implementation: 
in the boxplot reported below, in fact, we can see that the I/O version works only with the files which size is below 4000, 
and for bigger files it produces a stack overflow.

![png](images/output_2_2.png)

The first three boxes are related to the file of size 2000, then the next three are related file of size 3000, and so on.
From the box plot we can see that generally the execution times are quite different, 
especially for the Conduit versions in which we have also many outliers.

Then, we aggregated each set of 20 evaluations by means of their median, and plotted again with a bar diagram.
Again, the bars are grouped by input file (from 2000 to 5000) and the elapsed time is in seconds.

![png](images/output_4_1.png)

## Wordcount evaluation - executable file

Then, we decided to compile the scripts and evaluate the executable file produced by the compilation.
We used the command `ghc --make` with `-O` flag, which enables a set of optimizations during the compilation.
Since running the executable code is faster and more reliable than using the Ghci console, 
we used for the second evaluation files repeated respectively 2500, 5000, 7500, 10000, 12500 and 15000 times.

The results obtained are quite surprising, because they highlight that `wordcount` and `wordcountCv3` have very similar performances,
but the most surprising result is that the `wordcountCv2` function seems to be very inefficient, especially for large input files.

![png](images/output_6_1.png)

Again the bar diagram is obtained aggregating each set of 20 evaluations by their median.

![png](images/output_8_1.png)

It's worth noting from the box plot that the `wordcountCv2` has more outliers than the other versions, 
in particular in each set of 20 evaluations we have at least one run 
that takes approximately three times than the others in the same set. 
To investigate this fact we evaluated again 20 times the `wordcountCv2` function with an input file of size 15000 
we evaluated the executable with `+RTS -s` options, which allows to see how much time is spent in the garbage collector. 
(For more information, see [Measuring performance](https://wiki.haskell.org/Performance/GHC#Measuring_performance).)

The results highlight that some of the time required to run `wordcountCv2` is spent in the garbage collector.
The following data tell how much time is being spent running the program itself (MUT time), 
and how much time spent in the garbage collector (GC time). 

```
1,155,372,089,504 bytes allocated in the heap
  57,899,646,920 bytes copied during GC
   9,072,121,152 bytes maximum residency (17 sample(s))
     144,022,208 bytes maximum slop
            8651 MB total memory in use (0 MB lost due to fragmentation)

                                     Tot time (elapsed)  Avg pause  Max pause
  Gen  0     1104943 colls,     0 par   41.828s  85.514s     0.0001s    0.0287s
  Gen  1        17 colls,     0 par   34.578s  274.046s     16.1204s    164.3027s

  INIT    time    0.000s  (  0.000s elapsed)
  MUT     time  519.828s  (1660.710s elapsed)
  GC      time   76.406s  (359.560s elapsed)
  EXIT    time    0.000s  (  0.018s elapsed)
  Total   time  596.234s  (2020.289s elapsed)

  %GC     time       0.0%  (0.0% elapsed)

  Alloc rate    2,222,604,037 bytes per MUT second

  Productivity  87.2% of total user, 82.2% of total elapsed
```

Those are the results of the `wordcountCv3` execution, which show that not only the MUT time is much smaller, 
but also the GC time is much less that the compared to the GC time of `wordcountCv2`. 

```
1,119,052,163,176 bytes allocated in the heap
  19,755,079,352 bytes copied during GC
         245,784 bytes maximum residency (8502 sample(s))
          29,896 bytes maximum slop
               0 MB total memory in use (0 MB lost due to fragmentation)

                                     Tot time (elapsed)  Avg pause  Max pause
  Gen  0     1058668 colls,     0 par   17.906s  18.140s     0.0000s    0.0006s
  Gen  1      8502 colls,     0 par    1.016s   1.155s     0.0001s    0.0236s

  INIT    time    0.000s  (  0.002s elapsed)
  MUT     time  365.172s  (373.761s elapsed)
  GC      time   18.922s  ( 19.295s elapsed)
  EXIT    time    0.000s  (  0.000s elapsed)
  Total   time  384.094s  (393.058s elapsed)

  %GC     time       0.0%  (0.0% elapsed)

  Alloc rate    3,064,453,315 bytes per MUT second

  Productivity  95.1% of total user, 95.1% of total elapsed
```

## General evaluation of simpler pipelines
However, the results obtained so fare pose another question about the overall Conduit performance, 
since there is no evidence that the `wordcountCv3` version is faster than the initial lazy I/O version.
To investigate whether implementing a function using Conduit provide performance improvements or not, 
we decided to test simpler pipelines and evaluate their performances compared to the lazy I/O counterparts.
The code used for this evaluation is available in [Performance_example.hs](code/Performance_example.hs).

First of all, we compared the performances of a very simple function which sums the first x integers of an infinite list.
The standard version is built like this:

```haskell
print $ foldr (+) 0 (take x [1..])
```

And this is the Conduit version:

```haskell
print $ runConduitPure $ yieldMany [1..] .| takeC x .| sumC
```

We evaluated both versions 20 times, summing the first 10000000, 40000000, 70000000 and 100000000 integers,
and these are the obtained results:

![png](images/output_11_1.png)

Note that for this evaluation, we skipped the `-O` flag, because it enabled a weird optimization 
that allowed the program to cache the result of each iteration, 
so that, iterating the function 10 times, we obtained the following results:

```
38.2066878s
4.3696857s
1.3367605s
0.9950032s
0.9399968s
0.9039936s
0.9079987s
0.9119587s
0.9090151s
0.8749654s
```

Anyway, the results show that with a simple program like this, built using a very short pipeline, 
we can achieve considerable performance improvements compared to the lazy I/O version.

This made us question whether the problem in our wordcount function was the reading from a file, 
so we shifted our attention on that aspect.
For this reason, we built a simple function that reads an input file, and copies its contents in an output file.

This is the function built with the System.IO module, as in the `wordcount` function.

```haskell
withFile "input.txt" ReadMode $ \input ->
    withFile "outputS.txt" WriteMode $ \output -> do
        content <- hGetContents input
        hPutStr output $ content
```

And this is in turn the Conduit version:

```haskell
runConduitRes $ sourceFile "input.txt"
    .| decodeUtf8C
    .| encodeUtf8C
    .| sinkFile "outputC.txt"
```

These are the result obtained using as input files of size 10000, 30000 and 50000
(always iterating the code 20 times for each input file):

![png](images/output_14_1.png)

Again the results show a considerable performance gain using the Conduit version instead of the lazy I/O one,
so reading/writing from a file does not result in a performance degradation.

Our last guess was trying to complicate the pipeline adding some intermediate steps between reading and writing, 
and for this reason we inserted in the computation two steps: 
* Mapping a `toUpper` function which converts all characters in uppercase
* Filtering all non-alphanumerical characters.
The two function become therefore: 

```haskell
withFile "input.txt" ReadMode $ \input ->
    withFile "outputS.txt" WriteMode $ \output -> do
        content <- hGetContents input
        hPutStr output $ content
```

And with Conduit:

```haskell
runConduitRes $ sourceFile "input.txt"
    .| decodeUtf8C
    .| omapCE toUpper
    .| filterCE isAlphaNum
    .| encodeUtf8C
    .| sinkFile "outputC.txt"
```

The results became the following:

![png](images/output_17_1.png)

So we can see that the performance gain of the conduit version is much smaller, 
and that indicates that the stream processing paradigm adds much overhead to the computation.

## Performance conclusions

So the conclusion is that if we have a program doing some one-off processing of a large file, 
as long as we have a lazy I/O version running fine now, 
there's probably no good performance reason to convert it over to a streaming package.
In fact, streaming is more likely to add some overhead, 
so the evidence is that, in non trivial examples like our wordcount case, 
a well optimized lazy I/O solution would out-perform a well optimized streaming solution.



# Distributed wordcount with network-conduit and async

# Synchronous wordcount
Once explored the main features of the Conduit library, we decided to extend the wordcount snippet to more practical use cases, 
e.g. distributing the logic between a client and a server.

Among the packages that are built on top of Conduit there is [conduit-extra](http://hackage.haskell.org/package/conduit-extra) 
containing the module [Data.Conduit.Network](https://hackage.haskell.org/package/conduit-extra-1.3.1.1/docs/Data-Conduit-Network.html), 
which provides some functions for writing network servers and clients using Conduit. 
We recommend [this tutorial](https://www.yesodweb.com/blog/2014/03/network-conduit-async) to take a look to its functionalities.

We tried to impelement a distributed version of the wordcount of the previous section, 
where the client reads from the file and sends a stream of `ByteString` to the server, 
and the server does the computation to the `HashMap` and replies to the client with the result.

Both the server and the client code are contained respectively in the [server.hs](code/server.hs) and [client.hs](code/client.hs) files.

This is the server code:

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Monad (forever)
import Data.Functor (void)

import Data.ByteString.Char8 (pack)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Word8 (toLower, isAlphaNum, _percent)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network

server :: IO ()
server = runTCPServer (serverSettings 4000 "*") $ \appData -> forever $ do
    hashMap <- runConduit $ appSource appData 
        .| takeWhileCE (/= _percent)
        .| omapCE toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| foldMC insertInHashMap empty
    runConduit $ yield (pack $ show $ toList hashMap)
        .| appSink appData

insertInHashMap x v = do
    return (insertWith (+) v 1 x)
```

`runTCPServer` takes two parameters. The first is the server settings, which indicates how to listen for incoming connections. 
The second parameter is an `Application`, which takes some `AppData` and runs some action. 
Importantly, our app data provides a `Source` to read data from the client, and a `Sink` to write data to the client.

The action repeated indefinitely by the server (thanks to `forever`) is quite trivial given the explanations of the previous section: 
once the input arrives from the client it calculates the `HashMap` containing the occurrences of the words, 
and then sends it back to the client. 

Since the type signature of `appSink` is `appSink :: (HasReadWrite ad, MonadIO m) => ad -> ConduitT ByteString o m ()`, 
it suggests us that we can send to the client only streams of type `ByteString`, 
therefore we must perform a tricky `toList`, then `show` and then `pack` on our hashmap before sending it to the client. 
The same constraint applies to `appSource`, which has type signature 
`appSource :: (HasReadWrite ad, MonadIO m) => ad -> ConduitT i ByteString m ()`.

There is another component of the pipeline worth noting, which is `takeWhileCE (/= _percent)`: 
we basically stop sending data downstream as soon as the `%` character is found. 
This is a fundamental step in the pipeline, because a Conduit pipeline is driven by downstream. 
However, in this case the downstream is `foldMC insertInHashMap empty`, 
which continuously accumulates data coming from upstream but doesn't know whether the client has finished sending data. 
With `takeWhileCE (/= _percent)` we can ensure that the server stops processing characters 
as soon as a `%` character in the `ByteStream` is found 
(we will see later that the `%` has appropriately inserted by the client at the end of the input.)

And this is the client code:

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent.Async (concurrently)
import Data.Functor (void)
import Control.Monad (forever)

import Data.ByteString.Char8 (pack)
import Data.Word8 (_cr)

import Conduit
import Data.Conduit.Network

client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (forever $ do    
            getLine
            runConduitRes $ 
                do
                    sourceFile "input.txt"
                    yield (pack "%")
                .| appSink server)
        (runConduit $ appSource server 
            .| stdoutC)
```

As in the server case, we use `runTCPClient` in a similar way to connect with the server. 

The rationale of the client logic is as follows: 
we want to read a file and send its content to the client everytime the user press a key, 
and concurrently receive and print everything is sent back by the server. 
To tackle with said concurrency in a correct way, we pull in the [async package](https://hackage.haskell.org/package/async), 
and in particular, the `concurrently` function. 
This function forks each child action into a separate thread, and blocks until both actions complete. 
If either thread throws an exception, then the other is terminated and the exception is rethrown. 
This provides exactly the behavior we need: there is a thread which deals with producing data to be sent to the server, 
and the other one which deals with consuming data (printing it with `stdoutC`) received from the server.

We can see again in the producing thread the employent of `forever` due to repeat the underlying action indefinetly. 
In receiving thread this is not strictly necessary, because it waits implicitely for data from the server and therefore never closes.

In the producing thread we can see the `%` character being `yield`ed after the file is read with `sourceFile "input.txt"`, 
and then everything is sent to the server as a single `ByteString` stream.

However, handling the communication between client and server was not so easy: 
the examples of the [tutorial](https://www.yesodweb.com/blog/2014/03/network-conduit-async) 
deals with very "linear" pipelines as for the server part, 
and in particular there is not the concept of accumulation introduced by `foldMC`, 
which is necessary in our example to build up the hashmap. 
For instance, if we consider the following example, (partially) taken from the tutorial, there are no problems at all.

```haskell
{-# LANGUAGE OverloadedStrings #-}
import           Control.Concurrent.Async (concurrently)
import           Control.Monad (void)
import           Conduit
import           Data.Word8 (toUpper)

server :: IO ()
server = runTCPServer (serverSettings 4000 "*") $ \appData ->
    appSource appData $$ omapCE toUpper =$ appSink appData

client :: IO ()
client = runTCPClient (clientSettings 4000 "localhost") $ \server ->
        void $ concurrently
            (runConduitRes $ sourceFile "input.txt"
                .| appSink server)
            (runConduit $ appSource server 
                .| stdoutC)
```

However, introducing the `foldMC` in the server pipeline, as explained before, results in a deadlock, 
because the client is waiting for the server to respond before it closes the connection, 
but the server is unaware that the client has done sending data and is waiting for more.

We tried solving this problem by forcing the communication between client and server to shutdown after the file is read, 
like in the following example:

```haskell
{-# LANGUAGE OverloadedStrings #-}
import Control.Concurrent.Async (concurrently)
import Data.Functor (void)
import Conduit
import Data.Conduit.Network

import Data.Streaming.Network (appRawSocket)
import Network.Socket (shutdown, ShutdownCmd(..))

client :: IO ()
client = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        ((runConduitRes $ sourceFile "input.txt" 
            .| appSink server) >> doneWriting server)
        (runConduit $ appSource server 
            .| stdoutC)

doneWriting = maybe (pure ()) (`shutdown` ShutdownSend) . appRawSocket
```

But with this version of the client it is too hard to push the concept of `forever` in the first thread of the client, 
because once we have called `shutdown` with `ShutdownSend` on the socket when the file has been sent the first time, 
it is not possible to send again other data to the server, because an exception is raised.

Therefore, we decided that the best option was to include the `%` character at the end of the stream 
and stopping the flow of the stream in the server with `takeWhileCE (/= _percent)`, 
exploiting the fact that Conduit pipelines are driven by downstream.

In addition to the version of the client wich reads from a file and sends a `ByteString` stream to the server, 
we implemented a similar version that does the same thing, but reas from user's input instead of from a file.

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent.Async (concurrently)
import Data.Functor (void)
import Control.Monad (forever)

import Data.ByteString.Char8 (pack)
import Data.Word8 (_cr)

import Conduit
import Data.Conduit.Network

client_stdin :: IO ()
client_stdin = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (forever $ runConduit $ stdinC
            .| do 
                takeWhileCE (/= _cr)
                yield (pack "%")
            .| appSink server)
        (runConduit $ appSource server 
            .| stdoutC)
```

It is almost identical to the `client_file` function shown before, 
except that we have to take care that `stdinC` doesn't know when the user has finished to type something, 
therefore we added a `takeWhileCE (/= _cr)` to consider only the first line of input.


# Wordcount with timeout
This section contains the core of the research and is inspired by 
[the research conducted by Philippe and Luca](https://github.com/plumberz/plumberz.github.io), in which, 
given a tumbling window of 5 seconds and an input stream of lines of text, 
the wordcount program returns at every closing of the window the hashmap containing the occurrences of each word.

In this case, we tried to adapt this concept of time window to the client/server architecture described before, 
so that the server computes the occurrences of each word and deals with the time window at the same time.

Also the code of server with timeout is contained in the [server.hs](code/server.hs) file.

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Monad (forever)
import Data.Functor (void)

import Data.ByteString.Char8 (pack)
import Data.Maybe (fromJust)
import Data.HashMap.Strict (empty, insertWith, toList, unionWith)
import Data.Word8 (toLower, isAlphaNum, _percent)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network

import Control.Concurrent (threadDelay, takeMVar, putMVar, newMVar, tryTakeMVar)
import Control.Concurrent.Async
import System.Timeout


server_tw :: Int -> IO ()
server_tw timeWindow = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMapMVar <- newMVar empty
    void $ concurrently
        (forever $ do 
            hashMap <- runConduit $ appSource appData
                .| takeWhileCE (/= _percent)
                .| omapCE toLower
                .| CC.splitOnUnboundedE (not . isAlphaNum)
                .| foldMC insertInHashMap empty
            queuedHashMap <- tryTakeMVar hashMapMVar
            putMVar hashMapMVar $ unionWith (+) hashMap (extractHashMap queuedHashMap))
        (forever $ do 
            threadDelay timeWindow
            hashMap <- tryTakeMVar hashMapMVar
            runConduit $ yield (pack $ show $ toList (extractHashMap hashMap))
                .| appSink appData)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)

extractHashMap hashMap = if hashMap == Nothing 
                            then empty 
                            else fromJust hashMap
```


First of all, to handle the concept of time correctly, we have to create a separate thread, 
to let the time time counting and the building of the hashmap to happen in parallel. 
To achieve this, we again rely on the `concurrently` of the `Control.Concurrent.Async` module of the async package. 
The rationale is that one thread receives the stream of data from the client and produces the hashmap, 
and the other one at each window closing consumes the data sending the result to the client.

To achieve the sharing of the hashmap between the two threads, we employed the `Control.Concurrent` module 
and in particular [MVars](https://hackage.haskell.org/package/base-4.12.0.0/docs/Control-Concurrent-MVar.html). 
An `MVar` t is mutable location that is either empty or contains a value of type t. 
It has two fundamental operations: `putMVar` which fills an MVar if it is empty and blocks otherwise, 
and `takeMVar` which empties an MVar if it is full and blocks otherwise. 
In our example we instantiated an empty `MVar`s with `newMVar empty` at the beginning, 
so that we could have a syncronyzed, mutable variable visible by both threads.

The producer thread repeats continuously (with `forever`) three monadic actions.
* The first one is basically the conduit pipeline seen in the examples before: we build a `HashMap` and store it in a variable.
* Then, with `tryTakeMVar hashMapMVar` we are accessing the (initially empty) shared `MVar`, and binding its content to `queuedHashMap`.
  We used `tryTakeMVar` instead of `takeMVar` because the former is basically non-blocking version of the latter, 
  and thus the program does not block if the taken `MVar` is `empty`.
* In the last monadic action we are merging the hashmap stored in the `MVar` with the one just computed in the pipeline, 
  and store back the result into the same `MVar`.
  To do so, we are using the `unionWith` with combining function `+`, because we want to sum the values of the duplicate keys.
  Note that we can't feed the `queuedHashMap` directly into the `unionWith`, 
  because `trytakevar` has type `tryTakeMVar :: MVar a -> IO (Maybe a)`, 
  therefore `queuedHashMap` isn't of type `HashMap`, but `Maybe HashMap`.
  To extract the value from `queuedHashMap` we implemented a simple `extractHashMap` function, 
  wich returns `empty` in case the input is `Nothing` and a plain `HashMap` if the input is a `Just`, using the `fromJust` function.

The consumer thread every n seconds (inserted by the user) reads the content of the MVar and sends it to the client. 
More in detail, it repeatedely does the following monadic actions: 
* First of all, the thread waits for a certain amount of time with `threadDelay`. 
* Then, takes the content of the MVar using `tryTakeMVar`. 
* Finally, it sends a stream of Bytestring to the client as in the previous example 
  (note that due to the type signature of `tryTakeMVar` we have to extract the value from the `Maybe` as seen before).
* Thus, if the `HashMap` is `empty`, the client will receive and print an empty stream.

However, with the described implementation some problem can arise in the with `client_file` function if large files are used.
In particular, if the client employs more time to read the file than the time window defined in the server, 
the process seems not to work properly. This is due to the fact that the client reads the file all at once, 
and then appends the `%` character at the end. Therefore, we implemented a `client_filev2` version 
which reads one line at a time and then appends to every line the `%` and send them to the server, one at a time.
In this way the communication is guaranteed to be more fluid even in the case of large files 
which requires much time to be decoded. This is achieved with the `splitOnUnboundedE` combinator again, 
this time used to split the chunked stream into lines (splits when it founds `_cr`, i.e. newline),
and with `intersperseC` which inserts the `%` character between each yielded line.

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent.Async (concurrently)
import Data.Functor (void)
import Control.Monad (forever)

import Data.ByteString.Char8 (pack)
import Data.Word8 (_cr)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network

client_filev2 :: IO ()
client_filev2 = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (forever $ do    
            getLine
            runConduitRes $ sourceFile "input.txt"
                .| CC.splitOnUnboundedE (== _cr)
                .| intersperseC (pack "%")
                .| appSink server)
        (runConduit $ appSource server 
            .| stdoutC)
```


## Distributed wordcount conclusions
The `network-conduit` package allows to extend the stream processing paradigm to a client-server architecture 
without big efforts. Howerver, problems arise when we have an accumulation step in a pipeline, 
because some workarounds are needed to make an actor aware that the other actor has finished sending data to it. 
Moreover, if we want to pull in the concept of time and asyncronicity to implement the time window, 
we have to rely on the `async` package because Conduit doesn't have a package supporting multithreading.
