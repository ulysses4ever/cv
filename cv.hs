#!/usr/bin/env cabal
{- cabal:
build-depends:  base
              , aeson
              , ginger
              , text
default-language: GHC2021
-}

{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main where

import Data.Aeson (toJSON, ToJSON)
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
  "cfg" ->  toGVal . toJSON $ myConfig
  "pubs" -> toGVal . toJSON $ pubsCv


-- ##############################################
-- ##                 Datatypes                ##
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


data Publication = MkPublication
  { title :: Text
  , authors :: [Text]
  , venue :: Text
  , venueshort :: Text
  , year :: Int
  , doi :: Maybe Text
  , pdf :: Text
  }
  deriving (Generic, ToJSON)

defaultPub = MkPublication
  { title = error "Untitled"
  , authors = error "Unknown authors"
  , venue = error "Unknown Venue"
  , venueshort = error "Unknown"
  , year = error "Unknown year"
  , doi = Nothing
  , pdf = "unknown.pdf"
  }

-- ##############################################
-- ##                 Config                   ##
-- ##############################################

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

pubsCv :: [Publication]
pubsCv = pubs
  & map (\pub ->
        pub { authors = filter (/= myConfig.name) pub.authors -- don't name self
                          -- Hack for rendering lists: create a singleton list by joining with ", ".
                          -- TODO: there should be another type for pubs, perhaps, where authors is a single string.
                          & (\l -> if null l then l else Text.intercalate ", " l & pure)
            -- escape underscores in DOIs because latex...
            , doi = Text.concatMap (\case
                                       '_' -> "\\_"
                                       c -> Text.pack [c]
                                       ) <$> pub.doi
        })
  -- don't show arXiv pubs for now (TODO: more robust categorization...)
  & filter \pub ->
        pub.venue /= "arXiv"

-- TODO: populate 'pdf' fields for pubs below:
-- https://a-pelenitsyn.github.io/Papers/2024-ICS_arkade-knn-rtcore.pdf
-- https://a-pelenitsyn.github.io/Papers/2023-vmil-approximate-type-stability-short.pdf
-- https://a-pelenitsyn.github.io/Papers/2021-julia-type-stability.pdf
-- https://www.di.ens.fr/~zappa/projects/lambdajulia/paper.pdf
-- https://a-pelenitsyn.github.io/Papers/2018-TMPA-effects-vs-transformers-in-parsing.pdf
-- https://a-pelenitsyn.github.io/Papers/2015-PCS-Scala-generics.pdf
-- and so on...

pubs :: [Publication]
pubs =
  [ defaultPub
      { title = "RT-BarnesHut: Accelerating Barnes-Hut Using Ray-Tracing Hardware"
      , authors = ["Vani Nagarajan", "Rohan Gangaraju", "Kirshanthan Sundararajah", "Artem Pelenitsyn", "Milind Kulkarni"]
      , venue = "ACM SIGPLAN Annual Symposium on Principles and Practice of Parallel Programming"
      , venueshort = "PPoPP '25"
      , year = 2025
      , doi = Just "10.1145/3710848.3710885"
      }
  , defaultPub
      { title = "SparseAuto: An Auto-scheduler for Sparse Tensor Computations using Recursive Loop Nest Restructuring"
      , authors = ["Adhitha Dias", "Logan Anderson", "Kirshanthan Sundararajah", "Artem Pelenitsyn", "Milind Kulkarni"]
      , venue = "Proceedings of the ACM on Programming Languages"
      , venueshort = "OOPSLA '24"
      , year = 2024
      , doi = Just "10.1145/3689730"
      }
  , defaultPub
      { title = "Optimizing Layout of Recursive Datatypes with Marmoset: Or, Algorithms + Data Layouts = Efficient Programs"
      , authors = ["Vidush Singhal", "Chaitanya Koparkar", "Joseph Zullo", "Artem Pelenitsyn", "Michael Vollmer", "Mike Rainey", "Ryan Newton", "Milind Kulkarni"]
      , venue = "European Conference on Object-Oriented Programming"
      , venueshort = "ECOOP '24"
      , year = 2024
      , doi = Just "10.4230/LIPIcs.ECOOP.2024.38"
      }
  , defaultPub
      { title = "Arkade: k-Nearest Neighbor Search With Non-Euclidean Distances using GPU Ray Tracing"
      , authors = ["Durga Keerthi Mandarapu", "Vani Nagarajan", "Artem Pelenitsyn", "Milind Kulkarni"]
      , venue = "ACM International Conference on Supercomputing"
      , venueshort = "ICS '24"
      , year = 2024
      , doi = Just "10.1145/3650200.3656601"
      }
  , defaultPub
      { title = "Garbage Collection for Mostly Serialized Heaps"
      , authors = ["Chaitanya S. Koparkar", "Vidush Singhal", "Aditya Gupta", "Mike Rainey", "Michael Vollmer", "Artem Pelenitsyn", "Sam Tobin-Hochstadt", "Milind Kulkarni", "Ryan R. Newton"]
      , venue = "ACM SIGPLAN International Symposium on Memory Management"
      , venueshort = "ISMM '24"
      , year = 2024
      , doi = Just "10.1145/3652024.3665512"
      }
  , defaultPub
      { title = "SABLE: Staging Blocked Evaluation of Sparse Matrix Computations"
      , authors = ["Pratyush Das", "Adhitha Dias", "Anxhelo Xhebraj", "Artem Pelenitsyn", "Kirshanthan Sundararajah", "Milind Kulkarni"]
      , venue = "arXiv"
      , venueshort = "arXiv"
      , year = 2024
      , doi = Just "10.48550/arXiv.2407.00829"
      }
  , defaultPub
      { title = "Approximating Type Stability in the Julia JIT (Work in Progress)"
      , authors = ["Artem Pelenitsyn"]
      , venue = "ACM SIGPLAN International Workshop on Virtual Machines and Intermediate Languages"
      , venueshort = "VMIL '23"
      , year = 2023
      , doi = Just "10.1145/3623507.3623556"
      , pdf = "2023-vmil-approximate-type-stability-short.pdf"
      }
  , defaultPub
      { title = "Type stability in Julia: avoiding performance pathologies in JIT compilation"
      , authors = ["Artem Pelenitsyn", "Julia Belyakova", "Benjamin Chung", "Ross Tate", "Jan Vitek"]
      , venue = "Proceedings of the ACM on Programming Languages"
      , venueshort = "OOPSLA '21"
      , year = 2021
      , doi = Just "10.1145/3485527"
      }
  -- , defaultPub
  --     { title = "Type Stability in Julia: Avoiding Performance Pathologies in JIT Compilation (Extended Version)"
  --     , authors = ["Artem Pelenitsyn", "Julia Belyakova", "Benjamin Chung", "Ross Tate", "Jan Vitek"]
  --     , venue = "arXiv"
  --     , venueshort = "arXiv"
  --     , year = 2021
  --     , doi = Just "10.48550/arXiv.2109.01950"
      -- }
  , defaultPub
      { title = "Julia subtyping: a rational reconstruction"
      , authors = ["Francesco Zappa Nardelli", "Julia Belyakova", "Artem Pelenitsyn", "Benjamin Chung", "Jeff Bezanson", "Jan Vitek"]
      , venue = "Proceedings of the ACM on Programming Languages"
      , venueshort = "OOPSLA '18"
      , year = 2018
      , doi = Just "10.1145/3276483"
      }
  , defaultPub
      { title = "Can we learn some PL theory?: how to make use of a corpus of subtype checks"
      , authors = ["Artem Pelenitsyn"]
      , venue = "International Workshop on Machine Learning techniques for Programming Languages"
      , venueshort = "ML4PL '18"
      , year = 2018
      , doi = Just "10.1145/3236454.3236471"
      }
  , defaultPub
      { title = "Functional Parser of Markdown Language Based on Monad Combining and Monoidal Source Stream Representation"
      , authors = ["Georgy Lukyanov", "Artem Pelenitsyn"]
      , venue = "International Conference on Tools and Methods for Program Analysis"
      , venueshort = "TMPA '17"
      , year = 2017
      , doi = Just "10.1007/978-3-319-71734-0_8"
      }
  , defaultPub
      { title = "Associated types and constraint propagation for generic programming in Scala"
      , authors = ["Artem Pelenitsyn"]
      , venue = "Programming and Computer Software"
      , venueshort = "PCS"
      , year = 2015
      , doi = Just "10.1134/S0361768815040064"
      }
  ]
