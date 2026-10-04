{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main where

import Control.Monad (unless)
import Data.Aeson (toJSON, ToJSON, FromJSON(..), withObject, (.:), (.:?), (.!=), eitherDecodeFileStrict)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Text.Ginger
import Text.Ginger.GVal
import Data.Function ((&))
import Data.Either (fromRight)
import GHC.Generics (Generic)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text

main :: IO ()
main = do
  pubs <- eitherDecodeFileStrict "pubs.json"
    >>= either (fail . ("pubs.json: " <>)) pure
  etemplate <- parseGingerFile'
    ((mkParserOptions resolver) { poDelimiters = myDelimiters })
    "cv.tex.ginger"
  let template = either (error . show) id etemplate
  Text.putStrLn $
    runGinger
      (makeContextText (context pubs))
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

context pubs = \case
  "cfg" ->  toGVal . toJSON $ myConfig
  "pubs" -> toGVal . toJSON $ pubsCv pubs


-- ##############################################
-- ##                 Config                   ##
-- ##############################################

data Config = MkConfig
  { name :: Text
  , email :: Text
  , adr1 :: Text
  , adr2 :: Text
  , tel :: Text
  , web :: Text
  , dblp :: Text
  , gScholar :: Text
  }
  deriving (Generic, ToJSON)


myConfig :: Config
myConfig = MkConfig
  { name = "Artem Pelenitsyn"
  , email = "a@pelenitsyn.top"
  , adr1  = "1308 South St, Apt 1"
  , adr2  = "Lafayette, IN, USA, 47901"
  , tel = "+1-(857)-204-4460"
  , web = "https://a.pelenitsyn.top"
  , dblp = "https://dblp.org/pid/165/7962.html"
  , gScholar = "https://scholar.google.com/citations?user=my1k3PQAAAAJ&hl=en"
  }


-- ##############################################
-- ##                 Publications             ##
-- ##############################################

-- The list itself is in pubs.json, newest first. It is data rather than code
-- so that the homepage (a-pelenitsyn/a-pelenitsyn.github.io) can render the
-- same list: its build fetches the file from this repo.

data Publication = MkPublication
  { title :: Text
  , authors :: [Text]
  , venue :: Text
  , venueshort :: Text
  , year :: Int
  , doi :: Maybe Text
  -- Full URL of a preprint, for papers accepted but not yet published.
  , preprint :: Maybe Text
  , pdf :: Text
  , award :: Maybe Text
  }
  deriving (Generic, ToJSON)

-- title, authors, venue, venueshort and year are required; the rest default
-- to what the list in this file used to fill in. A key the parser does not
-- know is an error rather than ignored: a misspelled "preprint" would
-- otherwise drop out of the CV and the homepage without a word.
instance FromJSON Publication where
  parseJSON = withObject "Publication" \o -> do
    let known = ["title", "authors", "venue", "venueshort", "year", "doi", "preprint", "pdf", "award"]
        unknown = filter (`notElem` known) (map Key.toText (KeyMap.keys o))
    unless (null unknown) $
      fail ("unknown field(s) " <> Text.unpack (Text.intercalate ", " unknown))
    MkPublication
      <$> o .: "title"
      <*> o .: "authors"
      <*> o .: "venue"
      <*> o .: "venueshort"
      <*> o .: "year"
      <*> o .:? "doi"
      <*> o .:? "preprint"
      <*> o .:? "pdf" .!= "unknown.pdf"
      <*> o .:? "award"

-- Underscores are legal in DOIs and URLs but are a subscript to latex.
latexEscape :: Text -> Text
latexEscape = Text.concatMap \case
  '_' -> "\\_"
  c -> Text.pack [c]

pubsCv :: [Publication] -> [Publication]
pubsCv pubs = pubs
  & map (\pub ->
        pub { authors = pub.authors
                          & map (\a -> if a == myConfig.name -- highlight self
                                     then "\\textbf{" <> a <> "}" else a) 
                          -- Hack below for rendering lists: create a singleton list by joining with ", ".
                          -- TODO: there needs to be a separate type for pubs where authors is a single string, perhaps.
                          & Text.intercalate ", "
                          & pure
            , doi = latexEscape <$> pub.doi
            , preprint = latexEscape <$> pub.preprint
        })
  -- don't show arXiv pubs for now (TODO: more robust categorization...)
  & filter \pub ->
        pub.venue /= "arXiv"

-- TODO: populate 'pdf' fields in pubs.json:
-- https://a-pelenitsyn.github.io/Papers/2024-ICS_arkade-knn-rtcore.pdf
-- https://a-pelenitsyn.github.io/Papers/2023-vmil-approximate-type-stability-short.pdf
-- https://a-pelenitsyn.github.io/Papers/2021-julia-type-stability.pdf
-- https://www.di.ens.fr/~zappa/projects/lambdajulia/paper.pdf
-- https://a-pelenitsyn.github.io/Papers/2018-TMPA-effects-vs-transformers-in-parsing.pdf
-- https://a-pelenitsyn.github.io/Papers/2015-PCS-Scala-generics.pdf
-- and so on...

-- Two entries stay out of pubs.json until it can tell a paper from a preprint
-- or a talk. They were commented out of the list that used to be here:
--
-- TODO: arXiv should probably be a "type" of publication once I add support for it
--   { "title": "Type Stability in Julia: Avoiding Performance Pathologies in JIT Compilation (Extended Version)",
--     "authors": ["Artem Pelenitsyn", "Julia Belyakova", "Benjamin Chung", "Ross Tate", "Jan Vitek"],
--     "venue": "arXiv", "venueshort": "arXiv", "year": 2021, "doi": "10.48550/arXiv.2109.01950" }
--
-- TODO: ML4PL should be a talk once talks are supported
--   { "title": "Can we learn some PL theory?: how to make use of a corpus of subtype checks",
--     "authors": ["Artem Pelenitsyn"],
--     "venue": "International Workshop on Machine Learning techniques for Programming Languages",
--     "venueshort": "ML4PL '18", "year": 2018, "doi": "10.1145/3236454.3236471" }
