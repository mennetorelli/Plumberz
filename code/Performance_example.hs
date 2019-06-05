import Data.Char (toUpper, isAlphaNum)

import System.IO

import Conduit

import Data.Time.Clock

import qualified File_generator as FG


iterate_list :: Int -> [Int] -> IO ()
iterate_list _ [] = return ()
iterate_list n (x:xs) = do
    -- List
    appendFile "output.txt" ("List version, list dimension: " ++ (show x) ++ "\n")
    evaluate_list_1 n x
    -- Conduit
    appendFile "output.txt" ("Conduit version, list dimension: " ++ (show x) ++ "\n")
    evaluate_list_2 n x
    iterate_list n xs

evaluate_list_1 :: Int -> Int -> IO ()
evaluate_list_1 0 _ = return ()
evaluate_list_1 i x = do
    putStrLn $ "Evaluating list version, remaining evaluations: " ++ (show i) ++ ", list dimension: " ++ (show x)
    startTime <- getCurrentTime
    print $ foldr (+) 0 (take x [1..])
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_list_1 (i-1) x

    
evaluate_list_2 :: Int -> Int -> IO ()
evaluate_list_2 0 _ = return ()
evaluate_list_2 i x = do
    putStrLn $ "Evaluating Conduit version, remaining evaluations: " ++ (show i) ++ ", list dimension: " ++ (show x)
    startTime <- getCurrentTime
    print $ runConduitPure $ yieldMany [1..] .| takeC x .| sumC
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_list_2 (i-1) x


iterate_file :: Int -> [Int] -> IO ()
iterate_file _ [] = return ()
iterate_file n (x:xs) = do
    FG.generateFile x
    -- Standard
    appendFile "output.txt" ("Standard version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_1 n x
    -- Conduit
    appendFile "output.txt" ("Conduit version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_2 n x
    iterate_file n xs

evaluate_file_1 :: Int -> Int -> IO ()
evaluate_file_1 0 _ = return ()
evaluate_file_1 i x = do
    putStrLn $ "Evaluating standard version, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
          content <- hGetContents input
          hPutStr output $ content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file_1 (i-1) x

evaluate_file_2 :: Int -> Int -> IO ()
evaluate_file_2 0 _ = return ()
evaluate_file_2 i x = do
    putStrLn $ "Evaluating Conduit version, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| encodeUtf8C
        .| sinkFile "outputC.txt"
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file_2 (i-1) x


iterate_file_mf :: Int -> [Int] -> IO ()
iterate_file_mf _ [] = return ()
iterate_file_mf n (x:xs) = do
    FG.generateFile x
    -- Standard
    appendFile "output.txt" ("Standard version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_mf_1 n x
    -- Conduit
    appendFile "output.txt" ("Conduit version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_mf_2 n x
    iterate_file_mf n xs

evaluate_file_mf_1 :: Int ->  Int ->IO ()
evaluate_file_mf_1 0 _ = return ()
evaluate_file_mf_1 i x = do
    putStrLn $ "Evaluating standard version m/f, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
            content <- hGetContents input
            hPutStr output $ filter isAlphaNum $ fmap toUpper content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file_mf_1 (i-1) x

evaluate_file_mf_2 :: Int -> Int -> IO ()
evaluate_file_mf_2 0 _ = return ()
evaluate_file_mf_2 i x = do
    putStrLn $ "Evaluating Conduit version m/f, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE toUpper
        .| filterCE isAlphaNum
        .| encodeUtf8C
        .| sinkFile "outputC.txt"
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file_mf_2 (i-1) x


main :: IO ()
main = do 
    putStrLn "1: sum of numbers in a list"
    putStrLn "2: copy of a file"
    putStrLn "3: copy of a file + map + filter"
    putStrLn "4: both 2 and 3"
    choice <- getLine
    writeFile "output.txt" ""
    putStrLn "Number of evaluations: "  -- 20
    evaluations <- getLine
    let e = read evaluations
    case choice of
        "1" -> do
            putStrLn "Size of lists: "  -- 10000000 40000000 70000000 100000000
            sizes <- getLine
            let s = map (read :: String -> Int) (words sizes)
            iterate_list e s
        "2" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file e s
                "n" -> do
                    evaluate_file_1 e 0
                    evaluate_file_2 e 0
        "3" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file_mf e s
                "n" -> do
                    evaluate_file_mf_1 e 0
                    evaluate_file_mf_2 e 0
        "4" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file e s
                    iterate_file_mf e s
                "n" -> do
                    evaluate_file_1 e 0
                    evaluate_file_2 e 0
                    evaluate_file_mf_1 e 0
                    evaluate_file_mf_2 e 0
    