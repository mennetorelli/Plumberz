{-# LANGUAGE OverloadedStrings #-}

module Wordcount_batch (
    wordcount,
    wordcountC,
    wordcountCv2,
    wordcountCv3,
    insertInHashMap) where

import Control.Monad

import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (pack, toLower, filter, words)

import System.IO

import Conduit
import qualified Data.Conduit.Combinators as CC

import Data.Time.Clock


wordcount :: IO ()
wordcount = withFile "input.txt" ReadMode $ \handle -> do
    content <- hGetContents handle
    print $ toList $ foldr
        (\x v -> insertWith (+) x 1 v) 
        empty 
        (fmap Data.Text.toLower 
            $ fmap (Data.Text.filter isAlphaNum)
            $ (Data.Text.words . pack) content)


wordcountC :: IO ()
wordcountC = do
    content <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| foldC
    hashMap <- runConduit $ yieldMany (Data.Text.words content)
        .| mapC (Data.Text.filter isAlphaNum)
        .| foldMC insertInHashMap empty
    print (toList hashMap)


wordcountCv2 :: IO ()
wordcountCv2 = do 
    hashMap <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| peekForeverE (do
            word <- takeWhileCE isAlphaNum .| foldC
            dropWhileCE (not . isAlphaNum)
            yield word)
        .| foldMC insertInHashMap empty
    print (toList hashMap)


wordcountCv3 :: IO ()
wordcountCv3 = do 
    hashMap <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| CC.splitOnUnboundedE (not . isAlphaNum)
        .| foldMC insertInHashMap empty
    print (toList hashMap)


insertInHashMap x v = do
    return (insertWith (+) v 1 x)



main :: IO ()
main = do
    putStrLn "1: wordcount without Conduit"
    putStrLn "2: wordcount with Conduit"
    putStrLn "3: wordcount with Conduit v2"
    putStrLn "4: wordcount with Conduit v3"
    choice <- getLine
    case choice of
        "1" -> forever $ do
            startTime <- getCurrentTime
            wordcount
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
            appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
            -- main
        "2" -> do
            startTime <- getCurrentTime
            wordcountC
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
            main
        "3" -> forever $ do
            startTime <- getCurrentTime
            wordcountCv2
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
            appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
            -- main
        "4" -> forever $ do
            startTime <- getCurrentTime
            wordcountCv3
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
            appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
            -- main
        "quit" -> return ()
        _ -> do
            putStrLn "Invalid command"
            main
