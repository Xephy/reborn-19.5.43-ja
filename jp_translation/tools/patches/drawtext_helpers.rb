#===============================================================================
# Japanese line breaking.
# The word-wrap loops further down can only break a line at whitespace, which
# Japanese text never contains, so a translated line would run straight off the
# window. These helpers make every character boundary a break candidate instead,
# subject to kinsoku shori (characters that may not start or end a line).
# Pure ASCII text is unaffected: a break is only offered when one of the two
# characters involved is a wide character.
#===============================================================================
JA_WIDE_CHAR    = /[　-〿぀-ヿㇰ-ㇿ㐀-䶿一-鿿＀-￯]/
# May not begin a line: closing brackets, punctuation, small kana, prolonged sound mark.
JA_NO_LINE_HEAD = /[　、。，．・：；？！゛゜ー々〜…‥ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ)\]}）］｝〉》」』】〕｣!?:;]/
# May not end a line: opening brackets.
JA_NO_LINE_END  = /[（［｛〈《「『【〔｢(\[{]/

def pbJaCanBreakBefore?(prev, cur)
  return false if !prev || !cur || prev == "" || cur == ""
  return false if !prev[JA_WIDE_CHAR] && !cur[JA_WIDE_CHAR]
  return false if cur[JA_NO_LINE_HEAD]
  return false if prev[JA_NO_LINE_END]
  return true
end

# Splits a whitespace-delimited "word" into the pieces that may each start a
# line. getLineBrokenChunks tokenizes on whitespace, so an entire Japanese
# sentence arrives as a single word and can never be wrapped; this gives that
# wrapper something to work with. ASCII-only words are returned untouched.
def pbJaSplitChunks(str)
  return [str] if !str || str == "" || !str[JA_WIDE_CHAR]

  chars = str.scan(/./m)
  out = []
  cur = ""
  for i in 0...chars.length
    if i > 0 && cur != "" && pbJaCanBreakBefore?(chars[i - 1], chars[i])
      out.push(cur)
      cur = ""
    end
    cur += chars[i]
  end
  out.push(cur) if cur != ""
  return out
end

