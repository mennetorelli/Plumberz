import Conduit
import Control.Monad
import Data.Char (isAlphaNum, toLower)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.Text (pack, toLower, filter, words)
import Data.Time.Clock
import System.IO


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

insertInHashMap x v = do
    return (insertWith (+) v 1 x)


wordcountCv2 :: IO ()
wordcountCv2 = do 
    hashMap <- runConduitRes $ sourceFile "input.txt"
        .| decodeUtf8C
        .| omapCE Data.Char.toLower
        .| peekForeverE (do
            word <- takeWhileCE isAlphaNum
            dropCE 1
            return word)
        .| foldMC insertInHashMap empty
    print (toList hashMap)



main :: IO ()
main = do
    putStrLn "1: wordcount without Conduit"
    putStrLn "2: wordcount with Conduit"
    putStrLn "3: wordcount with Conduit v2"
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
        "3" -> do
            startTime <- getCurrentTime
            wordcountCv2
            endTime <- getCurrentTime
            print $ diffUTCTime endTime startTime
        _ -> main