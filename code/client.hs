{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Control.Concurrent.Async (concurrently)
import Control.Monad (void)
import Data.Conduit.Network

main :: IO ()
main =
    runTCPClient (clientSettings 4000 "localhost") $ \server ->
        void $ concurrently
            (runConduit $ stdinC .| appSink server)
            (runConduit $ appSource server .| stdoutC)