{-# LANGUAGE OverloadedStrings #-}

import Control.Monad (forever)
import Data.Functor (void)

import Data.ByteString.Char8 (pack)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Word8 (toLower, isAlphaNum)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network

import Control.Concurrent (forkOS, threadDelay, takeMVar, putMVar, newMVar)
import Control.Concurrent.Async
import System.Timeout


main2 :: IO ()
main2 = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMap <- runConduit $ appSource appData 
        .| timedWindow 5000000
    return ()


main :: IO ()
main = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMapMVar <- newMVar empty
    void $ concurrently
        (do 
            hashMap <- runConduit $ appSource appData 
                .| omapCE toLower
                .| CC.splitOnUnboundedE (not . isAlphaNum)
                .| foldMC insertInHashMap empty
            putMVar hashMapMVar hashMap)
        (forever $ do 
            threadDelay 5000000
            hashMap <- takeMVar hashMapMVar
            print $ toList hashMap)
            -- runConduit $ yield (pack $ show $ toList hashMap)
            --    .| iterMC print)
            --    .| appSink appData)


timedWindow t = do
    v <- lift $ newMVar empty
    lift $ async $ timer' t v empty
    wordcount' empty v

timer' w v e = do
    threadDelay w
    c <- takeMVar v
    print $ toList c
    putMVar v e
    timer' w v e

wordcount' e v = do
    x <- await
    s' <- lift $ takeMVar v
    lift $ putMVar v $ insertWith (+) x 1 s'
    wordcount' e v


insertInHashMap x v = do
    return (insertWith (+) v 1 x)