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


server :: IO ()
server = runTCPServer (serverSettings 4000 "*") $ \appData -> forever $ do
    hashMap <- runConduit $ appSource appData 
        .| takeWhileCE (/= _percent)
        .| omapCE toLower
        .| do 
            CC.splitOnUnboundedE (not . isAlphaNum)
            dropWhileC (/= "")
        .| foldMC insertInHashMap empty
    runConduit $ yield (pack $ show $ toList hashMap)
        .| appSink appData


server_tw :: Int -> IO ()
server_tw timeWindow = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMapMVar <- newMVar empty
    void $ concurrently
        (forever $ do 
            hashMap <- runConduit $ appSource appData
                .| takeWhileCE (/= _percent)
                .| omapCE toLower
                .| do 
                    CC.splitOnUnboundedE (not . isAlphaNum)
                    dropWhileC (/= "")
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


main :: IO ()
main = do
    putStrLn "1: server without time window"
    putStrLn "2: server with time window"
    choice <- getLine
    case choice of
        "1" -> do
            putStrLn "Server started"
            server
        "2" -> do
            putStrLn "Insert time window (in seconds)"
            timeWindow <- getLine
            putStrLn "Server started"
            server_tw $ (read timeWindow) * 1000000
        _ -> do
            putStrLn "Invalid command"
            main