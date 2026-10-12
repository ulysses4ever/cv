{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

-- | cv2txt: cv.txt from cv.tex.
--
-- > runhaskell ./cv2txt.hs [-DNAME]... [--today=DATE] [--no-emphasis] < cv.tex > cv.txt
--
-- It reads the cv.tex that cv.hs writes, so pubs.json is already in it, and
-- it knows only the moderncv and LaTeX commands this CV uses. Any other
-- command in the body stops it with the line number: a command it skipped
-- would drop content from cv.txt without a word, which is what pandoc did to
-- the Experience section.
--
-- The output is plain text with light Markdown: "#" and "##" headings,
-- **bold** and *italic* where the source asks for them (--no-emphasis drops
-- the markers), and each moderncv item as its label (a date, a venue) in a
-- left column with its text beside it, one line per \newline. A link is
-- "text <url>", or the bare url when the text is its tail (a DOI, a preprint).
-- Lines are not wrapped, so an entry pastes into a web form as one line.
--
-- -DNAME makes \ifdefined\NAME true, as \def\NAME{} on the pdflatex command
-- line does: -DTEACHINGEARLY gives the teaching-first order. \today is
-- --today's date; without one the title leaves out its "(Last updated: ...)",
-- so that regenerating cv.txt on another day does not change the file.
module Main (main) where

import Control.Monad (foldM)
import Data.Char (isDigit, isLetter)
import Data.List (intercalate, stripPrefix)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import System.Environment (getArgs)
import System.Exit (die)
import System.IO (hSetEncoding, stdin, stdout, utf8)

main :: IO ()
main = do
  opts <- either die pure . options =<< getArgs
  mapM_ (`hSetEncoding` utf8) [stdin, stdout]
  src <- T.getContents
  either (die . ("cv2txt: " <>)) T.putStr (cv2txt opts src)

data Opts = Opts
  { defines :: [Text]
  , today :: Maybe Text
  , emphasis :: Bool
  }

options :: [String] -> Either String Opts
options = foldM opt (Opts [] Nothing True)
  where
    opt o a = case a of
      '-' : 'D' : name@(_ : _) -> Right o {defines = T.pack name : defines o}
      "--no-emphasis" -> Right o {emphasis = False}
      _ | Just d <- stripPrefix "--today=" a -> Right o {today = Just (T.pack d)}
        | otherwise -> Left ("unknown option " <> a <> "\nusage: cv2txt [-DNAME]... [--today=DATE] [--no-emphasis] < cv.tex > cv.txt")

cv2txt :: Opts -> Text -> Either String Text
cv2txt opts src = do
  let toks = tokenize src
  (preamble, rest) <- maybe (Left "no \\begin{document}") Right (breakAt (document "begin") toks)
  (body, _) <- maybe (Left "no \\end{document}") Right (breakAt (document "end") rest)
  let (fields, predefined) = scanPreamble preamble
  nodes <- parse =<< expand (Set.fromList (defines opts) <> predefined) body
  title <- titleBlock opts fields
  Right (layout title (blocks opts nodes))

-- ##############################################
-- ##                 Tokens                   ##
-- ##############################################

-- | TeX's tokens, each command with its line for the error messages.
data Tok
  = Cmd Int Text -- ^ a control word such as \cvitem, or a symbol such as \&
  | Open Int
  | Close Int
  | Chr Int Char -- ^ any other character
  | Spc -- ^ blanks, or the end of a line
  | Par -- ^ a blank line
  deriving (Eq, Show)

data LineState = NewLine | MidLine | SkipBlanks

-- | TeX's reading rules: blanks after a control word are skipped, and so is
-- a comment with the end of its line and the indentation of the next one.
tokenize :: Text -> [Tok]
tokenize = go NewLine 1 . T.unpack
  where
    go :: LineState -> Int -> String -> [Tok]
    go _ _ [] = []
    go st n (c : cs) = case c of
      '\\' -> case cs of
        d : ds
          | isLetter d, (w, rest) <- span isLetter cs -> Cmd n (T.pack w) : go SkipBlanks n rest
          | d == '\n' -> Cmd n " " : go NewLine (n + 1) ds
          | d == ' ' -> Cmd n " " : go SkipBlanks n ds
          | otherwise -> Cmd n (T.singleton d) : go MidLine n ds
        [] -> []
      '%' -> case break (== '\n') cs of
        (_, _ : rest) -> go NewLine (n + 1) rest
        _ -> []
      '\n' -> case st of
        NewLine -> Par : go NewLine (n + 1) cs
        MidLine -> Spc : go NewLine (n + 1) cs
        SkipBlanks -> go NewLine (n + 1) cs
      '{' -> Open n : go MidLine n cs
      '}' -> Close n : go MidLine n cs
      _
        | c `elem` [' ', '\t', '\r'] -> case st of
            MidLine -> Spc : go SkipBlanks n cs
            _ -> go st n cs
        | otherwise -> Chr n c : go MidLine n cs

at :: Int -> String -> String
at n msg = "line " <> show n <> " of cv.tex: " <> msg

dropSpc :: [Tok] -> [Tok]
dropSpc = dropWhile (== Spc)

-- | The tokens before the marker, and those after it.
breakAt :: ([Tok] -> Maybe [Tok]) -> [Tok] -> Maybe ([Tok], [Tok])
breakAt marker = go []
  where
    go _ [] = Nothing
    go acc ts@(t : rest) = case marker ts of
      Just after -> Just (reverse acc, after)
      Nothing -> go (t : acc) rest

-- | \begin{document} or \end{document}.
document :: Text -> [Tok] -> Maybe [Tok]
document cmd = \case
  Cmd _ c : Open _ : ts | c == cmd -> chars "document" ts
  _ -> Nothing
  where
    chars (x : xs) (Chr _ y : r) | x == y = chars xs r
    chars [] (Close _ : r) = Just r
    chars _ _ = Nothing

-- | The tokens inside a group, after its opening brace; and those after it.
groupBody :: Int -> [Tok] -> Either String ([Tok], [Tok])
groupBody n = go (0 :: Int) []
  where
    go _ _ [] = Left (at n "this { is never closed")
    go d acc (t : ts) = case t of
      Close _ | d == 0 -> Right (reverse acc, ts)
              | otherwise -> go (d - 1) (t : acc) ts
      Open _ -> go (d + 1) (t : acc) ts
      _ -> go d (t : acc) ts

-- | k arguments, each a group or a single token.
arguments :: Int -> Int -> [Tok] -> Either String ([[Tok]], [Tok])
arguments _ 0 ts = Right ([], ts)
arguments n k ts = do
  (a, rest) <- case dropSpc ts of
    Open m : r -> groupBody m r
    t : r | t /= Par, not (isClose t) -> Right ([t], r)
    _ -> Left (at n "a command is short of arguments")
  (as, rest') <- arguments n (k - 1) rest
  Right (a : as, rest')
  where
    isClose = \case Close _ -> True; _ -> False

-- ##############################################
-- ##                 Preamble                 ##
-- ##############################################

-- | The arguments of \familyname, \title, \address and the rest of what
-- \maketitle prints; and the names the preamble defines, for \ifdefined.
-- Nothing else in the preamble reaches the text.
scanPreamble :: [Tok] -> (Map.Map Text [[Tok]], Set.Set Text)
scanPreamble = go Map.empty Set.empty
  where
    go fs ds = \case
      [] -> (fs, ds)
      Cmd _ c : ts
        | c `elem` personal, (args, rest) <- groups ts -> go (Map.insert c args fs) ds rest
        | c `elem` definers, Just name <- definedName ts -> go fs (Set.insert name ds) ts
      _ : ts -> go fs ds ts
    personal = ["firstname", "familyname", "title", "address", "mobile", "phone", "email", "homepage"]
    definers = ["newcommand", "renewcommand", "providecommand", "def", "NewDocumentCommand", "RenewDocumentCommand"]
    definedName ts = case skipStar ts of
      Cmd _ name : _ -> Just name
      Open _ : Cmd _ name : Close _ : _ -> Just name
      _ -> Nothing
    groups ts = case dropSpc ts of
      Open n : r | Right (g, rest) <- groupBody n r, (gs, rest') <- groups rest -> (g : gs, rest')
      _ -> ([], ts)

skipStar :: [Tok] -> [Tok]
skipStar = \case
  Chr _ '*' : r -> r
  r -> r

-- ##############################################
-- ##                 Expansion                ##
-- ##############################################

-- | Expands the body's \newcommand macros and its \ifdefined...\else...\fi.
-- A name is defined if the body, the preamble or -D defines it, or if cv2txt
-- knows it.
expand :: Set.Set Text -> [Tok] -> Either String [Tok]
expand predefined = go (0 :: Int) Map.empty
  where
    go _ _ [] = Right []
    go steps macros (t : ts) = case t of
      _ | steps > 100000 -> Left "macro expansion does not stop"
      Cmd n c
        | c `elem` ["newcommand", "renewcommand", "providecommand"] -> do
            (name, arity, body, rest) <- newcommand n ts
            go steps (Map.insert name (arity, body) macros) rest
        | c == "ifdefined" -> case ts of
            Cmd _ name : rest -> do
              (yes, no, after) <- conditional n rest
              let defined = Map.member name macros || Map.member name commands || Set.member name predefined
              go (steps + 1) macros ((if defined then yes else no) ++ after)
            _ -> Left (at n "\\ifdefined without a command name after it")
        | c `elem` ["else", "fi"] -> Left (at n ("\\" <> T.unpack c <> " outside \\ifdefined"))
        | not (Map.member c commands), Just (arity, body) <- Map.lookup c macros -> do
            (args, rest) <- arguments n arity ts
            go (steps + 1) macros (substitute args body ++ rest)
      _ -> (t :) <$> go steps macros ts

-- | \newcommand{\name}[k]{body}, after the \newcommand.
newcommand :: Int -> [Tok] -> Either String (Text, Int, [Tok], [Tok])
newcommand n ts0 = do
  (name, ts1) <- case skipStar ts0 of
    Cmd _ c : r -> Right (c, r)
    Open _ : Cmd _ c : Close _ : r -> Right (c, r)
    _ -> Left (at n "\\newcommand without a name")
  let (arity, ts2) = case dropSpc ts1 of
        Chr _ '[' : Chr _ d : Chr _ ']' : r | isDigit d -> (read [d], r)
        r -> (0, r)
  case dropSpc ts2 of
    Open m : r -> do
      (body, rest) <- groupBody m r
      Right (name, arity, body, rest)
    Chr _ '[' : _ -> Left (at n "a \\newcommand with an optional argument: cv2txt does not do those")
    _ -> Left (at n "\\newcommand without a body in braces")

-- | #1 to #9 in a macro's body, replaced by the arguments.
substitute :: [[Tok]] -> [Tok] -> [Tok]
substitute args = \case
  Chr _ '#' : Chr _ d : rest
    | isDigit d, i <- read [d] - 1, i >= 0, i < length args -> args !! i ++ substitute args rest
  t : rest -> t : substitute args rest
  [] -> []

-- | After \ifdefined\name: the tokens up to \else or \fi, those from \else
-- to \fi, and those after \fi; a nested \if...\fi is passed over whole.
conditional :: Int -> [Tok] -> Either String ([Tok], [Tok], [Tok])
conditional n = go (0 :: Int) [] Nothing
  where
    go _ _ _ [] = Left (at n "\\ifdefined without its \\fi")
    go d yes no (t : ts) = case t of
      Cmd _ "fi" | d == 0 -> Right (reverse yes, maybe [] reverse no, ts)
      Cmd _ "else" | d == 0, Nothing <- no -> go d yes (Just []) ts
      Cmd _ c
        | "if" `T.isPrefixOf` c -> keep (d + 1)
        | c == "fi" -> keep (d - 1)
      _ -> keep d
      where
        keep d' = case no of
          Nothing -> go d' (t : yes) no ts
          Just ns -> go d' yes (Just (t : ns)) ts

-- ##############################################
-- ##                 Parsing                  ##
-- ##############################################

data Node
  = Str Text -- ^ characters as typed: TeX's ligatures not yet applied
  | Space
  | ParBreak
  | Command Int Text [[Node]]
  | Group [Node]

-- | The commands cv2txt knows, with how many arguments each takes. The
-- moderncv ones may also have moderncv's optional [spacing].
commands :: Map.Map Text Int
commands =
  Map.fromList $
    [ ("section", 1), ("subsection", 1), ("maketitle", 0)
    , ("cventry", 6), ("cvitem", 2), ("cvdoubleitem", 4), ("cvtripleitem", 6), ("cvlistitem", 1)
    , ("textbf", 1), ("emph", 1), ("textit", 1), ("texttt", 1)
    , ("myhref", 2), ("href", 2), ("url", 1)
    , ("newline", 0), ("\\", 0), ("par", 0), ("today", 0)
    ]
      ++ [(c, 1) | c <- dropped]
      ++ [(c, 0) | c <- switches ++ Map.keys symbols]

-- | Commands for the page and not the text, dropped with their argument.
dropped :: [Text]
dropped = ["pagestyle", "thispagestyle", "vspace", "hspace"]

-- | Commands that change only the look of what follows.
switches :: [Text]
switches = ["footnotesize", "scriptsize", "small", "normalsize", "ttfamily", "strut", "noindent"]

-- | Commands that stand for characters.
symbols :: Map.Map Text Text
symbols =
  Map.fromList
    [ ("&", "&"), ("%", "%"), ("_", "_"), ("#", "#"), ("$", "$"), ("{", "{"), ("}", "}")
    , (" ", " "), (",", " "), ("@", ""), ("-", ""), ("/", "")
    , ("ldots", "…"), ("dots", "…"), ("CPP", "C++"), ("CSH", "C#"), ("LaTeX", "LaTeX"), ("TeX", "TeX")
    ]

parse :: [Tok] -> Either String [Node]
parse = \case
  [] -> Right []
  Open n : ts -> do
    (g, rest) <- groupBody n ts
    inner <- parse g
    (Group inner :) <$> parse rest
  Close n : _ -> Left (at n "} without a {")
  Spc : ts -> (Space :) <$> parse ts
  Par : ts -> (ParBreak :) <$> parse ts
  Chr _ c : ts | (cs, rest) <- chars ts -> (Str (T.pack (c : cs)) :) <$> parse rest
  Cmd n c : ts -> case Map.lookup c commands of
    Nothing -> Left (at n ("unknown command \\" <> T.unpack c <> ": teach cv2txt.hs what it means"))
    Just k -> do
      (args, rest) <- arguments n k (if "cv" `T.isPrefixOf` c then spacing ts else ts)
      nodes <- mapM parse args
      (Command n c nodes :) <$> parse rest
  where
    chars = \case
      Chr _ c : r | (cs, r') <- chars r -> (c : cs, r')
      r -> ([], r)
    spacing ts = case dropSpc ts of
      Chr _ '[' : r -> drop 1 (dropWhile (\case Chr _ ']' -> False; _ -> True) r)
      _ -> ts

-- ##############################################
-- ##                 Rendering                ##
-- ##############################################

-- | Pieces of a line: words, the gaps between them, and line breaks.
data Piece = W Text | Gap | Nl

-- | Inline content as lines, one per \newline.
render :: Opts -> [Node] -> [Text]
render opts = map (T.unwords . T.words . T.concat . map word) . splitNl . pieces opts
  where
    word = \case W t -> t; _ -> " "

splitNl :: [Piece] -> [[Piece]]
splitNl ps = case break isNl ps of
  (line, _ : rest) -> line : splitNl rest
  (line, []) -> [line]
  where
    isNl = \case Nl -> True; _ -> False

pieces :: Opts -> [Node] -> [Piece]
pieces opts = concatMap piece
  where
    piece = \case
      Str s -> [W (ligatures s)]
      Space -> [Gap]
      ParBreak -> [Nl]
      Group ns -> pieces opts ns
      Command _ c args -> case (c, args) of
        ("textbf", [a]) -> wrap "**" a
        ("emph", [a]) -> wrap "*" a
        ("textit", [a]) -> wrap "*" a
        ("myhref", [u, a]) -> link (url u) a
        ("href", [u, a]) -> link (url u) a
        ("url", [u]) -> [W (url u)]
        ("today", []) -> [W (fromMaybe "" (today opts))]
        _ | c `elem` ["newline", "\\", "par"] -> [Nl]
          | Just " " <- Map.lookup c symbols -> [Gap]
          | Just s <- Map.lookup c symbols -> [W s]
          | c `elem` dropped || c `elem` switches -> []
          | otherwise -> concatMap (\a -> Gap : pieces opts a) args
    -- Markers go round each line of the content, and hug it.
    wrap marker a
      | emphasis opts = intercalate [Nl] [hug marker l | l <- splitNl (pieces opts a)]
      | otherwise = pieces opts a
    hug marker l = case trimGaps l of
      [] -> []
      l' -> [W marker] ++ l' ++ [W marker]
    trimGaps = reverse . dropWhile isGap . reverse . dropWhile isGap
    isGap = \case Gap -> True; _ -> False
    -- The text "10.1145/3485527" of https://doi.org/10.1145/3485527 says
    -- nothing the url does not, so then the url stands alone. Only text that
    -- looks like an address counts: "slides" stays even at .../slides.
    link u a
      | T.any (`elem` ['.', '/']) t, unslash t `T.isSuffixOf` unslash u = [W u]
      | otherwise = pieces opts a ++ [Gap, W ("<" <> u <> ">")]
      where
        t = T.unwords (render opts a)
        unslash = T.dropWhileEnd (== '/')

-- | A url as typed: escapes undone, and no ligatures or ~ for a space.
url :: [Node] -> Text
url = T.concat . map raw
  where
    raw = \case
      Str s -> s
      Command _ c [] | Just s <- Map.lookup c symbols -> s
      Group ns -> url ns
      _ -> ""

-- | What pdflatex makes of --, ---, `` and '' and the tie ~.
ligatures :: Text -> Text
ligatures s = foldl (\acc (a, b) -> T.replace a b acc) s pairs
  where
    pairs = [("---", "—"), ("--", "–"), ("``", "“"), ("''", "”"), ("~", " ")]

-- ##############################################
-- ##                 Layout                   ##
-- ##############################################

data Block
  = Heading Int Text
  | Paragraph [Text]
  | Item [Text] [Text] -- ^ the label's lines and the text's lines
  | Title -- ^ where \maketitle prints the name and contacts

blocks :: Opts -> [Node] -> [Block]
blocks opts = go []
  where
    go acc = \case
      [] -> para acc
      ParBreak : ns -> para acc ++ go [] ns
      Group inner : ns -> go acc (inner ++ ns)
      Command _ c args : ns | Just bs <- structure c args -> para acc ++ bs ++ go [] ns
      n : ns -> go (n : acc) ns
    para acc = [Paragraph ls | let ls = lines' (reverse acc), not (null ls)]
    lines' = nonEmpty . render opts
    line = T.unwords . lines'
    nonEmpty = filter (not . T.null)
    structure c args = case (c, args) of
      ("section", [t]) -> Just [Heading 1 (line t)]
      ("subsection", [t]) -> Just [Heading 2 (line t)]
      ("maketitle", []) -> Just [Title]
      -- moderncv prints \cventry{date}{what}{where}{city}{grade}{description}
      -- as "what, where, city, grade" beside the date, the description below.
      ("cventry", [date, what, wher, city, grade, desc]) ->
        let first = T.intercalate ", " (nonEmpty (map line [what, wher, city, grade]))
         in Just [Item (lines' date) (nonEmpty [first] ++ lines' desc)]
      ("cvitem", [l, t]) -> Just [Item (lines' l) (lines' t)]
      ("cvdoubleitem", [l1, t1, l2, t2]) -> Just [Item (lines' l1) (lines' t1), Item (lines' l2) (lines' t2)]
      ("cvtripleitem", [l1, t1, l2, t2, l3, t3]) ->
        Just (zipWith Item (map lines' [l1, l2, l3]) (map lines' [t1, t2, t3]))
      ("cvlistitem", [t]) -> Just [Item ["-"] (lines' t)]
      _ -> Nothing

layout :: [Text] -> [Block] -> Text
layout title = T.unlines . tidy . go
  where
    go = \case
      [] -> []
      Title : bs -> title ++ [""] ++ go bs
      Heading 1 t : bs -> ["", "# " <> t, ""] ++ go bs
      Heading _ t : bs -> ["", "## " <> t, ""] ++ go bs
      Paragraph ls : bs -> ls ++ [""] ++ go bs
      bs | (items, rest) <- span isItem bs -> table [(l, t) | Item l t <- items] ++ [""] ++ go rest
    isItem = \case Item {} -> True; _ -> False

-- | moderncv's two columns: each label padded to the widest in the run, then
-- its text. When any item has more than one line, a blank line separates
-- them all.
table :: [([Text], [Text])] -> [Text]
table items = intercalate gap (map rows items)
  where
    width = maximum (0 : map T.length (concatMap fst items))
    gap = ["" | any (\(l, t) -> length l > 1 || length t > 1) items]
    rows (l, t) = zipWith row (pad l) (pad t)
      where
        pad xs = take (max (length l) (length t)) (xs ++ repeat "")
    row l t
      | width == 0 = t
      | otherwise = T.stripEnd (T.justifyLeft width ' ' l <> "  " <> t)

-- | No blanks at line ends, no runs of blank lines, none at either end.
tidy :: [Text] -> [Text]
tidy = trim . squeeze . map T.stripEnd
  where
    squeeze = \case
      a : b : r | T.null a, T.null b -> squeeze (b : r)
      a : r -> a : squeeze r
      [] -> []
    trim = reverse . dropWhile T.null . reverse . dropWhile T.null

-- | What \maketitle prints: the name, the title, the address and contacts.
titleBlock :: Opts -> Map.Map Text [[Tok]] -> Either String [Text]
titleBlock opts fields = do
  name <- T.unwords . filter (not . T.null) . concat <$> mapM (field opts) ["firstname", "familyname"]
  title <- undated . T.unwords <$> field opts {today = Just (fromMaybe "\0" (today opts))} "title"
  address <- T.intercalate ", " . filter (not . T.null) <$> field opts "address"
  contacts <-
    concat
      <$> mapM
        (\(k, label) -> map (label <>) <$> field opts k)
        [("mobile", "Phone: "), ("phone", "Phone: "), ("email", "Email: "), ("homepage", "Homepage: ")]
  Right (filter (not . T.null) [name, title] ++ [""] ++ filter (not . T.null) (address : contacts))
  where
    field o k = mapM (fmap (T.unwords . render o) . parse) (Map.findWithDefault [] k fields)
    -- Without --today, the parenthesis that holds \today goes with it.
    undated t = case T.breakOn "\0" t of
      (_, "") -> t
      (before, after)
        | T.any (== '(') before, T.any (== ')') after ->
            T.unwords (T.words (T.dropEnd 1 (T.dropWhileEnd (/= '(') before) <> " " <> T.drop 1 (T.dropWhile (/= ')') after)))
        | otherwise -> T.replace "\0" "" t
