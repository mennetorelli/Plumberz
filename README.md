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

Finally, a pipeline is run with the `runConduit` function.

# Batch wordcount with Conduit
To understand better how the library works, we implemented a simple wordcount script. The rationale is the following: the script reads from a .txt file, and counts occurrences of all the words contained into it, and finally prints the result to the user. 

All the versions descrived in this paragraph are in the [wordcount_example.hs](https://github.com/mennetorelli/Plumberz/blob/master/code/wordcount_example.hs) file.

## Batch version without Conduit
First of all, we implemented a version of the wordcount script without using Conduit library, to understand the benefits that Conduit provides. 

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

 The rationale is as follows: first of all the function reads from the input.txt file by means of withFile function, then extracts the content with `hGetContents`, and finally accumulates all the words contained in a hashmap by means of a `foldr` used with `(\x v -> insertWith (+) x 1 v)` function. The words are obtained from the `String` read from the file using a combination of `fmap`s: first of all the string is converted in a `Text` with `pack` and split in a series of `Text`s with `words` function, then such words are cleaned from eventual non alphanumberical characters, and finally lowercased due to prevent duplicates.

This non-Conduit example works fine, but the main problem compared to any Conduit version is that the memory usage is not constant: if the file size grows, there is the possibility of a stack overflow exception.


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

This version of the wordcount deals with data in a stram processing style, using Conduit. In particular, the `wordcountC` function contains two monadic actions which run a pipeline each (plus the third monadic action that prints the result).

The first monadic action has the purpose of reading form the input file and accumulate its content in a `Text`. More in detail the steps of the pipeline are:

* the file is read with `sourceFile`, which produces a `ByteString` to be sent downstream. 
* Then the `ByteString` is converted in a Text with `decodeUtf8C`
* Each character of the `ByteString` is mapped to the toLower function, using the `omapCE` function. This is an example of the ability of Conduit to work with chunked data. Here the issue is that instead of
having a stream of `Char` values, we have a stream of `Text` values,
and our `mapC` function will work on the `Text`s. But our `toUpper`
function works on the `Char`s inside of the `Text`. This is where the chunked functions in conduit come into play. In
addition to functions that work directly on the values in a stream, we
have functions that work on the _elements_ inside those values. These
functions get a `CE` suffix instead of `C`.
* At last, the `foldC` accumulates the data from upstream.

Instead of using `runConduit`, the pipeline is run with the helper function `runResourceT`, which is nothing more than `runResourceT . runConduit`. `runResourceT` is contained in the built-in package [resourceT](https://www.stackage.org/package/resourcet) of Conduit and allows to allocate resources and guarantees that they will be cleaned up.

The second monadic action deals with analyzing the `Text` extracted from the first pipeline and counts the words contained into it. More in detail the steps are:

* The `yieldMany (Data.Text.words content)` produces a stream of words starting from the single `Text`.
* The `mapC (Data.Text.filter isAlphaNum)` filters the non alphanumeric characters. Note that in this case we use `mapC` instead of `ompaCE`, because we are not working anymore with each character contained in the stream.
* `foldMC insertInHashMap empty` is a monadic strict left fold to accumulate the words in the hashmap.

This first implementation has a drowback, i.e. the instantiation of two different pipelines to compute the task. The next versions of the task show our attempt to achieve the same results employng only one stream of data.


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
            dropCE 1
            yield word)
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)
```

In this implementation we merged the two pipelines in a single one, using `peekForeverE`. `peekForeverE` is the "chunked" version of the conduit combinator `peekForever`, which continuously runs a conduit as long as there is some input available in a stream. A combinator is an element that when given a conduit, will generate a conduit.

the argument of `peekForeverE` is a monadic action that contains an "inner" conduit, and the steps are as follows:
* With `takeWhileCE` we send downstream all the elements that match the `isAlphaNum` predicate, i.e. in our case we accumulate the chunked stream into a word variable using the `foldC` function.
* With `dropCE 1` we discard from the stream the non alphanumeric character (i.e. the spaces, or other punctuation characters).
* Finally, we `yield` the previously stored word downstream, and in this case the downstream corresponds to `foldMC insertInHashMap empty` of the "outer" conduit.

We can replace `peekForeverE` with `splitOnUnboundedE`, which is a conduit combinator that splits a stream of arbitrarily-chunked data, based on a predicate on the elements, i.e. exactly what we need in our example.

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