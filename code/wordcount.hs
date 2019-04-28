import Conduit
import Control.Monad
import Data.Char (isAlphaNum)
import Data.List.Split
import Data.Text (pack, unpack, toLower)
import System.IO

standard :: IO ()
standard = do
    withFile "input.txt" ReadMode $ \handle -> do
        content <- hGetContents handle
        putStrLn $ concat 
            $ splitOn " " 
            $ (filter isAlphaNum) 
            $ (unpack . toLower . pack) content



main :: IO ()
main = do
    putStrLn "1: standard wordcount without Conduit"
    choice <- getLine
    case choice of
        "1" -> standard
        _ -> main

