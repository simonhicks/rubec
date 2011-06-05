# load the extensions so we can use the #to_parser method on existing classes
%w(object regexp string fixnum range).each do |c|
  require File.dirname(__FILE__) + "/extensions/#{c}"
end

module Rubec
  require File.dirname(__FILE__) + '/rubec/state'
  extend self

  def choice *parsers
    proc do |state|
      result = nil
      parsers.find do |pars|
        result = pars.to_parser[state]
      end
      !result.nil? ? result : nil
    end
  end

  def opt psr
    proc do |state|
      (res = psr.to_parser[state]).nil? ? false : res
    end
  end

  def rep0 pars
    proc do |state|
      results = []
      while !(res = pars.to_parser[state]).nil?
        results << res
      end
      results
    end
  end

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

  def action psr, &block
    proc do |state|
      if !(res = psr.to_parser[state]).nil?
        block.call(res)
      else
        nil
      end
    end
  end

  def ignore psr
    action psr.to_parser do
      false
    end
  end

  def between before, cont, after
    proc do |state|
      result = seq(before, cont, after)[state]
      result.nil? ? nil : result[1]
    end
  end

  def list item, sep=","
    action(seq(item, rep0(seq(ignore(sep), item)))) do |ast|
      f, r = ast
      r.map{|e| e[1]}.unshift(f)
    end
  end

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

  def anything
    proc do |state|
      res = state.remaining[0]
      state.advance(1)
      res
    end
  end

  def fail
    proc do |state|
      nil
    end
  end

  def eos
    ignore /\Z/
  end

  def parse state, psr
    state = state.is_a?(State) ? state : State.new(state)
    ast = remove_all_false(psr.to_parser[state])
    [state, ast]
  end

  private

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
