require 'rubec'

# To demonstrate the basics of Rubec, I'm going to use a basic Calculator. Our 
# calculator is going to parse and evaluate simple arithmetic statements like 
# "1 + 2 * 3".

class Calculator
  # rubec consists mostly of methods in the Rubec module, so we need to include it
  include Rubec

  # first we create the parsers.
  def initialize
    utility_parsers
    operator_parsers
    integer_parsers
    term_and_expr_parsers
  end

  private

  # here we are creating a whitespace parser using the ignore() method. This will match
  # whitespace, but won't add anything to the final syntax tree.
  def utility_parsers
    @whitespace = ignore /\s+/
  end

  # this is going to be used to make the operator parsers. We use between() to match three 
  # parsers as a single pattern, only keeping the result of the middle one, and opt() so 
  # that the whitespace is optional.
  def make_operator op
    between(opt(@whitespace), op, opt(@whitespace))
  end

  def operator_parsers
    @plus = make_operator "+"
    @minus = make_operator "-"
    @times = make_operator "*"
    @divide = make_operator "/"
  end

  # here we use action() so we can process the output of the parser, converting an array of
  # strings, each containing a single digit into a single Integer.
  def integer_parsers
    @integer = action(seq(1..9, rep0(0..9))) do |ast|
      ast.flatten.join('').to_i
    end
  end

  # Here we use choice() to create a parser that matches the first of a number of options and seq()
  # to match a sequence of several parsers as a single parser. Also, since Ruby doesn't support lazyr
  # evaluation, we need to use forward definitions to enable recursive parsers
  def term_and_expr_parsers
    @term = proc{|*args| @term[*args]}
    @term = seq(
        choice(@integer), 
        choice(@times, @divide), 
        choice(@term, @integer))
    @expr = proc{|*args| @expr[*args]}
    @expr = seq(
        choice(@term, @integer),
        choice(@plus, @minus),
        choice(@term, @expr, @integer))
    @parser = choice(@expr, @term, @integer)
  end

  # the parse() method is used to apply a parser to a string. It returns a data tree representing 
  # the abstract syntax tree.
  def parse_expr str
    parse(str, @parser)
  end

  # this utility method is for evaluating the syntax tree returned by the #parse_expr method
  def evaluate_tree ast
    n1, op, n2 = ast
    n1 = n1.is_a?(Array) ? evaluate_tree(n1) : n1
    n2 = n2.is_a?(Array) ? evaluate_tree(n2) : n2
    n1.send(op.to_sym, n2)
  end

  public

  # the calculate method just ties it all together and provides an entry point. The abstract syntax 
  # tree is also printed for demonstration purposes
  def calculate str
    ast = parse_expr(str)[1]
    puts ast.to_s
    evaluate_tree(ast)
  end
end

# now we test our new calculator
c = Calculator.new
puts c.calculate("1 * 2 + 3 * 4")
