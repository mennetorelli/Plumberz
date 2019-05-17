{-# LANGUAGE OverloadedStrings #-}

import Control.Concurrent.Async (concurrently)
import Data.Functor (void)

import Conduit
import Data.Conduit.Network

import Data.Streaming.Network (appRawSocket)
import Network.Socket (shutdown, ShutdownCmd(..))


client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        ((runConduitRes $ sourceFile "input.txt" 
            .| appSink server) >> doneWriting server)
        (runConduit $ appSource server 
            .| stdoutC)

doneWriting = maybe (pure ()) (`shutdown` ShutdownSend) . appRawSocket


client_stdin :: IO ()
client_stdin = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        ((runConduit $ stdinC
            .| appSink server) >> doneWriting server)
        (runConduit $ appSource server 
            .| stdoutC)



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


    

