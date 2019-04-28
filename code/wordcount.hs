import Conduit
import Control.Monad
import Data.Char (isAlphaNum)
import Data.HashMap.Strict (empty, insertWith, toList)
import Data.List.Split
import Data.Text (pack, unpack, toLower)
import System.IO

standard :: IO ()
standard = do
    withFile "input.txt" ReadMode $ \handle -> do
        content <- hGetContents handle
        putStrLn $ foldr 
            (++)
            ""
            (fmap (unpack . toLower . pack)
                $ fmap (filter isAlphaNum)
                $ splitOn " " content)



main :: IO ()
main = do
    putStrLn "1: standard wordcount without Conduit"
    choice <- getLine
    case choice of
        "1" -> standard
        _ -> main
