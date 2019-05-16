{-# LANGUAGE OverloadedStrings #-}
import Control.Concurrent.Async (concurrently)
import Conduit
import Control.Monad (void)
import Data.Conduit.Network


client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (runConduitRes $ sourceFile "input.txt"
            .| appSink server)
        (runConduit $ appSource server 
            .| stdoutC)


client_stdin :: IO ()
client_stdin = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    void $ concurrently
        (runConduit $ stdinC
            .| appSink server)
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
            main
        "2" -> do
            client_stdin
            main
        "3" -> return ()


    

