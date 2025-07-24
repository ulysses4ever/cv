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
  etemplate <- parseGinger resolver Nothing "{{ cfg.name }}"
  let template = fromRight (error "Boo") etemplate
  Text.putStrLn $
    runGinger
      (makeContextText context)
      template


resolver name = pure Nothing

context = \case
  "cfg" ->  toGVal . toJSON $ defaultConfig

data Config = MkConfig
  { name :: Text
  , email :: Text
  }
  deriving (Generic, ToJSON)

defaultConfig :: Config
defaultConfig = MkConfig
  { name = "Artem"
  , email = "a@pelenitsyn.top"
  }
