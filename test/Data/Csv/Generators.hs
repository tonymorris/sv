module Data.Csv.Generators (
  genCsv
  , genNewline
  , genSep
  , genFinalRecord
  , genBetween
  , genEscaped
  , genQuote
  , genField
  , genRecord
  , genRecords
  , genNonEmptyRecord
  , genPesarated
  , genSeparated
  , genHeaded
  , genHeader
) where

import Control.Applicative ((<$>), liftA2, liftA3)
import Data.Separated      (Pesarated (Pesarated), Separated (Separated))
import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Data.Csv.Csv        (Csv (Csv))
import Data.Csv.Field      (Field' (QuotedF, UnquotedF), downmix)
import Data.Csv.Headed     (Header (Header), Headed (Headed))
import Data.Csv.Record     (Record (Record), NonEmptyRecord (SingleFieldNER, MultiFieldNER), FinalRecord (FinalRecord), Records (Records))
import Data.List.AtLeastTwo (AtLeastTwo (AtLeastTwo))
import Text.Between        (Between (Between))
import Text.Escaped        (Escaped', escapeNel)
import Text.Newline        (Newline (CRLF, LF))
import Text.Space          (Spaces, Spaced)
import Text.Quote          (Quote (SingleQuote, DoubleQuote), Quoted (Quoted))

genCsv :: Gen Char -> Gen Spaces -> Gen s1 -> Gen s2 -> Gen (Csv s1 s2)
genCsv sep spc s1 s2 =
  let rs = genRecords spc s2
      e  = genFinalRecord spc s1 s2
  in  liftA3 Csv sep rs e

genNewline :: Gen Newline
genNewline =
  -- TODO put CR back in
  Gen.element [CRLF, LF]

genSep :: Gen Char
genSep =
  Gen.element ['|', ',']

genFinalRecord :: Gen Spaces -> Gen s1 -> Gen s2 -> Gen (FinalRecord s1 s2)
genFinalRecord spc s1 s2 =
  FinalRecord <$> Gen.maybe (genNonEmptyRecord spc s1 s2)

genBetween :: Gen Spaces -> Gen str -> Gen (Spaced str)
genBetween spc str =
  liftA3 Between spc str spc

genQuote :: Gen Quote
genQuote =
  Gen.element [SingleQuote, DoubleQuote]

genEscaped :: Gen a -> Gen (Escaped' a)
genEscaped a =
  escapeNel <$> Gen.nonEmpty (Range.linear 1 5) a

genQuoted :: Gen a -> Gen (Quoted a)
genQuoted =
  liftA2 Quoted genQuote . genEscaped

genAtLeastTwo :: Range Int -> Gen a -> Gen (AtLeastTwo a)
genAtLeastTwo r a = AtLeastTwo <$> a <*> Gen.nonEmpty r a

genField :: Gen Spaces -> Gen s1 -> Gen s2 -> Gen (Field' s1 s2)
genField spc s1 s2 =
  Gen.choice [
    UnquotedF <$> s1
  , QuotedF <$> genBetween spc (genQuoted s2)
  ]

genRecord :: Gen Spaces -> Gen s -> Gen (Record s)
genRecord spc s =
  Record <$> Gen.nonEmpty (Range.linear 1 10) (downmix <$> genField spc s s)

genNonEmptyRecord :: Gen Spaces -> Gen s1 -> Gen s2 -> Gen (NonEmptyRecord s1 s2)
genNonEmptyRecord spc s1 s2 =
  let f  = genField spc s1 s2
      f' = downmix <$> genField spc s2 s2
  in  Gen.choice [
    SingleFieldNER <$> f
  , MultiFieldNER <$> genAtLeastTwo (Range.linear 1 10) f'
  ]

genRecords :: Gen Spaces -> Gen str -> Gen (Records str)
genRecords spc str =
  Records <$> genPesarated spc str

genPesarated :: Gen Spaces -> Gen s -> Gen (Pesarated Newline (Record s))
genPesarated spc s =
  let r = genRecord spc s
  in  Pesarated <$> genSeparated r genNewline

genSeparated :: Gen a -> Gen b -> Gen (Separated a b)
genSeparated a b =
  Separated <$> Gen.list (Range.linear 0 1000) (liftA2 (,) a b)

genHeader :: Gen Spaces -> Gen s -> Gen (Header s)
genHeader spc s = Header <$> genRecord spc s

genHeaded :: Gen Spaces -> Gen s1 -> Gen s2 -> Gen (Headed s1 s2)
genHeaded spc s1 s2 =
  let hdr = genHeader spc s2
      csv = genCsv genSep spc s1 s2
  in Headed <$> hdr <*> Gen.maybe (liftA2 (,) genNewline csv)

