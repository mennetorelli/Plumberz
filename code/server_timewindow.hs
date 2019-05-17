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


server :: Int -> IO ()
server timeWindow = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMapMVar <- newMVar empty
    void $ concurrently
        (do 
            hashMap <- runConduit $ appSource appData 
                .| omapCE toLower
                .| CC.splitOnUnboundedE (not . isAlphaNum)
                .| foldMC insertInHashMap empty
            putMVar hashMapMVar hashMap)
        (forever $ do 
            threadDelay timeWindow
            hashMap <- takeMVar hashMapMVar
            runConduit $ yield (pack $ show $ toList hashMap)
                .| appSink appData)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)


main :: IO ()
main = do
    putStrLn "Insert time window (in seconds)"
    timeWindow <- getLine
    server $ (read timeWindow) * 1000000