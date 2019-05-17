{-# LANGUAGE OverloadedStrings #-}

import Data.ByteString.Char8 (pack)
import Data.Word8 (toLower, isAlphaNum)
import Data.HashMap.Strict (empty, insertWith, toList)

import Conduit
import qualified Data.Conduit.Combinators as CC
import Data.Conduit.Network


main2 :: IO ()
main2 = runTCPServer (serverSettings 4000 "*") $ \appData -> 
    runConduit $ appSource appData 
        .| omapCE toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| do
            hashMap <- foldMC insertInHashMap empty
            yield (pack $ show $ hashMap)
            iterMC print 
        .| appSink appData

main :: IO ()
main = runTCPServer (serverSettings 4000 "*") $ \appData -> do
    hashMap <- runConduit $ appSource appData 
        .| omapCE toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| foldMC insertInHashMap empty
    runConduit $ yield (pack $ show $ toList hashMap)
        .| iterMC print
        .| appSink appData

insertInHashMap x v = do
    return (insertWith (+) v 1 x)