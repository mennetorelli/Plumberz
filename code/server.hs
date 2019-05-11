{-# LANGUAGE OverloadedStrings #-}
import Conduit
import Data.Conduit.Network
import Data.HashMap.Strict (empty, insertWith, toList)

main :: IO ()
main = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMap <- runConduit $ appSource appData 
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)