# This object is used by Rubec parsers to store the current state during parsing

module Rubec
  class State
  # create the State object using a string that is to be parsed
    def initialize string=""
      @string = string
      @index = 0
      @last_match = nil
    end

    attr_reader :last_match

    # returns the remaining, unparsed portion of the string
    def remaining
      @string[@index..-1]
    end

    # returns the line number of the line that is currently being parsed... this would 
    # be useful for reporting errors, except that it's not currently available from any 
    # of the parsers
    def line
      @string[0..@index].split("\n").count
    end

    # advance the position of this state object by n characters... this is to acccount
    # for that fact that we have parsed n chars sucessfully.
    def advance n
      @index += n
      self
    end

    # This is used for regexp parsers. Since we only want a regexp parser to match the 
    # first part of the remaining string, we check for the presence of \A in the regexp
    # before matching, making parsers easier to read and write.
    def match re
      unless re.inspect[1..2] == "\\A"
        a = re.inspect
        a[0] = "/\\A"
        re = eval(a)
      end
      @last_match = remaining.match(re)
    end

    # clone the State object. This is used for combinators that require several conditions 
    # to be met in order to match... it allows us to fail, after some parsers have matched 
    # without altering the original object.
    def clone
      s = State.new(@string)
      s.index = @index
      s
    end

    protected

    # used when creating a clone
    def index= n
      @index = n
    end
  end
end
