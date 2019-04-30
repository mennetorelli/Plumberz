import Conduit
import Control.Monad
import Data.Char (isAlphaNum)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (pack, unpack, toLower, splitOn, filter, words)
import Data.Time.Clock
import System.IO


wordcount :: IO ()
wordcount = withFile "input.txt" ReadMode $ \handle -> do
    content <- hGetContents handle
    print $ toList $ foldr
        (\x v -> insertWith (+) x 1 v) 
        empty 
        (fmap toLower 
            $ fmap (Data.Text.filter isAlphaNum)
            $ (Data.Text.words . pack) content)


wordcountC :: IO ()
wordcountC = do
    content <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| foldC
    hashMap <- runConduit $ yieldMany (Data.Text.words content)
        .| mapC (Data.Text.filter isAlphaNum)
        .| mapC toLower
        .| foldMC insertInHashMap empty
    print (toList hashMap)

insertInHashMap x v = do
    return (insertWith (+) v 1 x)


main :: IO ()
main = do
    putStrLn "1: wordcount without Conduit"
    putStrLn "2: wordcount with Conduit"
    choice <- getLine
    case choice of
        "1" -> do 
            startTime <- getCurrentTime
            wordcount
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
        "2" -> do
            startTime <- getCurrentTime
            wordcountC
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
        _ -> main
