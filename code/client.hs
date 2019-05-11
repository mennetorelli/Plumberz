{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Control.Monad (void)
import Data.Conduit.Network
import Data.Word8 (toLower, isAlphaNum)

main :: IO ()
main = runTCPClient (clientSettings 4000 "localhost") $ \server ->
    runConduitRes $ sourceFile "input.txt"
    .| omapCE toLower
    .| peekForeverE (do
        word <- takeWhileCE isAlphaNum
        dropCE 1
        return word)
    .| appSink server

