import Data.Char (toUpper, isAlphaNum)

import System.IO

import Conduit

import Data.Time.Clock

import qualified File_generator as FG


iterate_list :: Int -> [Int] -> IO ()
iterate_list _ [] = return ()
iterate_list n (x:xs) = do
    appendFile "output.txt" ("List version, list dimension: " ++ (show x) ++ "\n")
    evaluate_list n x
    iterate_list n xs

evaluate_list :: Int -> Int -> IO ()
evaluate_list 0 _ = return ()
evaluate_list i x = do
    putStrLn $ "Evaluating list version, remaining evaluations: " ++ (show i) ++ ", list dimension: " ++ (show x)
    startTime <- getCurrentTime
    print $ foldr (+) 0 (take x [1..])
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_list (i-1) x


iterate_listC :: Int -> [Int] -> IO ()
iterate_listC _ [] = return ()
iterate_listC n (x:xs) = do
    appendFile "output.txt" ("Conduit version, list dimension: " ++ (show x) ++ "\n")
    evaluate_listC n x
    iterate_listC n xs
    
evaluate_listC :: Int -> Int -> IO ()
evaluate_listC 0 _ = return ()
evaluate_listC i x = do
    putStrLn $ "Evaluating Conduit version, remaining evaluations: " ++ (show i) ++ ", list dimension: " ++ (show x)
    startTime <- getCurrentTime
    print $ runConduitPure $ yieldMany [1..] .| takeC x .| sumC
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_listC (i-1) x


iterate_file :: Int -> [Int] -> IO ()
iterate_file _ [] = return ()
iterate_file n (x:xs) = do
    FG.generateFile x
    appendFile "output.txt" ("Standard version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file n x
    iterate_file n xs

evaluate_file :: Int -> Int -> IO ()
evaluate_file 0 _ = return ()
evaluate_file i x = do
    putStrLn $ "Evaluating standard version, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
          content <- hGetContents input
          hPutStr output $ content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file (i-1) x


iterate_fileC :: Int -> [Int] -> IO ()
iterate_fileC _ [] = return ()
iterate_fileC n (x:xs) = do
    FG.generateFile x
    appendFile "output.txt" ("Conduit version, file dimension: " ++ (show x) ++ "\n")
    evaluate_fileC n x
    iterate_fileC n xs

evaluate_fileC :: Int -> Int -> IO ()
evaluate_fileC 0 _ = return ()
evaluate_fileC i x = do
    putStrLn $ "Evaluating Conduit version, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| encodeUtf8C
        .| sinkFile "outputC.txt"
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_fileC (i-1) x


iterate_file_mf :: Int -> [Int] -> IO ()
iterate_file_mf _ [] = return ()
iterate_file_mf n (x:xs) = do
    FG.generateFile x
    appendFile "output.txt" ("Standard version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_mf n x
    iterate_file_mf n xs

evaluate_file_mf :: Int ->  Int ->IO ()
evaluate_file_mf 0 _ = return ()
evaluate_file_mf i x = do
    putStrLn $ "Evaluating standard version m/f, remaining evaluations: " ++ (show i) ++ ", file dimension: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
            content <- hGetContents input
            hPutStr output $ filter isAlphaNum $ fmap toUpper content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    appendFile "output.txt" (show (diffUTCTime endTime startTime) ++ "\n")
    evaluate_file_mf (i-1) x


iterate_file_mfC :: Int -> [Int] -> IO ()
iterate_file_mfC _ [] = return ()
iterate_file_mfC n (x:xs) = do
    FG.generateFile x
    appendFile "output.txt" ("Conduit version, file dimension: " ++ (show x) ++ "\n")
    evaluate_file_mfC n x
    iterate_file_mfC n xs

evaluate_file_mfC :: Int -> Int -> IO ()
evaluate_file_mfC 0 _ = return ()
evaluate_file_mfC i x = do
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
    evaluate_file_mfC (i-1) x


main :: IO ()
main = do 
    putStrLn "LIST REDUCtION EVALUATION"
    putStrLn "1: sum of numbers in a list"
    putStrLn "1: sum of numbers in a list, Conduit version"
    putStrLn "3: both 1 and 2"
    putStrLn "COPY OF FILE EVALUATION"
    putStrLn "4: copy of a file"
    putStrLn "5: copy of a file, Conduit version"
    putStrLn "6: both 4 and 5"
    putStrLn "7: copy of a file + map + filter"
    putStrLn "8: copy of a file + map + filter, Conduit version"
    putStrLn "9: both 7 and 8"
    putStrLn "10: all file evaluations"
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
            putStrLn "Size of lists: "  -- 10000000 40000000 70000000 100000000
            sizes <- getLine
            let s = map (read :: String -> Int) (words sizes)
            iterate_listC e s
        "3" -> do
            putStrLn "Size of lists: "  -- 10000000 40000000 70000000 100000000
            sizes <- getLine
            let s = map (read :: String -> Int) (words sizes)
            iterate_list e s
            iterate_listC e s
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
                "n" -> evaluate_file e 0
        "5" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_fileC e s
                "n" -> evaluate_fileC e 0
        "6" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file e s
                    iterate_fileC e s
                "n" -> do
                    evaluate_file e 0
                    evaluate_fileC e 0
        "7" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file_mf e s
                "n" -> evaluate_file_mf e 0
        "8" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file_mfC e s
                "n" -> evaluate_file_mfC e 0
        "9" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file_mf e s
                    iterate_file_mfC e s
                "n" -> do
                    evaluate_file_mf e 0
                    evaluate_file_mfC e 0
        "10" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file e s
                    iterate_fileC e s
                    iterate_file_mf e s
                    iterate_file_mfC e s
                "n" -> do
                    evaluate_file e 0
                    evaluate_fileC e 0
                    evaluate_file_mf e 0
                    evaluate_file_mfC e 0
    