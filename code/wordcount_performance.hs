import System.IO

import Data.Time.Clock

import qualified Wordcount_batch as WCB
import qualified File_generator as FG


main :: IO ()
main = do
    putStrLn "Press 1 to evaluate wordcount"
    putStrLn "Press 2 to evaluate wordcountCv2"
    putStrLn "Press 3 to evaluate wordcountCv3"
    putStrLn "Press 4 to evaluate all versions"
    choice <- getLine
    writeFile "output.txt" ""
    putStrLn "Number of evaluations: "
    evaluations <- getLine
    putStrLn "Create new files? y/n"
    newFile <- getLine
    case newFile of 
        "y" -> do
            putStrLn "File dimensions: "
            fileSizes <- getLine
            let e = read evaluations
                fs = map (read :: String -> Int) (words fileSizes)
            case choice of 
                "1" -> iterate_wc e fs
                "2" -> iterate_wcCv2 e fs
                "3" -> iterate_wcCv3 e fs
                "4" -> do
                    iterate_wc e fs
                    iterate_wcCv2 e fs
                    iterate_wcCv3 e fs
        "n" -> do
            let e = read evaluations
            case choice of 
                "1" -> evaluate_wc e 0
                "2" -> evaluate_wcCv2 e 0
                "3" -> evaluate_wcCv3 e 0
                "4" -> do
                    evaluate_wc e 0
                    evaluate_wcCv2 e 0
                    evaluate_wcCv3 e 0
            


iterate_wc :: Int -> [Int] -> IO ()
iterate_wc _ [] = return ()
iterate_wc n (x:xs) = do
    writeFile "input.txt" ""
    FG.generateFile x
    appendFile "output.txt" ("wordcount, file dimension: " ++ (show x) ++ "\n")
    evaluate_wc n x
    iterate_wc n xs

iterate_wcCv2 :: Int -> [Int] -> IO ()
iterate_wcCv2 _ [] = return ()
iterate_wcCv2 n (x:xs) = do
    writeFile "input.txt" ""
    FG.generateFile x
    appendFile "output.txt" ("wordcountCv2, file dimension: " ++ (show x) ++ "\n")
    evaluate_wcCv2 n x
    iterate_wcCv2 n xs

iterate_wcCv3 :: Int -> [Int] -> IO ()
iterate_wcCv3 _ [] = return ()
iterate_wcCv3 n (x:xs) = do
    writeFile "input.txt" ""
    FG.generateFile x
    appendFile "output.txt" ("wordcountCv3, file dimension: " ++ (show x) ++ "\n")
    evaluate_wcCv3 n x
    iterate_wcCv3 n xs


evaluate_wc 0 _ = return ()
evaluate_wc i x = do
    putStrLn $ "Evaluating wordcount, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    WCB.wordcount
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wc (i-1) x

evaluate_wcCv2 0 _ = return ()
evaluate_wcCv2 i x = do
    putStrLn $ "Evaluating wordcountCv2, " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    WCB.wordcountCv2
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv2 (i-1) x

evaluate_wcCv3 0 _ = return ()
evaluate_wcCv3 i x = do
    putStrLn $ "Evaluating wordcountCv3, " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    WCB.wordcountCv3
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_wcCv3 (i-1) x