# Where the rendered samples are written. Relative to the game's working
# directory unless JP_SELFTEST_OUT points somewhere else.
OUT = ENV["JP_SELFTEST_OUT"] || "jp_selftest"
alias :__jp_orig_setlang2 :pbSetLanguage
def pbSetLanguage
  __jp_orig_setlang2
  begin
    Dir.mkdir(OUT) rescue nil
    bmp = Bitmap.new(512, 300)
    bmp.fill_rect(0, 0, 512, 300, Color.new(40, 48, 56))
    pbSetSystemFont(bmp)
    base = Color.new(248,248,248); sh = Color.new(72,80,88)
    # 実際の枠と同じ 282px x 64px を3種類の長さで
    samples = [
      "命中率が30％上がる。",
      "こうげきを受けると自分のほのお技の威力が50％上がる。",
      "そのターンに他のポケモンが使った道具をターンの終わりに拾う。戦闘後にも道具を拾うことがある。",
      "味方にプラスかマイナスがいると特攻が50％上がる。じきゅうりょくは防御と特防をギアチェンジは攻撃と特攻を上げる。",
    ]
    y = 4
    samples.each do |t|
      bmp.fill_rect(6, y, 282, 64, Color.new(56,66,78))
      drawTextExFitted(bmp, 6, y, 282, 2, t, base, sh)
      y += 70
    end
    bmp.to_file("#{OUT}/abil.png")
    bmp.dispose
    File.open("#{OUT}/ok.txt","wb"){|f| f.write("done\n")}
  rescue Exception => e
    File.open("#{OUT}/ok.txt","wb"){|f| f.write("FAILED\n#{e.class}: #{e.message}\n#{(e.backtrace||[])[0,6].join("\n")}\n")}
  end
end
