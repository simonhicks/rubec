class String
  def to_parser
    proc do |state|
      test_string = state.remaining[0, (len = self.length)]
      if self == test_string
        state.instance_eval do
          advance len
        end
        self.clone
      else 
        nil
      end
    end
  end
end

