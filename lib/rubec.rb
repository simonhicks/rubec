# **Rubec** is a set of parser combinators written in ruby.
#
# For the purposes of this library, a parser is a proc that takes a Rubec::State object, 
# and checks whether the remainder of the string begins with a specific pattern. If so,
# it updates the State object (advancing it's position) and returns either the matching
# or some function of the matching string. If it doesn't match, then the state object is
# left ualtered and the parser returns nil
#
# Parsers can be created using the #to_parser method...
#
#     # this will match when the remaining state begins with "hello"
#     hello = "hello".to_parser     
#     # this will match when the remaining state begins with a digit
#     digit = /\d/.to_parser        
#     lowercase = ("a".."z").to_parser
#     non_zero = (1..9).to_parser
#
# The methods in this module are combinators, which means they take one or more parsers 
# as their arguments, and return more complex parsers. For example,
#
#     require 'rubec'
#     include Rubec
#
#     zero = 0.to_parser
#     non_zero = (1..9).to_parser
#     digit = choice(zero, non_zero)
#     integer = seq(zero, rep0(digit))
# 
# In fact, all the combinators will automatically call #to_parser whenever they expect 
# a parser so you can also do this...
#
#     require 'rubec'
#     include Rubec
#
#     digit = choice(0, 1..9)
#     integer = seq(0, rep0(digit))
#
# The best way to use parsers is using Rubec.parse(str, parser) as this automatically
# creates a Rubec::State object and removes any ignored items for you, returning only 
# the abstract data tree...


# load the extensions so we can use the #to_parser method on existing classes
%w(object regexp string fixnum range).each do |c|
  require File.dirname(__FILE__) + "/extensions/#{c}"
end

module Rubec
  require File.dirname(__FILE__) + '/rubec/state'
  extend self

  # takes any number of parsers and returns another parser that matches the first of the 
  # patterns matched by the given parsers
  def choice *parsers
    proc do |state|
      result = nil
      parsers.find do |pars|
        result = pars.to_parser[state]
      end
      !result.nil? ? result : nil
    end
  end

  # takes a parser and returns another parser that either matches the pattern matched by
  # that parser or matches anything and returns false. This can be used to match optional 
  # patterns.
  def opt psr
    proc do |state|
      (res = psr.to_parser[state]).nil? ? false : res
    end
  end

  # takes a parser and returns another parser that matches 0 or more repetitions of the 
  # the pattern matched by the given parser.
  def rep0 pars
    proc do |state|
      results = []
      while !(res = pars.to_parser[state]).nil?
        results << res
      end
      results
    end
  end

  # takes a parser and returns another parser that matches 1 or more repetitions of the
  # pattern matched by the give parser.
  def rep1 pars
    proc do |state|
      results = nil
      if !(res = pars.to_parser[state]).nil?
        more = rep0(pars)[state]
        results = more.unshift(res)
      end
      results
    end
  end

  # takes any number of parsers and returns another parser that matches only if all the
  # given parsers match in sequence. (ie. it matches a pattern constructed by the 
  # sequence of patterns matched by the given parsers)
  #
  # The state is cloned before it is parsed, so that the original isn't altered when some 
  # of the parsers match, but others don't.
  def seq *parsers
    proc do |state|
      s = state.clone
      results = []
      parsers.each do |ps| 
        results << (res = ps.to_parser[s])
        break if res.nil?
      end
      if results.all?{|e| !(e.nil?) }
        parsers.map{|ps| ps.to_parser[state]}
      else
        nil
      end
    end
  end

  # takes a parser and a block and returns another parser that matches the same pattern,
  # but passes the value returned by the original parser to the block before returning it.
  def action psr, &block
    proc do |state|
      if !(res = psr.to_parser[state]).nil?
        block.call(res)
      else
        nil
      end
    end
  end

  # takes a parser and returns another parser that matches the same pattern, but always 
  # returns false if there's a match or nil if not. This is useful for matching patterns
  # that we want to ignore (like whitespace).
  def ignore psr
    action psr.to_parser do
      false
    end
  end

  # takes a begining parser, a middle parser and an end parser and returns another parser
  # that matches the three parsers' patterns in sequence, returning the result of the middle
  # parser. This is useful for matching things between brackets, parens, quote-marks etc.
  def between before, cont, after
    proc do |state|
      result = seq(before, cont, after)[state]
      result.nil? ? nil : result[1]
    end
  end

  # takes an item parser and a seperator parser and returns a parser that matches a list
  # of items separated by the separator. If the returned parser matches, the separator is
  # ignored and the result is an array of the matched items.
  def list item, sep=","
    action(seq(item, rep0(seq(ignore(sep), item)))) do |ast|
      f, r = ast
      r.map{|e| e[1]}.unshift(f)
    end
  end

  # takes two parsers and returns another parser that matches only when the first parser
  # matches and the second parser doesn't match.
  #
  # the state is cloned before being parsed, so that it isn't altered if both parsers match
  def except yes, no
    proc do |state|
      s = state.clone # this is so that if there are no matches, then state isn't altered
      if no.to_parser[s].nil?
        yes.to_parser[state]
      else
        nil
      end
    end
  end

  # returns a parser that matches anything. Most commonly used with except (eg. 
  # except(anything, whitespace))
  def anything
    proc do |state|
      res = state.remaining[0]
      state.advance(1)
      res
    end
  end

  # returns a parser that always fails (ie. always returns nil)
  def fail
    proc do |state|
      nil
    end
  end

  # returns a parser that matches the end of the string
  def eos
    ignore /\Z/
  end

  # takes a Rubec::State object and a parser and returns the state and the result of parsing 
  # that state using the given parser. Since false is used to indicate that something should 
  # be ingored, the data structure is walked and all false's are removed before it's returned.
  #
  # If a string is given instead of a State object, a new State object is created using the 
  # string and this is parsed instead.
  def parse state, psr
    state = state.is_a?(State) ? state : State.new(state)
    ast = remove_all_false(psr.to_parser[state])
    [state, ast]
  end

  private

  # walks the given data structure and removes all items which are equal to false
  def remove_all_false ast
    result = []
    if ast.is_a?(Array)
      ast.each do |e|
        if e.is_a?(Array)
          result << remove_all_false(e)
        elsif e != false
          result << e
        end
      end
    elsif result != false
      result = ast
    end
    result
  end
end

