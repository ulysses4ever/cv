#!/usr/bin/env cabal
{- cabal:
build-depends: base
              , aeson
              , ginger
              , text
default-language: GHC2021
-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DeriveAnyClass #-}

module Main where

import Data.Aeson (toJSON, ToJSON)
import Text.Ginger
import Text.Ginger.GVal
import Data.Either (fromRight)
import GHC.Generics (Generic)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text

main :: IO ()
main = do
  etemplate <- parseGingerFile'
    ((mkParserOptions resolver) { poDelimiters = myDelimiters })
    "cv.tex.ginger"
  let template = either (\e -> error (show e)) id etemplate
  Text.putStrLn $
    runGinger
      (makeContextText context)
      template

myDelimiters = Delimiters
  { delimOpenInterpolation = "<<="
  , delimCloseInterpolation  = ">>"
  , delimOpenTag = "<<"
  , delimCloseTag = ">>"
  , delimOpenComment = "<#"
  , delimCloseComment = "#>"
  }

resolver :: SourceName -> IO (Maybe Source)
resolver i = readFile i >>= pure . Just

context = \case
  "cfg" ->  toGVal . toJSON $ defaultConfig
  "pubs" -> toGVal . toJSON $ pubs

data Config = MkConfig
  { name :: Text
  , email :: Text
  , dblp :: Text
  , gScholar :: Text
  }
  deriving (Generic, ToJSON)

defaultConfig :: Config
defaultConfig = MkConfig
  { name = "Artem"
  , email = "a@pelenitsyn.top"
  , dblp = "https://dblp.org/pid/165/7962.html"
  , gScholar = "https://scholar.google.com/citations?user=my1k3PQAAAAJ&hl=en"
  }

data Publication = MkPublication
  { title :: Text
  , authors :: [Text]
  , venue :: Text
  , year :: Int
  , doi :: Maybe Text
  , pdf :: Text
  }
  deriving (Generic, ToJSON)

pubs =
  [ MkPublication
      { title = "Approximating Type Stability in the Julia JIT (Work in Progress)"
      , authors = ["Artem Pelenitsyn"]
      , venue = "VMIL (Virtual Machines and Intermediate Languages)"
      , year = 2023
      , doi = Just "10.1145/3623507.3623556"
      , pdf = "2023-vmil-approximate-type-stability-short.pdf"
      }
  ]
