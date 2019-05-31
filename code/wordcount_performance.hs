{-# LANGUAGE OverloadedStrings #-}

import Control.Monad

import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (pack, toLower, filter, words)

import System.IO

import Conduit
import qualified Data.Conduit.Combinators as CC

import Data.Time.Clock

import Wordcount_example
import File_generator


main :: IO ()
main = do
    writeFile "output.txt" ""
    putStrLn "Number of evaluations: "
    evaluations <- getLine
    putStrLn "File dimension: "
    fileSizes <- getLine
    evaluate (read evaluations) [2500, 5000, 7500, 10000]

evaluate :: Integer -> [Integer] -> IO ()
evaluate 0 _ = return ()
evaluate n [] = return ()
evaluate n (x:xs) = do
    clearFile
    generateFile x
    appendFile "output.txt" "File size: \n" -- ++ (show x) 
    appendFile "output.txt" "wordcount\n"
    evaluate_wc n (x:xs) n
    appendFile "output.txt" "wordcountCv2\n"
    evaluate_wcCv2 n (x:xs) n
    appendFile "output.txt" "wordcountCv3\n"
    evaluate_wcCv3 n (x:xs) n
    appendFile "output.txt" "\n"
    evaluate n xs


evaluate_wc n (x:xs) 0 = return ()
evaluate_wc n (x:xs) i = do
    startTime <- getCurrentTime
    wordcount
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wc n (x:xs) (i-1)

evaluate_wcCv2 n (x:xs) 0 = return ()
evaluate_wcCv2 n (x:xs) i = do
    startTime <- getCurrentTime
    wordcountCv2
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv2 n (x:xs) (i-1)

evaluate_wcCv3 n (x:xs) 0 = return ()
evaluate_wcCv3 n (x:xs) i = do
    startTime <- getCurrentTime
    wordcountCv3
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv3 n (x:xs) (i-1)