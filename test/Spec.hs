{-# LANGUAGE OverloadedStrings #-}

import qualified Data.Map     as M
import           Data.Text    (Text)
import qualified Data.Text    as T
import           Larceny
import           Test.Hspec
import qualified Text.XmlHtml as X

main :: IO ()
main = spec

page' :: Text
page' = "<body>\
         \ <site-title/>\
              \ <people>\
              \   <p><name/></p>\
              \   <site-title/>\
              \ </people>\
              \</body>"

page'' :: Text
page'' = "<body>\
              \ My site\
              \   <p>Daniel</p>\
              \   My site\
              \   <p>Matt</p>\
              \   My site\
              \   <p>Cassie</p>\
              \   My site\
              \   <p>Libby</p>\
              \   My site\
              \</body>"

              {--
-- to use
subst :: Substitution
subst = (M.fromList [ (Hole "site-title", text "My site")
                    , (Hole "people",
                       \tpl l ->
                       T.concat $ map (\n ->
                                       runTemplate
                                            tpl (M.fromList
                                                 [(Hole "name", text n)])
                                            l)
                       ["Daniel", "Matt", "Cassie", "Libby"])])--}

page :: Template
page = Template $ \m l -> need m [Hole "site-title", Hole "people"] $
                          T.concat ["<body>"
                                 , (m M.! (Hole "site-title")) (Template $ text "") l
                                 , (m M.! (Hole "people")) (add m peopleBody) l
                                 , "</body>"
                                 ]
  where peopleBody :: Template
        peopleBody = Template $ \m l -> need m [Hole "name", Hole "site-title"] $
                                      T.concat ["<p>"
                                               , (m M.! (Hole "name")) (Template $ text "") l
                                               , "</p>"
                                               , (m M.! (Hole "site-title")) (Template $ text "") l
                                               ]

subst :: Substitution
subst = sub [ ("site-title", text "My site")
             , ("name", text "My site")
             , ("person", fill $ sub [("name", text "Daniel")])
             , ("people", mapSub (\n -> sub $ [("name", text n)])
                          ["Daniel", "Matt", "Cassie", "Libby"]) ]

shouldRender :: (Text, Substitution, Library) -> Text -> Expectation
shouldRender (t, s, l) output =
  T.replace " " "" (runTemplate (parse t) s l) `shouldBe`
  T.replace " " "" output

spec :: IO ()
spec = hspec $ do
  describe "parse" $ do
    it "should parse HTML into a Template" $ do
      (page', subst, mempty) `shouldRender` page''
    it "should allow attributes" $ do
      ("<p id=\"hello\">hello</p>", mempty, mempty) `shouldRender` "<p id=\"hello\">hello</p>"

  describe "add" $ do
    it "should allow overriden tags" $ do
      ("<name /><person><name /></person>", subst, mempty) `shouldRender` "My siteDaniel"

  describe "apply" $ do
    it "should allow templates to be included in other templates" $ do
      ("<apply name=\"hello\" />",
       mempty,
       M.fromList [("hello", parse "hello")]) `shouldRender` "hello"
    it "should allow templates with unfilled holes to be included in other templates" $ do
      ("<apply name=\"person\" />",
       sub [("name", text "Daniel")],
       M.fromList [("person", parse "<name />")]) `shouldRender` "Daniel"
    it "should allow templates to be included in other templates" $ do
      ("<apply name=\"person\">Libby</apply>",
       mempty,
       M.fromList [("person", parse "<content />")]) `shouldRender` "Libby"
    it "should allow compicated templates to be included in other templates" $ do
      ("<apply name=\"person\"><p>Libby</p></apply>",
       sub [("food", text "pizza")],
       M.fromList [("person", parse "<food /><content />")])
        `shouldRender` "pizza<p>Libby</p>"

  describe "mapHoles" $ do
    it "should map a substitution over a list" $ do
      (page', subst, mempty) `shouldRender` page''

  describe "attributes" $ do
    it "should apply substitutions to attributes as well" $ do
      ("<p id=\"${name}\"><name /></p>",
       sub [("name", text "McGonagall")],
       mempty) `shouldRender` "<p id=\"McGonagall\">McGonagall</p>"

  -- WAT
    it "should allow you to use attributes as substitutions" $ do
      ("<person alias=\"Bonnie Thunders\"><alias /></person>",
       sub [("person", fill mempty)],
       mempty) `shouldRender` "Bonnie Thunders"

  describe "findUnbound" $ do
    it "should find stuff matching the pattern ${blah}" $ do
      findUnbound [X.Element "p" [("blah", "${blah}")] []] `shouldBe` ["blah"]

  describe "findUnboundAttrs" $ do
    it "should find stuff matching the pattern ${blah}" $ do
      findUnboundAttrs [("blah", "${blah}")] `shouldBe` ["blah"]
