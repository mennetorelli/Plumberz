{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Control.Concurrent (forkOS, threadDelay, takeMVar, putMVar, newMVar)
import Control.Concurrent.Async
import Control.Monad (forever)
import Data.Conduit.Network
import Data.HashMap.Strict (empty, insertWith, toList)
import System.Timeout

main :: IO ()
main = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMap <- runConduit $ appSource appData 
        .| timedWindow 5000000
    return ()

insertInHashMap x v = do
    return (insertWith (+) v 1 x)

timedWindow t = do
    v <- lift $ newMVar empty
    lift $ async $ timer' t v empty
    wordcount' empty v

timer' w v e = do
    threadDelay w
    c <- takeMVar v
    print $ toList c
    putMVar v e
    timer' w v e

wordcount' e v = do
    x <- await
    s' <- lift $ takeMVar v
    lift $ putMVar v $ insertWith (+) x 1 s'
    wordcount' e v