{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Control.Monad (void)
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network
import Data.Word8 (toLower, isAlphaNum)


client_file :: IO ()
client_file = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    runConduitRes $ sourceFile "input.txt"
    .| omapCE toLower
    .| CC.splitOnUnboundedE (not . isAlphaNum)
    .| appSink server


client_stdin :: IO ()
client_stdin = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    runConduit $ stdinC
    .| omapCE toLower
    .| CC.splitOnUnboundedE (not . isAlphaNum)
    .| appSink server



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


    

