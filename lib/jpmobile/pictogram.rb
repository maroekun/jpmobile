module Jpmobile
  # 絵文字関連処理
  module Pictogram
    # +str+ のなかで携帯電話側エンコーディングで表記された絵文字をUnicode数値文字参照に置換する。
    def self.external_to_unicodecr(str)
      # NOTE 現状ではキャリア間で端末が送ってくる絵文字のコード領域が重なっていないので、
      # このメソッドはUser-agentによって挙動を変更する必要は無い。
      s = str.dup
      # DoCoMo, Au
      s.gsub!(SJIS_REGEXP) do |match|
        sjis = match.unpack('n').first
        unicode = SJIS_TO_UNICODE[sjis]
        unicode ? ("&#x%04x;"%unicode) : match
      end
      # SoftBank
      s.gsub!(/\x1b\x24(.)(.+?)\x0f/) do |match|
        a = $1
        $2.split(//).map{|x| "\x1b\x24#{a}#{x}\x0f"}.join('')
      end
      s.gsub(SOFTBANK_WEBCODE_REGEXP) do |match|
        unicode = SOFTBANK_WEBCODE_TO_UNICODE[match[2,2]] + 0x1000
        unicode ? ("&#x%04x;"%unicode) : match
      end
    end
    # +str+ のなかでUnicode数値文字参照で表記された絵文字を携帯側エンコーディングに置換する。
    #
    # キャリア間の変換に +conversion_table+ を使う。+conversion_table+ に+nil+を与えると、
    # キャリア間の変換は行わない。
    #
    # 携帯側エンコーディングがShift_JIS場合は +to_sjis+ に +true+ を指定する。
    # +true+ を指定すると変換テーブルに文字列が指定されている場合にShift_JISで出力される。
    def self.unicodecr_to_external(str, conversion_table=nil, to_sjis=true)
      # NOTE このメソッドだけがUser-Agentに依存して挙動を変える必要がある。
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        if conversion_table
          converted = conversion_table[unicode] # キャリア間変換
        else
          converted = unicode # 変換しない
        end

        # 携帯側エンコーディングに変換する
        case converted
        when Integer
          # 変換先がUnicodeで指定されている。つまり対応する絵文字がある。
          if sjis = UNICODE_TO_SJIS[converted]
            [sjis].pack('n')
          elsif webcode = SOFTBANK_UNICODE_TO_WEBCODE[converted-0x1000]
            "\x1b\x24#{webcode}\x0f"
          else
            # キャリア変換テーブルに指定されていたUnicodeに対応する
            # 携帯側エンコーディングが見つからない(変換テーブルの不備の可能性あり)。
            match
          end
        when String
          # 変換先がUnicodeで指定されている。
          to_sjis ? Kconv::kconv(converted, Kconv::SJIS, Kconv::UTF8) : converted
        when nil
          # 変換先が定義されていない。
          match
        end
      end
    end
    # +str+ のなかでUnicode数値文字参照で表記された絵文字をUTF-8に置換する。
    def self.unicodecr_to_utf8(str)
      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        if UNICODE_TO_SJIS[unicode] || SOFTBANK_UNICODE_TO_WEBCODE[unicode-0x1000]
          [unicode].pack('U')
        else
          match
        end
      end
    end
    # +str+ のなかでUTF-8で表記された絵文字をUnicode数値文字参照に置換する。
    def self.utf8_to_unicodecr(str)
      str.gsub(UTF8_REGEXP) do |match|
        "&#x%04x;" % match.unpack('U').first
      end
    end
  end
end