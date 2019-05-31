import System.IO

import Data.Time.Clock

import Wordcount_batch
import File_generator


main :: IO ()
main = do
    writeFile "output.txt" ""
    putStrLn "Number of evaluations: "
    evaluations <- getLine
    --putStrLn "File dimension: "
    --fileSizes <- getLine
    evaluate (read evaluations) [2500, 5000, 7500, 10000, 12500, 15000]

evaluate :: Integer -> [Integer] -> IO ()
evaluate 0 _ = return ()
evaluate n [] = return ()
evaluate n (x:xs) = do
    writeFile "input.txt" ""
    generateFile x
    appendFile "output.txt" ("File size: " ++ (show x) ++ "\n")
    appendFile "output.txt" "wordcount\n"
    evaluate_wc n
    appendFile "output.txt" "wordcountCv2\n"
    evaluate_wcCv2 n
    appendFile "output.txt" "wordcountCv3\n"
    evaluate_wcCv3 n
    appendFile "output.txt" "\n"
    evaluate n xs


evaluate_wc 0 = return ()
evaluate_wc i = do
    startTime <- getCurrentTime
    wordcount
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wc (i-1)

evaluate_wcCv2 0 = return ()
evaluate_wcCv2 i = do
    startTime <- getCurrentTime
    wordcountCv2
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv2 (i-1)

evaluate_wcCv3 0 = return ()
evaluate_wcCv3 i = do
    startTime <- getCurrentTime
    wordcountCv3
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv3 (i-1)