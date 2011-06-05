# Adds a #to_parser method to Regexp
class Regexp
  def to_parser
    proc do |state|
      state.match(self)
      if state.last_match
        result = state.instance_eval do
          advance last_match[0].length
          last_match[0]
        end
        result
      else
        nil
      end
    end
  end
end

