import Data.Char (toUpper, isAlphaNum)

import System.IO

import Conduit

import Data.Time.Clock

import qualified File_generator as FG


iterate_list :: [Int] -> IO ()
iterate_list [] = return ()
iterate_list (x:xs) = do
    evaluate_list x
    iterate_list xs

evaluate_list :: Int -> IO ()
evaluate_list n = do
    -- List
    putStrLn $ "List version, size: " ++ (show n)
    startTime <- getCurrentTime
    print $ foldr (+) 0 (take n [1..])
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    -- Conduit
    putStrLn $ "Conduit version, size: " ++ (show n)
    startTime <- getCurrentTime
    print $ runConduitPure $ yieldMany [1..] .| takeC n .| sumC
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime


iterate_file :: [Int] -> IO ()
iterate_file [] = return ()
iterate_file (x:xs) = do
    FG.generateFile x
    evaluate_file x
    iterate_file xs

evaluate_file :: Int -> IO ()
evaluate_file x = do
    -- Standard
    putStrLn $ "Standard version, file size: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
          content <- hGetContents input
          hPutStr output $ content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    -- Conduit
    putStrLn $ "Conduit version, file size: " ++ (show x)
    startTime <- getCurrentTime
    runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| encodeUtf8C
        .| sinkFile "outputC.txt"
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime


iterate_file_mf :: [Int] -> IO ()
iterate_file_mf [] = return ()
iterate_file_mf (x:xs) = do
    FG.generateFile x
    evaluate_file_mf x
    iterate_file_mf xs

evaluate_file_mf :: Int -> IO ()
evaluate_file_mf x = do
    -- Standard
    putStrLn $ "Standard version, file size: " ++ (show x)
    startTime <- getCurrentTime
    withFile "input.txt" ReadMode $ \input ->
        withFile "outputS.txt" WriteMode $ \output -> do
            content <- hGetContents input
            hPutStr output $ filter isAlphaNum $ fmap toUpper content
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime
    -- Conduit
    putStrLn $ "Conduit version, file size: " ++ (show x)
    startTime <- getCurrentTime
    runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE toUpper
        .| filterCE isAlphaNum
        .| encodeUtf8C
        .| sinkFile "outputC.txt"
    endTime <- getCurrentTime
    print $ diffUTCTime endTime startTime


main :: IO ()
main = do 
    putStrLn "1: sum of numbers in a list"
    putStrLn "2: copy of a file"
    putStrLn "3: copy of a file + map"
    choice <- getLine
    case choice of
        "1" -> do
            putStrLn "Size of lists: " -- 10000000
            sizes <- getLine
            let s = map (read :: String -> Int) (words sizes)
            iterate_list s
        "2" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file s
                "n" -> evaluate_file 0
        "3" -> do
            putStrLn "Generate new files? y/n"
            newFiles <- getLine
            case newFiles of
                "y" -> do
                    writeFile "input.txt" ""
                    putStrLn "Size of files: "  -- 10000 30000 50000 
                    sizes <- getLine
                    let s = map (read :: String -> Int) (words sizes)
                    iterate_file_mf s
                "n" -> evaluate_file_mf 0
    