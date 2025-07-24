#!/usr/bin/env cabal
{- cabal:
build-depends: base
              , ginger
              , text
-}

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Text.Ginger
import Text.Ginger.GVal
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text

main :: IO ()
main = do
  etemplate <- parseGinger resolver Nothing "{{ name }}"
  let template = fromRight (error "Boo") etemplate
  Text.putStrLn $
    runGinger
      (makeContextText context)
      template


resolver name = pure Nothing

context "name" = toGVal ("Artem" :: Text)
