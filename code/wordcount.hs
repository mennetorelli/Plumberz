import Conduit
import Control.Monad
import Data.Char (isAlphaNum)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.List.Split (splitOn)
import Data.Text (pack, unpack, toLower, splitOn, filter, words)
import System.IO

wordcount :: IO ()
wordcount = do
    withFile "input.txt" ReadMode $ \handle -> do
        content <- hGetContents handle
        putStrLn $ show $ foldr
            (\x v -> insertWith (+) x 1 v) 
            empty 
            (fmap (unpack . Data.Text.toLower . pack)
                $ fmap (Prelude.filter isAlphaNum)
                $ Data.List.Split.splitOn " " content)

wordcountC :: IO ()
wordcountC = do
    text <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| foldC
    count <- runConduit $ yieldMany (Data.Text.words text)
        .| mapC (Data.Text.filter isAlphaNum)
        .| mapC (Data.Text.toLower)
        .| sinkList
    print count


main :: IO ()
main = do
    putStrLn "1: wordcount without Conduit"
    putStrLn "2: wordcount with Conduit"
    choice <- getLine
    case choice of
        "1" -> wordcount
        "2" -> wordcountC
        _ -> main
