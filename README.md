# Intro
This project extends the research conducted by [Luca Lodi](https://github.com/lulogit) and [Philippe Scorsolini](https://github.com/phisco) 
for the course of "Principles of Programming Languages" at Politecnico di Milano 
by prof. Matteo Pradella and with the supervision of [Riccardo Tommasini](https://github.com/riccardotommasini). 
For more information, visit [their repository on GitHub](https://github.com/plumberz/plumberz.github.io)

While the previous research was focused on examining [Pipes](https://hackage.haskell.org/package/pipes) 
and [Tubes](https://hackage.haskell.org/package/tubes) libraries for stream processing in Haskell, 
this research focuses on the [Conduit](https://hackage.haskell.org/package/conduit) library.

# Conduit library
As the tutorial on the homepage of [Conduit's official reopsitory](https://github.com/snoyberg/conduit) explains, 
Conduit is a framework for dealing with streaming data, which standardizes various interfaces for streams of data, 
and allows a consistent interface for transforming, manipulating, and consuming that data. 
The main benefits that Conduit provides are constant memory and deterministic resource usage.

Since Conduit deals with streams of data, such data flows through a **pipeline**, which is the main concept of Conduit. 
Each component of a pipeline can consume data from **upstream**, and produce data to send **downstream**. 
For instance, this is an example of a Conduit pipeline:

```haskell
runConduit $ yieldMany [1..10] .| mapC (*2) .| mapC show .| mapM_C print
```

Each component of the pipeline consumes a stream of data from upstream, and produces a stream of data to be sent downstream. 
For instance, from the perspecive of `mapC (*2)`, `yieldMany [1..10]` is its upstream and `mapC show` is its downstream.

* `yieldMany` consumes nothing from upstream, and produces a stream of `Int`s.
* `mapC (*2)` consumes a stream of `Int`s, and produces a stream of `Int`s.
* `mapC show` consumes a stream of `Int`s, and produces a stream of `String`s.
* `mapM_C print` consumes a stream of `String`s, and produces nothing to downstream.
* If we combine for insance the first three components together, 
  we get something which consumes nothing from upstream, and produces a stream of `String`s.

To add some type signatures into this:

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
  Notice how this matches the input of both `mapC`, which is what lets us combine these two. 
  The output of the second `mapC` is `String`.
* The third indicates the base monad, which tells us what kinds of effects we can perform. 
  A `ConduitT` is a **monad transformer**, so it's possible to use `lift` to perform effects. 
  In our example we are using `IO` as base monad, because we used `print` in the last component.
* The final indicates the result type of the component. 
  This is typically only used for the most downstream component in a pipeline.
  In our example we have `()`, since `mapM_C print` doesn't have a result value, 
  but we could have for instance a pipeline like `yieldMany [1..10] .| mapC (*2) .| sumC`, 
  where the most downstream component `sumC` gets the sum of all values in the stream, and therefore results in a `Int` value.

 The components of a pipeline are connected to the `.|` operator, which type is:
 
 ```haskell
(.|) :: Monad m => ConduitT a b m () -> ConduitT b c m r -> ConduitT a c m r
```

This is prefectly in line with our example, and more in detail shows us that:
* The output from the first component must match the input from the second.
* We ignore the result type from the first component, and keep the result of the second.
* The combined component consumes the same type as the first component and produces the same type as the second component.
* Everything has to run in the same base monad.

Finally, a pipeline is run with the `runConduit` function, which has type signature:
 
```haskell
runConduit :: Monad m => ConduitT () Void m r -> m r
```

This gives us a better idea of what a pipeline is: just a self contained component, 
which consumes nothing from upstream, denoted by `()`,  and producing nothing to downstream, denoted by `Void`. 
(In practice, `()` and `Void` basically indicate the same thing)
When we have such a stand-alone component, we can run it to extract a monadic action that will return a result (the `m r`).

# Batch wordcount with Conduit
To understand better how the library works, we implemented a simple wordcount script. 
The rationale is the following: the script reads from a .txt file, and counts occurrences of all the words contained into it, 
and finally prints the result to the user. 

All the versions described in this section are in the [wordcount_example.hs](code/wordcount_example.hs) file.

## Batch version without Conduit
First of all, we implemented a version of the wordcount script without using Conduit library, 
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

 The rationale is as follows: first of all the function reads from the input.txt file by means of withFile function, 
 then extracts the content with `hGetContents`, 
 and finally accumulates all the words contained in a hashmap by means of a `foldr` used with `(\x v -> insertWith (+) x 1 v)` function. 
 The words are obtained from the `String` read from the file using a combination of `fmap`s: 
 first of all the string is converted in a `Text` with `pack` and split in a series of `Text`s with `words` function, 
 then such words are cleaned from eventual non alphanumerical characters, and finally lowercased due to prevent duplicates.

This non-Conduit example works fine, but the main problem compared to any Conduit version is that the memory usage is not constant: 
the more the file size grows, the more there are possibilities of a stack overflow exception.


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
            dropCE 1
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
we can combine simple conduits in more complex ones using the standard monadic interface (or do-notation).
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


# Distributed wordcount with network-conduit and async
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
To achieve this, we again rely on the `concurrently` of the `Control.Concurrent.Async` package. 
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