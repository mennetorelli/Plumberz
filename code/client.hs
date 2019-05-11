{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Control.Monad (void)
import Data.Conduit.Network
import Data.Word8 (toLower, isAlphaNum)


client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    runConduitRes $ sourceFile "input.txt"
    .| omapCE toLower
    .| peekForeverE (do
        word <- takeWhileCE isAlphaNum
        dropCE 1
        return word)
    .| appSink server


client_stdin :: IO ()
client_stdin = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    runConduit $ stdinC
    .| omapCE toLower
    .| peekForeverE (do
        word <- takeWhileCE isAlphaNum
        dropCE 1
        return word)
    .| appSink server



main :: IO ()
main = do
    putStrLn "1: input from file"
    putStrLn "2: input from stdin"
    choice <- getLine
    case choice of
        "1" -> do 
            client_file
        "2" -> do
            client_stdin

    

