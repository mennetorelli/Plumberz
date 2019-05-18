{-# LANGUAGE OverloadedStrings #-}

import Control.Monad (forever)
import Data.Functor (void)

import Data.ByteString.Char8 (pack)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Word8 (toLower, isAlphaNum, _percent)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network

import Control.Concurrent (threadDelay, takeMVar, putMVar, newMVar)
import Control.Concurrent.Async
import System.Timeout


server :: IO ()
server = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMap <- runConduit $ appSource appData 
        .| takeWhileCE (/= _percent)
        .| omapCE toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| foldMC insertInHashMap empty
    runConduit $ yield (pack $ show $ toList hashMap)
        .| iterMC print
        .| appSink appData

insertInHashMap x v = do
    return (insertWith (+) v 1 x)


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
            putMVar hashMapMVar hashMap)
        (forever $ do 
            threadDelay timeWindow
            hashMap <- takeMVar hashMapMVar
            runConduit $ yield (pack $ show $ toList hashMap)
                .| iterMC print
                .| appSink appData)


{-server_tw2 :: Int -> IO ()
server_tw2 timeWindow = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    timeOut <- newMVar False
    void $ concurrently
        (do 
            hashMap <- runConduit $ appSource appData 
                .| omapCE toLower
                .| CC.splitOnUnboundedE (not . isAlphaNum)
                .| do
                    timeOutValue <- takeMVar timeOut
                    if timeOutValue == True
                        then foldMC insertInHashMap empty
                        else lift $ return ()
            runConduit $ yield (pack $ show $ toList hashMap)
                .| iterMC print
                .| appSink appData)
        (forever $ do 
            threadDelay timeWindow
            putMVar timeOut True)-}
            


main :: IO ()
main = do
    putStrLn "Server without time window"
    putStrLn "Server with time window"
    choice <- getLine
    case choice of
        "1" -> server
        "2" -> do
            putStrLn "Insert time window (in seconds)"
            timeWindow <- getLine
            server_tw $ (read timeWindow) * 1000000