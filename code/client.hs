{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent.Async (concurrently)
import Data.Functor (void)
import Control.Monad (forever)

import Data.ByteString.Char8 (pack)
import Data.Word8 (_cr)

import Conduit
import Data.Conduit.Network

import Data.Streaming.Network (appRawSocket)
import Network.Socket (shutdown, ShutdownCmd(..))


client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (runConduitRes $ 
            do
                sourceFile "input.txt"
                yield (pack "%")
            .| appSink server)
        (runConduit $ appSource server 
            .| stdoutC)


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


doneWriting = maybe (pure ()) (`shutdown` ShutdownSend) . appRawSocket


main :: IO ()
main = do
    putStrLn "1: input from file"
    putStrLn "2: input from stdin"
    putStrLn "3: exit"
    choice <- getLine
    case choice of
        "1" -> do
            client_file
            putStrLn ""
            main
        "2" -> do
            client_stdin
            putStrLn ""
            main
        _ -> return ()


    

