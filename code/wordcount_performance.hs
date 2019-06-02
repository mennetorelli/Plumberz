import System.IO

import Data.Time.Clock

import Wordcount_batch
import File_generator


main :: IO ()
main = do
    writeFile "output.txt" ""
    putStrLn "Number of evaluations: "
    evaluations <- getLine
    putStrLn "File dimension: "
    fileSizes <- getLine
    evaluate (read evaluations) (map (read :: String -> Int) (words fileSizes))


evaluate :: Int -> [Int] -> IO ()
evaluate 0 _ = return ()
evaluate n [] = return ()
evaluate n (x:xs) = do
    writeFile "input.txt" ""
    generateFile x
    appendFile "output.txt" ("File size: " ++ (show x) ++ "\n")
    putStrLn $ "Evaluating wordcount, file dimension: " ++ (show x)
    appendFile "output.txt" "wordcount\n"
    evaluate_wc n
    putStrLn $ "Evaluating wordcount, file dimension: " ++ (show x)
    appendFile "output.txt" "wordcountCv2\n"
    evaluate_wcCv2 n
    putStrLn $ "Evaluating wordcount, file dimension: " ++ (show x)
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