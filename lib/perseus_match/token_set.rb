$KCODE = 'u'

LINGO_BASE = '/home/jw/devel/lingo/trunk'

class PerseusMatch

  class TokenSet < Array

    def self.tokenize(form)
      return @tokens[form] if @tokens

      @_tokens = {}
      @tokens  = Hash.new { |h, k| h[k] = new(
        k, @_tokens.has_key?(k) ? @_tokens[k] :
          k.scan(/\w+/).map { |i| @_tokens[i] }.flatten.compact
      )}

      parse = lambda { |x|
        x.each { |res|
          case res
            when /<(.*?)\s=\s\[(.*)\]>/
              a, b = $1, $2
              @_tokens[a.sub(/\|.*/, '')] ||= b.scan(/\((.*?)\+?\)/).flatten
            #when /<(.*)>/, /:(.*):/
            #  # ignore
          end
        }
      }

      if File.readable?(t = 'perseus.tokens')
        File.open(t) { |f| parse[f] }
        @tokens[form]
      else
        cfg  = File.join(Dir.pwd, 'perseus.cfg')
        file = form[0] == ?/ ? form : File.join(Dir.pwd, form)

        unless File.file?(file) && File.readable?(file)
          require 'tempfile'

          temp = Tempfile.new('perseus_match_temp')
          temp.puts form
          temp.close

          file = temp.path
        end

        Dir.chdir(LINGO_BASE) { parse[%x{
          ./lingo.rb -c #{cfg} < #{file}
        }] }

        if temp
          temp.unlink

          tokens  = @tokens[form]
          @tokens = nil
          tokens
        else
          @tokens[form]
        end
      end
    end

    private :push, :<<, :[]=  # maybe more...

    attr_reader :form

    def initialize(form, tokens = nil)
      super(tokens || self.class.tokenize(form))

      @form   = form
      @tokens = to_a.flatten
    end

    def distance(other)
      distance, index, max = xor(other).size, -1, size

      intersect(other).each { |token|
        while current = other.tokens[index += 1] and current != token
          distance += 1

          break if index > max
        end
      }

      distance
    end

    def tokens(wc = true)
      wc ? @tokens : @tokens_sans_wc ||= @tokens.map { |token|
        token.sub(%r{[/|].*?\z}, '')
      }
    end

    def &(other)
      tokens & other.tokens
    end

    def |(other)
      tokens | other.tokens
    end

    def intersect(other)
      (self & other).inject([]) { |memo, token|
        memo + [token] * [count(token), other.count(token)].max
      }
    end

    def xor(other)
      ((self | other) - (self & other)).inject([]) { |memo, token|
        memo + [token] * (count(token) + other.count(token))
      }
    end

    def disjoint?(other)
      (tokens(false) & other.tokens(false)).empty?
    end

    def inclexcl(inclexcl = {})
      incl(inclexcl[:incl] || '.*').excl(inclexcl[:excl])
    end

    def incl(*wc)
      (@incl ||= {})[wc = [*wc].compact] ||= map { |tokens|
        tokens.reject { |token| !match?(token, wc) }
      }.to_token_set(form)
    end

    def excl(*wc)
      (@excl ||= {})[wc = [*wc].compact] ||= map { |tokens|
        tokens.reject { |token| match?(token, wc) }
      }.to_token_set(form)
    end

    def count(token)
      counts[token]
    end

    def counts
      @counts ||= tokens.inject(Hash.new(0)) { |counts, token|
        counts[token] += 1
        counts
      }
    end

    def inspect
      "#{super}<#{form}>"
    end

    alias_method :to_s, :inspect

    private

    def match?(token, wc)
      token =~ %r{[/|](?:#{wc.join('|')})\z}
    end

  end

  class ::Array

    def to_token_set(form)
      TokenSet.new(form, self)
    end

  end

end
