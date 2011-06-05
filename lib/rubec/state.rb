class Rubec::State
  def initialize string=""
    @string = string
    @index = 0
    @last_match = nil
  end

  attr_reader :last_match

  def remaining
    @string[@index..-1]
  end

  def line
    @string[0..@index].split("\n").count
  end

  def advance n
    @index += n
    self
  end

  def match re
    unless re.inspect[1..2] == "\\A"
      a = re.inspect
      a[0] = "/\\A"
      re = eval(a)
    end
    @last_match = remaining.match(re)
  end

  def clone
    s = State.new(@string)
    s.index = @index
    s
  end

  protected

  def index= n
    @index = n
  end
end
